import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'slow failed validation close retains its own lock until Hive deletes it',
    () async {
      final release = Completer<void>();
      final deleted = Completer<void>();
      final finished = Completer<void>();
      final asynchronousErrors = <Object>[];
      File? ownLock;
      Object? rejection;
      Object? deletionFailure;
      var retainedAtRejection = false;
      runZonedGuarded(() async {
        try {
          await IOOverrides.runZoned(
            () async {
              try {
                await MusifyBackupService.inspectLegacyPayloadsForTesting({
                  'user': Uint8List.fromList([0, 1, 2, 3]),
                  'settings': Uint8List(0),
                });
              } catch (error) {
                rejection = error;
              }
              retainedAtRejection = ownLock != null && await ownLock!.exists();
              release.complete();
              await deleted.future.timeout(const Duration(seconds: 5));
              await Future<void>.delayed(const Duration(milliseconds: 10));
            },
            createFile: (path) {
              final actual = Zone.root.run(() => File(path));
              if (RegExp(
                r'verify_(user|settings)_\d+[.]lock$',
              ).hasMatch(path)) {
                ownLock = actual;
                return _HeldValidationLock(actual, release.future, () {
                  if (!deleted.isCompleted) deleted.complete();
                }, (error) => deletionFailure = error);
              }
              return actual;
            },
          );
        } catch (error) {
          asynchronousErrors.add(error);
        } finally {
          if (!release.isCompleted) release.complete();
          finished.complete();
        }
      }, (error, stack) => asynchronousErrors.add(error));
      await finished.future;
      try {
        expect(rejection, isA<BackupValidationException>());
        expect(retainedAtRejection, isTrue);
        expect(deletionFailure, isNull);
        expect(asynchronousErrors, isEmpty);
        expect(await ownLock!.exists(), isFalse);
      } finally {
        await Hive.close();
        final staging = ownLock?.parent;
        if (staging != null && await staging.exists()) {
          final resolved = await staging.resolveSymbolicLinks();
          final temporary = await Directory.systemTemp.resolveSymbolicLinks();
          if (!resolved.toLowerCase().startsWith(
            '$temporary${Platform.pathSeparator}musify-legacy-inspect-'
                .toLowerCase(),
          )) {
            throw StateError(
              'Refusing cleanup outside the owned validation staging directory.',
            );
          }
          await staging.delete(recursive: true);
        }
      }
    },
  );
}

class _HeldValidationLock extends Fake implements File {
  _HeldValidationLock(this.actual, this.release, this.finished, this.onFailure);
  final File actual;
  final Future<void> release;
  final void Function() finished;
  final void Function(Object) onFailure;
  @override
  String get path => actual.path;
  @override
  Future<bool> exists() => actual.exists();
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) =>
      actual.open(mode: mode);
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    await release;
    try {
      return await actual.delete(recursive: recursive);
    } catch (error) {
      onFailure(error);
      rethrow;
    } finally {
      finished();
    }
  }
}
