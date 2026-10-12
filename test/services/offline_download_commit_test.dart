import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/playlist_download_service.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('offline-commit-');
    Hive.init('${root.path}/hive');
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    applicationDirPath = '${root.path}/audio';
    await FilePaths.ensureDirectoriesExist();
    final keeper = {
      'ytid': 'keep-owned',
      'audioPath': FilePaths.getAudioPath('keep-owned'),
      'title': 'Keep owned',
    };
    await File(FilePaths.getAudioPath('keep-owned')).writeAsBytes([7, 8, 9]);
    await Hive.box('userNoBackup').put('offlineSongs', [keeper]);
    userOfflineSongs.value = [keeper];
    offlinePlaylistService.offlinePlaylists.value = [];
    await Hive.box('user').put('likedSongs', [
      {'ytid': 'keep-liked'},
    ]);
    reloadSongLibraryStateFromStorage();
  });
  tearDown(() async {
    await Hive.close();
    final owned = await root.resolveSymbolicLinks();
    final temporary = await Directory.systemTemp.resolveSymbolicLinks();
    if (!owned.startsWith('$temporary${Platform.pathSeparator}offline-commit-'))
      throw StateError('Refusing outside owned test root');
    await root.delete(recursive: true);
  });

  Map<String, dynamic> song(String id) => {
    'ytid': id,
    'title': 'Owned download',
    'artist': 'Owned fixture',
    'sourceType': 'owned_fixture',
  };
  OfflineAudioDownload body(List<int> bytes, {int? expected}) =>
      OfflineAudioDownload(
        Stream.value(bytes),
        expectedBytes: expected ?? bytes.length,
      );

  test(
    'truncated ownership proof preserves payload and does not call loader',
    () async {
      final id = 'owned-truncated-proof';
      final audio = File(FilePaths.getAudioPath(id));
      final marker = File('${audio.path}.download-125.part.owner.json');
      await audio.writeAsBytes([4, 3, 2, 1], flush: true);
      await marker.writeAsString('{"schema":1,', flush: true);
      var calls = 0;
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async {
            calls++;
            return body([1, 2, 3]);
          },
        ),
        isFalse,
      );
      expect(calls, 0);
      expect(await audio.readAsBytes(), [4, 3, 2, 1]);
      expect(await marker.readAsString(), '{"schema":1,');
    },
  );

  test('unknown ownership-marker collision survives rejected commit', () async {
    final id = 'owned-proof-collision';
    File? collision;
    expect(
      await makeSongOffline(
        song(id),
        audioLoader: (_) async => body([1, 2, 3, 4]),
        commitProbe: (boundary) async {
          if (boundary == OfflineCommitBoundary.bodyFlushed) {
            final part = Directory(FilePaths.getAudioPath(id)).parent
                .listSync()
                .whereType<File>()
                .singleWhere(
                  (file) =>
                      file.path.contains(id) && file.path.endsWith('.part'),
                );
            collision = File('${part.path}.owner.json');
            await collision!.writeAsString(
              'owned unknown collision',
              flush: true,
            );
          }
        },
      ),
      isFalse,
    );
    expect(await collision!.readAsString(), 'owned unknown collision');
    expect(await File(FilePaths.getAudioPath(id)).exists(), isFalse);
    expect((Hive.box('userNoBackup').get('offlineSongs') as List).length, 1);
  });

  test(
    'explicit retry rolls back only a hash-proven owned unregistered commit after reopen',
    () async {
      final id = 'owned-crash-journal';
      final audio = File(FilePaths.getAudioPath(id));
      final partialPath = '${audio.path}.download-123.part';
      final marker = File('$partialPath.owner.json');
      await audio.writeAsBytes([1, 2, 3, 4], flush: true);
      await marker.writeAsString(
        jsonEncode({
          'schema': 1,
          'ytid': id,
          'audioPath': audio.path,
          'partialPath': partialPath,
          'expectedBytes': 4,
          'sha256': sha256.convert([1, 2, 3, 4]).toString(),
        }),
        flush: true,
      );
      await Hive.close();
      Hive.init('${root.path}/hive');
      for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
        await Hive.openBox(name);
      }
      var calls = 0;
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async {
            calls++;
            return body([9, 10, 11, 12]);
          },
        ),
        isTrue,
      );
      expect(calls, 1); // Redownload; do not adopt even the proven owned body.
      expect(await audio.readAsBytes(), [9, 10, 11, 12]);
      expect(await marker.exists(), isFalse);
      final ids = (Hive.box('userNoBackup').get('offlineSongs') as List)
          .map((row) => row['ytid'])
          .toList();
      expect(ids, ['keep-owned', id]);
      expect(await File(FilePaths.getAudioPath('keep-owned')).readAsBytes(), [
        7,
        8,
        9,
      ]);
      expect(Hive.box('user').get('likedSongs'), [
        {'ytid': 'keep-liked'},
      ]);
    },
  );

  test(
    'mismatched ownership proof preserves unknown file and marker without registration',
    () async {
      final id = 'owned-tampered-journal';
      final audio = File(FilePaths.getAudioPath(id));
      final partialPath = '${audio.path}.download-124.part';
      final marker = File('$partialPath.owner.json');
      await audio.writeAsBytes([4, 3, 2, 1], flush: true);
      final text = jsonEncode({
        'schema': 1,
        'ytid': id,
        'audioPath': audio.path,
        'partialPath': partialPath,
        'expectedBytes': 4,
        'sha256': sha256.convert([1, 2, 3, 4]).toString(),
      });
      await marker.writeAsString(text, flush: true);
      var calls = 0;
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async {
            calls++;
            return body([9, 10]);
          },
        ),
        isFalse,
      );
      expect(calls, 0);
      expect(await audio.readAsBytes(), [4, 3, 2, 1]);
      expect(await marker.readAsString(), text);
      expect((Hive.box('userNoBackup').get('offlineSongs') as List).length, 1);
    },
  );

  test(
    'owned probes observe complete body then durable registration before return',
    () async {
      final seen = <OfflineCommitBoundary>[];
      final id = 'owned-probe';
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async => body([1, 2, 3, 4]),
          commitProbe: (boundary) async {
            seen.add(boundary);
            final registered =
                (Hive.box('userNoBackup').get('offlineSongs') as List)
                    .whereType<Map>()
                    .any((row) => row['ytid'] == id);
            if (boundary.index < OfflineCommitBoundary.registryWritten.index)
              expect(registered, isFalse);
            if (boundary.index >= OfflineCommitBoundary.registryWritten.index)
              expect(registered, isTrue);
            if (boundary.index >= OfflineCommitBoundary.afterRename.index)
              expect(await File(FilePaths.getAudioPath(id)).readAsBytes(), [
                1,
                2,
                3,
                4,
              ]);
          },
        ),
        isTrue,
      );
      expect(seen, OfflineCommitBoundary.values);
    },
  );

  test(
    'malformed durable registry is preserved despite a cached valid entry',
    () async {
      await Hive.box(
        'userNoBackup',
      ).put('offlineSongs', 'owned malformed state');
      var calls = 0;
      expect(
        await makeSongOffline(
          song('keep-owned'),
          audioLoader: (_) async {
            calls++;
            return body([1, 2, 3, 4]);
          },
        ),
        isFalse,
      );
      expect(calls, 0);
      expect(
        Hive.box('userNoBackup').get('offlineSongs'),
        'owned malformed state',
      );
      expect(await File(FilePaths.getAudioPath('keep-owned')).readAsBytes(), [
        7,
        8,
        9,
      ]);
    },
  );

  test(
    'download deletion cancels an active body before clearing durable registration',
    () async {
      final listened = Completer<void>();
      final stream = StreamController<List<int>>(
        onListen: () => listened.complete(),
      );
      final result = makeSongOffline(
        song('owned-clear'),
        audioLoader: (_) async =>
            OfflineAudioDownload(stream.stream, expectedBytes: 4),
      );
      await listened.future;
      stream.add([1, 2]);
      await offlinePlaylistService.deleteAllDownloads().timeout(
        const Duration(seconds: 3),
      );
      expect(await result, isFalse);
      expect(Hive.box('userNoBackup').get('offlineSongs'), isEmpty);
      expect(
        await File(FilePaths.getAudioPath('owned-clear')).exists(),
        isFalse,
      );
      expect(Hive.box('user').get('likedSongs'), [
        {'ytid': 'keep-liked'},
      ]);
      await stream.close();
    },
  );

  test(
    'same-recording overlap performs one transfer and one durable registration',
    () async {
      final listened = Completer<void>();
      final stream = StreamController<List<int>>(
        onListen: () => listened.complete(),
      );
      var calls = 0;
      Future<OfflineAudioDownload?> loader(String _) async {
        calls++;
        return OfflineAudioDownload(stream.stream, expectedBytes: 4);
      }

      final first = makeSongOffline(song('owned-overlap'), audioLoader: loader);
      final second = makeSongOffline(
        song('owned-overlap'),
        audioLoader: loader,
      );
      await listened.future;
      stream.add([1, 2, 3, 4]);
      await stream.close();
      expect(await Future.wait([first, second]), [true, true]);
      expect(calls, 1);
      expect(userOfflineSongs.value.map((row) => row['ytid']), [
        'keep-owned',
        'owned-overlap',
      ]);
    },
  );

  test(
    'different recording commits serialize without losing either membership',
    () async {
      expect(
        await Future.wait([
          for (final id in ['owned-one', 'owned-two'])
            makeSongOffline(
              song(id),
              audioLoader: (_) async => body([1, 2, 3, 4]),
            ),
        ]),
        [true, true],
      );
      final ids = userOfflineSongs.value.map((row) => row['ytid']).toList();
      expect(ids, unorderedEquals(['keep-owned', 'owned-one', 'owned-two']));
      expect(ids.first, 'keep-owned');
    },
  );

  test(
    'cancellation closes a stalled body and leaves no final file or new registry',
    () async {
      final listened = Completer<void>();
      var upstreamCancelled = false;
      final stream = StreamController<List<int>>(
        onListen: () => listened.complete(),
        onCancel: () => upstreamCancelled = true,
      );
      var cancelled = false;
      final result = makeSongOffline(
        song('owned-cancel'),
        audioLoader: (_) async =>
            OfflineAudioDownload(stream.stream, expectedBytes: 4),
        shouldCancel: () => cancelled,
      );
      await listened.future;
      stream.add([1, 2]);
      cancelled = true;
      expect(await result.timeout(const Duration(seconds: 2)), isFalse);
      expect(upstreamCancelled, isTrue);
      expect(
        await File(FilePaths.getAudioPath('owned-cancel')).exists(),
        isFalse,
      );
      expect(userOfflineSongs.value.map((row) => row['ytid']), ['keep-owned']);
      await stream.close();
    },
  );

  test(
    'partial registry writer failure rolls back membership and new file across reopen',
    () async {
      expect(
        await makeSongOffline(
          song('owned-rollback'),
          audioLoader: (_) async => body([1, 2, 3, 4]),
          registryWriter: (box, values) async {
            await box.put('offlineSongs', values);
            throw const FileSystemException('Owned registry failure');
          },
        ),
        isFalse,
      );
      expect(
        await File(FilePaths.getAudioPath('owned-rollback')).exists(),
        isFalse,
      );
      await Hive.close();
      await initPriorityReviewHive();
      expect(
        (Hive.box('userNoBackup').get('offlineSongs') as List).map(
          (row) => row['ytid'],
        ),
        ['keep-owned'],
      );
      expect(await File(FilePaths.getAudioPath('keep-owned')).readAsBytes(), [
        7,
        8,
        9,
      ]);
    },
  );

  test(
    'oversized and unknown-length bodies do not publish completion',
    () async {
      for (final id in ['owned-oversized', 'owned-unknown']) {
        expect(
          await makeSongOffline(
            song(id),
            audioLoader: (_) async => id == 'owned-oversized'
                ? body([1, 2, 3, 4, 5], expected: 4)
                : OfflineAudioDownload(Stream.value([1, 2])),
          ),
          isFalse,
        );
        expect(await File(FilePaths.getAudioPath(id)).exists(), isFalse);
      }
      expect(userOfflineSongs.value.map((row) => row['ytid']), ['keep-owned']);
    },
  );

  testWidgets('partial playlist never claims complete offline availability', (
    tester,
  ) async {
    await tester.pumpWidget(
      priorityReviewApp(child: const Scaffold(), brightness: Brightness.light),
    );
    final context = tester.element(find.byType(Scaffold));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await offlinePlaylistService.downloadPlaylist(
        context,
        {
          'ytid': 'owned-partial-playlist',
          'title': 'Owned partial playlist',
          'list': [
            song('owned-good-one'),
            song('owned-good-two'),
            song('owned-bad'),
          ],
        },
        audioLoader: (id) async =>
            body(id == 'owned-bad' ? [1, 2] : [1, 2, 3, 4], expected: 4),
      );
    });
    expect(
      offlinePlaylistService.isPlaylistDownloaded('owned-partial-playlist'),
      isFalse,
    );
    expect(
      userOfflineSongs.value.map((row) => row['ytid']),
      unorderedEquals(['keep-owned', 'owned-good-one', 'owned-good-two']),
    );
  });

  test(
    'successful transfer durably commits complete file and registry then repeats without requests',
    () async {
      var calls = 0;
      Future<OfflineAudioDownload?> loader(String _) async {
        calls++;
        return body([1, 2, 3, 4]);
      }

      expect(
        await makeSongOffline(song('owned-success'), audioLoader: loader),
        isTrue,
      );
      expect(
        await File(FilePaths.getAudioPath('owned-success')).readAsBytes(),
        [1, 2, 3, 4],
      );
      await Hive.close();
      await initPriorityReviewHive();
      reloadSongLibraryStateFromStorage();
      expect(userOfflineSongs.value.map((row) => row['ytid']), [
        'keep-owned',
        'owned-success',
      ]);
      expect(
        await makeSongOffline(song('owned-success'), audioLoader: loader),
        isTrue,
      );
      expect(calls, 1);
      expect(await File(FilePaths.getAudioPath('keep-owned')).readAsBytes(), [
        7,
        8,
        9,
      ]);
      expect(Hive.box('user').get('likedSongs'), [
        {'ytid': 'keep-liked'},
      ]);
    },
  );

  test(
    'unknown existing file is preserved and never silently adopted or overwritten',
    () async {
      final existing = File(FilePaths.getAudioPath('owned-legacy'));
      await existing.writeAsBytes([9, 9, 9]);
      final ok = await makeSongOffline(
        song('owned-legacy'),
        audioLoader: (_) async => body([1, 2, 3]),
      );
      expect(ok, isFalse);
      expect(await existing.readAsBytes(), [9, 9, 9]);
      expect(userOfflineSongs.value.map((row) => row['ytid']), ['keep-owned']);
    },
  );

  test('truncated body never publishes final file or registry', () async {
    expect(
      await makeSongOffline(
        song('owned-truncated'),
        audioLoader: (_) async => body([1, 2], expected: 4),
      ),
      isFalse,
    );
    expect(
      await File(FilePaths.getAudioPath('owned-truncated')).exists(),
      isFalse,
    );
    expect(userOfflineSongs.value.map((row) => row['ytid']), ['keep-owned']);
  });

  test(
    'failed body preserves existing library and permits bounded explicit retry',
    () async {
      Stream<List<int>> failed() async* {
        yield [1, 2];
        throw const FileSystemException('Owned body interruption');
      }

      expect(
        await makeSongOffline(
          song('owned-retry'),
          audioLoader: (_) async =>
              OfflineAudioDownload(failed(), expectedBytes: 4),
        ),
        isFalse,
      );
      expect(
        await File(FilePaths.getAudioPath('owned-retry')).exists(),
        isFalse,
      );
      expect(
        await makeSongOffline(
          song('owned-retry'),
          audioLoader: (_) async => body([1, 2, 3, 4]),
        ),
        isTrue,
      );
      expect(userOfflineSongs.value.map((row) => row['ytid']), [
        'keep-owned',
        'owned-retry',
      ]);
    },
  );
}
