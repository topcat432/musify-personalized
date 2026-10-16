import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

typedef OfflineFilePublisher =
    OfflineFilePublication Function(File source, File destination);

/// Live inode witness. Close after registration or compensation, including errors.
/// A checksum alone cannot distinguish a same-byte successor at the final path.
class OfflineFilePublication {
  OfflineFilePublication._(this._identityPath, [this._release]);
  final String _identityPath;
  final void Function()? _release;
  bool _closed = false;

  bool owns(File file) =>
      !_closed &&
      FileSystemEntity.typeSync(file.path, followLinks: false) ==
          FileSystemEntityType.file &&
      FileSystemEntity.identicalSync(_identityPath, file.path);

  void close() {
    if (_closed) return;
    _closed = true;
    _release?.call();
  }
}

/// Never replaces an existing entry. Android moves the validated inode with
/// RENAME_NOREPLACE, retaining an open descriptor as the live ownership witness.
/// Other platforms retain the source hard link. Unsupported operations fail closed.
/// The explicit move/syscall options also exercise Android's paths on Linux CI.
OfflineFilePublication publishOfflineFile(
  File source,
  File destination, {
  bool useNoReplaceMove = false,
  bool forceSyscall = false,
}) {
  if (source.absolute.path.contains('\u0000') ||
      destination.absolute.path.contains('\u0000')) {
    throw ArgumentError('Offline paths must not contain NUL');
  }
  if (Platform.isAndroid || useNoReplaceMove || forceSyscall) {
    return _publishByNoReplaceMove(
      source,
      destination,
      forceSyscall: forceSyscall,
    );
  }
  final allocator = Platform.isWindows
      ? DynamicLibrary.open('msvcrt.dll')
      : DynamicLibrary.process();
  final allocate = allocator
      .lookupFunction<
        Pointer<Void> Function(IntPtr),
        Pointer<Void> Function(int)
      >('malloc');
  final free = allocator
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('free');
  Pointer<Void> encode(String path) {
    if (Platform.isWindows) {
      final units = [...path.codeUnits, 0];
      final result = allocate(units.length * 2);
      if (result == nullptr) throw StateError('Offline path allocation failed');
      result.cast<Uint16>().asTypedList(units.length).setAll(0, units);
      return result;
    }
    final units = [...utf8.encode(path), 0];
    final result = allocate(units.length);
    if (result == nullptr) throw StateError('Offline path allocation failed');
    result.cast<Uint8>().asTypedList(units.length).setAll(0, units);
    return result;
  }

  final from = encode(source.absolute.path);
  Pointer<Void> to = nullptr;
  try {
    to = encode(destination.absolute.path);
    final bool success;
    if (Platform.isWindows) {
      final create = DynamicLibrary.open('kernel32.dll')
          .lookupFunction<
            Int32 Function(Pointer<Uint16>, Pointer<Uint16>, Pointer<Void>),
            int Function(Pointer<Uint16>, Pointer<Uint16>, Pointer<Void>)
          >('CreateHardLinkW');
      success = create(to.cast<Uint16>(), from.cast<Uint16>(), nullptr) != 0;
    } else {
      final link = DynamicLibrary.process()
          .lookupFunction<
            Int32 Function(Pointer<Uint8>, Pointer<Uint8>),
            int Function(Pointer<Uint8>, Pointer<Uint8>)
          >('link');
      success = link(from.cast<Uint8>(), to.cast<Uint8>()) == 0;
    }
    if (!success)
      throw FileSystemException(
        'Atomic offline publication refused (destination exists or hard links unavailable)',
        destination.path,
      );
    return OfflineFilePublication._(source.absolute.path);
  } finally {
    if (to != nullptr) free(to);
    free(from);
  }
}

