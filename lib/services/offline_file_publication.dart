import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

/// Publish a second name for the completed inode without replacing any existing
/// destination. Keep the source link until commit/compensation has established
/// ownership. Unsupported filesystems fail closed; no check-then-rename fallback.
void publishOfflineFile(File source, File destination) {
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
  } finally {
    if (to != nullptr) free(to);
    free(from);
  }
}
