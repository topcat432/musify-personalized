import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/offline_file_publication.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('offline-publication-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test('Android syscall numbers match supported UAPI ABIs', () {
    expect(offlineRenameNoReplaceSyscallNumber(Abi.androidArm), 382);
    expect(offlineRenameNoReplaceSyscallNumber(Abi.androidArm64), 276);
    expect(offlineRenameNoReplaceSyscallNumber(Abi.androidIA32), 353);
    expect(offlineRenameNoReplaceSyscallNumber(Abi.androidX64), 316);
    expect(offlineRenameNoReplaceSyscallNumber(Abi.windowsX64), isNull);
    expect(offlineReadOnlyNoFollowFlags(Abi.androidArm), 0x88000);
    expect(offlineReadOnlyNoFollowFlags(Abi.androidArm64), 0xa0000);
    expect(offlineReadOnlyNoFollowFlags(Abi.androidIA32), 0xa0000);
    expect(offlineReadOnlyNoFollowFlags(Abi.androidX64), 0xa0000);
  });
  test(
    'no-replace move rejects a symlink source without moving its target',
    () async {
      final source = File('${root.path}/source');
      final alias = Link('${root.path}/alias');
      final target = File('${root.path}/target');
      await source.writeAsBytes([1, 2, 3]);
      await alias.create(source.path);
      expect(
        () => publishOfflineFile(
          File(alias.path),
          target,
          useNoReplaceMove: true,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await source.readAsBytes(), [1, 2, 3]);
      expect(await alias.target(), source.path);
      expect(await target.exists(), isFalse);
    },
    skip: !Platform.isLinux,
  );
  for (final mode in [
    'default',
    if (Platform.isLinux) ...['move', 'syscall'],
  ]) {
    OfflineFilePublication publish(File from, File to) => publishOfflineFile(
      from,
      to,
      useNoReplaceMove: mode != 'default',
      forceSyscall: mode == 'syscall',
    );
    test('$mode preserves bytes and live ownership until close', () async {
      final source = File('${root.path}/source'),
          target = File('${root.path}/target');
      await source.writeAsBytes([1, 2, 3, 4], flush: true);
      final owner = publish(source, target);
      try {
        expect(owner.owns(target), isTrue);
        expect(await target.readAsBytes(), [1, 2, 3, 4]);
        expect(await source.exists(), mode == 'default');
        await target.delete();
        await target.writeAsBytes([1, 2, 3, 4], flush: true);
        expect(
          owner.owns(target),
          isFalse,
          reason: 'Same bytes are not the same inode',
        );
      } finally {
        owner.close();
        owner.close();
      }
      expect(owner.owns(target), isFalse);
    });
    for (final kind in [
      'file',
      'directory',
      if (!Platform.isWindows) 'dangling-link',
    ]) {
      test('$mode never clobbers $kind', () async {
        final source = File('${root.path}/source'),
            target = '${root.path}/target';
        await source.writeAsBytes([1, 2, 3, 4], flush: true);
        if (kind == 'file') await File(target).writeAsBytes([9, 8, 7]);
        if (kind == 'directory') await Directory(target).create();
        if (kind == 'dangling-link')
          await Link(target).create('${root.path}/missing');
        expect(
          () => publish(source, File(target)),
          throwsA(isA<FileSystemException>()),
        );
        expect(await source.readAsBytes(), [1, 2, 3, 4]);
        if (kind == 'file') expect(await File(target).readAsBytes(), [9, 8, 7]);
        if (kind == 'directory')
          expect(await Directory(target).exists(), isTrue);
        if (kind == 'dangling-link')
          expect(await Link(target).target(), '${root.path}/missing');
      });
    }
    test(
      '$mode competing writers have one winner and preserve loser',
      () async {
        final paths = [for (var i = 0; i < 2; i++) '${root.path}/source$i'];
        for (var i = 0; i < 2; i++)
          await File(paths[i]).writeAsBytes([i + 1, i + 1], flush: true);
        final target = '${root.path}/target';
        final moving = mode != 'default', syscall = mode == 'syscall';
        final results = await Future.wait([
          for (final path in paths)
            Isolate.run(() {
              try {
                final owner = publishOfflineFile(
                  File(path),
                  File(target),
                  useNoReplaceMove: moving,
                  forceSyscall: syscall,
                );
                try {
                  return owner.owns(File(target));
                } finally {
                  owner.close();
                }
              } on FileSystemException {
                return false;
              }
            }),
        ]);
        expect(results.where((x) => x).length, 1);
        final winner = results.indexOf(true), loser = 1 - results.indexOf(true);
        expect(await File(target).readAsBytes(), [winner + 1, winner + 1]);
        expect(await File(paths[loser]).readAsBytes(), [loser + 1, loser + 1]);
      },
    );
  }
  test('failed no-replace calls release pinned descriptors', () async {
    final source = File('${root.path}/source'),
        target = File('${root.path}/target');
    await source.writeAsBytes([1]);
    await target.writeAsBytes([2]);
    final before = Directory('/proc/self/fd').listSync().length;
    for (var i = 0; i < 40; i++)
      expect(
        () => publishOfflineFile(
          source,
          target,
          useNoReplaceMove: true,
          forceSyscall: true,
        ),
        throwsA(isA<FileSystemException>()),
      );
    expect(
      Directory('/proc/self/fd').listSync().length,
      lessThanOrEqualTo(before + 2),
    );
    expect(await source.readAsBytes(), [1]);
    expect(await target.readAsBytes(), [2]);
  }, skip: !Platform.isLinux);
}