/// Linux UAPI syscall numbers, also used by Bionic on API24–29 where the
/// renameat2 libc wrapper is absent. Unsupported ABIs fail before mutation.
int? offlineRenameNoReplaceSyscallNumber(Abi abi) => switch (abi) {
  Abi.androidArm || Abi.linuxArm => 382,
  Abi.androidArm64 || Abi.linuxArm64 || Abi.linuxRiscv64 => 276,
  Abi.androidIA32 || Abi.linuxIA32 => 353,
  Abi.androidX64 || Abi.linuxX64 => 316,
  _ => null,
};

OfflineFilePublication _publishByNoReplaceMove(
  File source,
  File destination, {
  required bool forceSyscall,
}) {
  if (!Platform.isAndroid && !Platform.isLinux) {
    throw UnsupportedError('No-replace move requires Android or Linux');
  }
  final libc = DynamicLibrary.open(
    Platform.isAndroid ? 'libc.so' : 'libc.so.6',
  );
  final errno = libc
      .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
        Platform.isAndroid ? '__errno' : '__errno_location',
      )();
  final malloc = libc
      .lookupFunction<
        Pointer<Void> Function(IntPtr),
        Pointer<Void> Function(int)
      >('malloc');
  final free = libc
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('free');
  final open = libc
      .lookupFunction<
        Int32 Function(Pointer<Uint8>, Int32, VarArgs<()>),
        int Function(Pointer<Uint8>, int)
      >('open');
  final close = libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
    'close',
  );
  Pointer<Uint8> encode(String path) {
    final bytes = [...utf8.encode(path), 0];
    final pointer = malloc(bytes.length).cast<Uint8>();
    if (pointer == nullptr) throw StateError('Offline path allocation failed');
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    return pointer;
  }

  final from = encode(source.absolute.path);
  Pointer<Uint8> to = nullptr;
  var fd = -1;
  var transferred = false;
  try {
    to = encode(destination.absolute.path);
    // O_RDONLY | O_NOFOLLOW | O_CLOEXEC: pin this inode, never a symlink target.
    fd = open(from, 0x20000 | 0x80000);
    if (fd < 0) {
      final code = errno.value;
      throw FileSystemException(
        'Cannot pin offline source',
        source.path,
        OSError('open', code),
      );
    }
    final witness = '/proc/self/fd/$fd';
    if (!FileSystemEntity.identicalSync(source.path, witness)) {
      throw FileSystemException('Offline source identity changed', source.path);
    }
    final int result;
    if (!forceSyscall && libc.providesSymbol('renameat2')) {
      final rename = libc
          .lookupFunction<
            Int32 Function(
              Int32,
              Pointer<Uint8>,
              Int32,
              Pointer<Uint8>,
              Uint32,
            ),
            int Function(int, Pointer<Uint8>, int, Pointer<Uint8>, int)
          >('renameat2');
      result = rename(-100, from, -100, to, 1); // AT_FDCWD, RENAME_NOREPLACE
    } else {
      final number = offlineRenameNoReplaceSyscallNumber(Abi.current());
      if (number == null)
        throw UnsupportedError('Unsupported no-replace syscall ABI');
      final syscall = libc
          .lookupFunction<
            IntPtr Function(
              IntPtr,
              VarArgs<(IntPtr, Pointer<Uint8>, IntPtr, Pointer<Uint8>, IntPtr)>,
            ),
            int Function(int, int, Pointer<Uint8>, int, Pointer<Uint8>, int)
          >('syscall');
      result = syscall(number, -100, from, -100, to, 1);
    }
    final code = errno.value; // Capture before any other native call.
    if (result != 0) {
      throw FileSystemException(
        'Atomic offline no-replace move refused',
        destination.path,
        OSError('renameat2 RENAME_NOREPLACE', code),
      );
    }
    final ownedFd = fd;
    final publication = OfflineFilePublication._(witness, () {
      close(ownedFd);
    });
    transferred = true;
    return publication;
  } finally {
    if (!transferred && fd >= 0) close(fd);
    if (to != nullptr) free(to.cast<Void>());
    free(from.cast<Void>());
  }
}
