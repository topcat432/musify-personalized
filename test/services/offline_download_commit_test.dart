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

  for (final fail in [false, true]) {
    test(
      'review residual removal serializes with commit, failure=$fail',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        var removalEntered = false;
        final download = makeSongOffline(
          song('serialized-remove-$fail'),
          audioLoader: (_) async => body([1, 2, 3, 4]),
          commitProbe: (at) async {
            if (at == OfflineCommitBoundary.beforeRename) {
              entered.complete();
              await release.future;
            }
          },
          registryWriter: fail
              ? (box, values) async {
                  await box.put('offlineSongs', values);
                  throw StateError('Synthetic writer failure');
                }
              : null,
        );
        await entered.future;
        final removal = removeSongFromOffline(
          'keep-owned',
          mutationProbe: () async {
            removalEntered = true;
          },
        );
        try {
          await Future<void>.delayed(Duration.zero);
          expect(
            removalEntered,
            isFalse,
            reason: 'Removal must not mutate inside another registry commit',
          );
        } finally {
          release.complete();
          await Future.wait([download, removal]);
        }
        expect(
          (Hive.box('userNoBackup').get('offlineSongs') as List)
              .whereType<Map>()
              .any((r) => r['ytid'] == 'keep-owned'),
          isFalse,
        );
      },
    );
  }
  for (final sameId in [false, true]) {
    test(
      'review residual rollback preserves newer durable row, same identity=$sameId',
      () async {
        final id = 'rollback-newer-$sameId';
        late Map<String, dynamic> newer;
        expect(
          await makeSongOffline(
            song(id),
            audioLoader: (_) async => body([1, 2, 3, 4]),
            registryWriter: (box, values) async {
              await box.put('offlineSongs', values);
              newer = sameId
                  ? {
                      ...(values.last as Map).cast<String, dynamic>(),
                      'title': 'Newer durable row',
                    }
                  : {
                      'ytid': 'new-durable',
                      'title': 'Newer durable row',
                      'audioPath': FilePaths.getAudioPath('keep-owned'),
                    };
              final latest = List<dynamic>.from(values);
              if (sameId) {
                latest[latest.length - 1] = newer;
              } else {
                latest.add(newer);
              }
              await box.put('offlineSongs', latest);
              await box.flush();
              throw StateError('Synthetic failure after a newer durable write');
            },
          ),
          isFalse,
        );
        final rows = Hive.box('userNoBackup').get('offlineSongs') as List;
        expect(
          rows.whereType<Map>().where((r) => r['title'] == 'Newer durable row'),
          [newer],
        );
        if (sameId)
          expect(await File(FilePaths.getAudioPath(id)).readAsBytes(), [
            1,
            2,
            3,
            4,
          ]);
      },
    );
  }
  test(
    'review residual rollback preserves newer in-place durable row',
    () async {
      const id = 'rollback-in-place';
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async => body([1, 2, 3, 4]),
          registryWriter: (box, values) async {
            await box.put('offlineSongs', values);
            (values.last as Map)['title'] = 'Newer in-place durable row';
            await box.put('offlineSongs', values);
            await box.flush();
            throw StateError(
              'Synthetic failure after in-place durable revision',
            );
          },
        ),
        isFalse,
      );
      expect(
        (Hive.box('userNoBackup').get('offlineSongs') as List)
            .whereType<Map>()
            .singleWhere((row) => row['ytid'] == id)['title'],
        'Newer in-place durable row',
      );
      expect(await File(FilePaths.getAudioPath(id)).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
    },
  );

  for (final boundary in [
    OfflinePlaylistCompletionBoundary.membersValidated,
    OfflinePlaylistCompletionBoundary.relatedSongsValidated,
  ]) {
    testWidgets(
      'review residual clear-all owns pending playlist completion at ${boundary.name}',
      (tester) async {
        await tester.pumpWidget(
          priorityReviewApp(
            child: const Scaffold(),
            brightness: Brightness.light,
          ),
        );
        final context = tester.element(find.byType(Scaffold));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          final entered = Completer<void>(), release = Completer<void>();
          var completions = 0;
          final task = offlinePlaylistService.downloadPlaylist(
            context,
            {
              'ytid': 'clear-completion',
              'title': 'Synthetic',
              'list': [song('keep-owned')],
            },
            completionProbe: (at) async {
              if (at == boundary) {
                entered.complete();
                await release.future;
              }
              if (at == OfflinePlaylistCompletionBoundary.registryCommitted)
                completions++;
            },
          );
          await entered.future;
          try {
            await offlinePlaylistService.deleteAllDownloads();
          } finally {
            release.complete();
          }
          await task;
          expect(Hive.box('userNoBackup').get('offlineSongs'), isEmpty);
          expect(
            Hive.box('userNoBackup').get('offlinePlaylists', defaultValue: []),
            isEmpty,
          );
          expect(userOfflineSongs.value, isEmpty);
          expect(offlinePlaylistService.offlinePlaylists.value, isEmpty);
          expect(completions, 0);
        });
      },
    );
  }

  for (final kind in [
    'empty',
    'interrupted',
    'complete',
    'collision',
    'existing-empty',
  ]) {
    test('optional artwork $kind never registers a false path', () async {
      final id = 'art-$kind';
      final art = File(FilePaths.getArtworkPath(id));
      if (kind == 'existing-empty') await art.writeAsBytes([]);
      var calls = 0;
      expect(
        await makeSongOffline(
          {
            ...song(id),
            'highResImage': 'https://example.invalid/art',
            'artworkPath': '/unrelated/inherited.jpg',
          },
          audioLoader: (_) async => body([1, 2, 3, 4]),
          artworkLoader: (_) async {
            calls++;
            if (kind == 'interrupted')
              throw StateError('synthetic interrupted response');
            if (kind == 'collision')
              await art.writeAsBytes([9, 9], flush: true);
            return kind == 'empty' ? [] : [3, 4, 5];
          },
        ),
        isTrue,
      );
      final rows = Hive.box('userNoBackup').get('offlineSongs') as List;
      final row = rows.whereType<Map>().singleWhere((row) => row['ytid'] == id);
      expect(row['artworkPath'], kind == 'complete' ? art.path : isNull);
      if (kind == 'complete') expect(await art.readAsBytes(), [3, 4, 5]);
      if (kind == 'collision') expect(await art.readAsBytes(), [9, 9]);
      if (kind == 'existing-empty') {
        expect(calls, 0);
        expect(await art.length(), 0);
      }
      expect(
        await art.parent
            .list()
            .where((entry) => entry.path.endsWith('.part'))
            .isEmpty,
        isTrue,
      );
    });
  }

  test(
    'owned retry preserves a final payload referenced by another registered identity',
    () async {
      final id = 'owned-shared-proof';
      final audio = File(FilePaths.getAudioPath(id));
      final partialPath = '${audio.path}.download-126.part';
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
      final registry = List<dynamic>.from(
        Hive.box('userNoBackup').get('offlineSongs'),
      )..add({'ytid': 'owned-alias', 'audioPath': audio.path});
      await Hive.box('userNoBackup').put('offlineSongs', registry);
      var calls = 0;
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async {
            calls++;
            return body([9, 10, 11, 12]);
          },
        ),
        isFalse,
      );
      expect(calls, 0);
      expect(await audio.readAsBytes(), [1, 2, 3, 4]);
      expect(Hive.box('userNoBackup').get('offlineSongs'), registry);
      expect(await marker.exists(), isTrue);
    },
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

  testWidgets(
    'registered empty or tampered playlist member cannot be skipped or marked complete',
    (tester) async {
      await tester.pumpWidget(
        priorityReviewApp(
          child: const Scaffold(),
          brightness: Brightness.light,
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        for (final bytes in [
          <int>[],
          [9, 9, 9, 9],
        ]) {
          final id = bytes.isEmpty ? 'playlist-empty' : 'playlist-tampered';
          final file = File(FilePaths.getAudioPath(id));
          await file.writeAsBytes(bytes, flush: true);
          final row = {
            ...song(id),
            'audioPath': file.path,
            'offlineAudioBytes': 4,
            'offlineAudioSha256': sha256.convert([1, 2, 3, 4]).toString(),
          };
          final registry = [...userOfflineSongs.value, row];
          await Hive.box('userNoBackup').put('offlineSongs', registry);
          userOfflineSongs.value = registry;
          final playlist = {
            'ytid': '$id-list',
            'title': 'Synthetic playlist',
            'list': [song(id)],
          };
          offlinePlaylistService.offlinePlaylists.value = [playlist];
          var calls = 0;
          await offlinePlaylistService.downloadPlaylist(
            context,
            playlist,
            audioLoader: (_) async {
              calls++;
              return body([1, 2, 3, 4]);
            },
          );
          expect(calls, 0);
          expect(
            offlinePlaylistService.isPlaylistDownloaded('$id-list'),
            isFalse,
          );
          expect(isPlaylistFullyOffline([song(id)]), isFalse);
          expect(await file.readAsBytes(), bytes);
          expect(Hive.box('userNoBackup').get('offlineSongs'), registry);
        }
      });
    },
  );

  testWidgets('typed playlist rows without artwork remain complete on repeat', (
    tester,
  ) async {
    await tester.pumpWidget(
      priorityReviewApp(child: const Scaffold(), brightness: Brightness.light),
    );
    final context = tester.element(find.byType(Scaffold));
    await tester.pumpWidget(const SizedBox.shrink());
    var loads = 0;
    final playlist = {
      'ytid': 'owned-typed-playlist',
      'title': 'Owned typed playlist',
      'list': [
        <String, String>{'ytid': 'keep-owned', 'title': 'Keep existing'},
        <String, String>{'ytid': 'owned-typed-new', 'title': 'Owned new'},
      ],
    };
    await tester.runAsync(() async {
      for (var repeat = 0; repeat < 2; repeat++) {
        await offlinePlaylistService.downloadPlaylist(
          context,
          playlist,
          audioLoader: (_) async {
            loads++;
            return body([1, 2, 3, 4]);
          },
        );
        expect(
          offlinePlaylistService.isPlaylistDownloaded('owned-typed-playlist'),
          true,
        );
      }
      expect(loads, 1);
      final copies = offlinePlaylistService.offlinePlaylists.value
          .where((p) => p['ytid'] == 'owned-typed-playlist')
          .toList();
      expect(copies, hasLength(1));
      expect((copies.single['list'] as List).map((r) => r['ytid']), [
        'keep-owned',
        'owned-typed-new',
      ]);
      expect(await File(FilePaths.getAudioPath('keep-owned')).readAsBytes(), [
        7,
        8,
        9,
      ]);
    });
  });

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
    'final-path collision at publication preserves the other file',
    () async {
      const id = 'publication-collision';
      final finalFile = File(FilePaths.getAudioPath(id));
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async => body([1, 2, 3, 4]),
          commitProbe: (boundary) async {
            if (boundary == OfflineCommitBoundary.beforeRename)
              await finalFile.writeAsBytes([8, 8, 8], flush: true);
          },
        ),
        isFalse,
      );
      expect(await finalFile.readAsBytes(), [8, 8, 8]);
      expect(userOfflineSongs.value.map((row) => row['ytid']), ['keep-owned']);
    },
  );

  test(
    'registry compensation preserves a replacement at the final path',
    () async {
      const id = 'compensation-replacement';
      final finalFile = File(FilePaths.getAudioPath(id));
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async => body([1, 2, 3, 4]),
          registryWriter: (_, _) async {
            await finalFile.delete();
            await finalFile.writeAsBytes([8, 8, 8], flush: true);
            throw StateError(
              'Synthetic registration failure after replacement',
            );
          },
        ),
        isFalse,
      );
      expect(await finalFile.exists(), isTrue);
      expect(await finalFile.readAsBytes(), [8, 8, 8]);
      expect(userOfflineSongs.value.map((row) => row['ytid']), ['keep-owned']);
    },
  );

  for (final boundary in [
    OfflineCommitBoundary.beforeRename,
    OfflineCommitBoundary.afterRename,
  ]) {
    test(
      'truncation at ${boundary.name} cannot publish damaged audio',
      () async {
        const id = 'publication-truncated';
        final registry = List<dynamic>.from(userOfflineSongs.value);
        expect(
          await makeSongOffline(
            song(id),
            audioLoader: (_) async => body([1, 2, 3, 4]),
            commitProbe: (at) async {
              if (at != boundary) return;
              final target = boundary == OfflineCommitBoundary.afterRename
                  ? File(FilePaths.getAudioPath(id))
                  : Directory(
                      FilePaths.getAudioPath(id),
                    ).parent.listSync().whereType<File>().singleWhere(
                      (file) =>
                          file.path.contains(id) && file.path.endsWith('.part'),
                    );
              await target.writeAsBytes([], flush: true);
            },
          ),
          isFalse,
        );
        expect(Hive.box('userNoBackup').get('offlineSongs'), registry);
      },
    );
  }

  for (final exists in [false, true]) {
    test(
      'registered ${exists ? "empty" : "missing"} audio is not successful and is preserved',
      () async {
        final id = 'registered-invalid-$exists';
        final file = File(FilePaths.getAudioPath(id));
        if (exists) await file.writeAsBytes([]);
        final row = {...song(id), 'audioPath': file.path};
        final registry = [...userOfflineSongs.value, row];
        await Hive.box('userNoBackup').put('offlineSongs', registry);
        userOfflineSongs.value = registry;
        var calls = 0;
        expect(
          await makeSongOffline(
            song(id),
            audioLoader: (_) async {
              calls++;
              return body([1, 2, 3, 4]);
            },
          ),
          isFalse,
        );
        expect(calls, 0);
        expect(await file.exists(), exists);
        if (exists) expect(await file.length(), 0);
        expect(Hive.box('userNoBackup').get('offlineSongs'), registry);
      },
    );
  }

  for (final replacement in <List<int>>[
    [],
    [9, 9, 9, 9],
  ]) {
    test(
      'fault after stream completion cannot publish ${replacement.isEmpty ? "empty" : "changed"} payload',
      () async {
        const id = 'fault-before-publication';
        final registry = List<dynamic>.from(userOfflineSongs.value);
        final result = await makeSongOffline(
          song(id),
          audioLoader: (_) async => body([1, 2, 3, 4]),
          commitProbe: (boundary) async {
            if (boundary == OfflineCommitBoundary.bodyFlushed) {
              final partial = Directory(FilePaths.getAudioPath(id)).parent
                  .listSync()
                  .whereType<File>()
                  .singleWhere(
                    (file) =>
                        file.path.contains(id) && file.path.endsWith('.part'),
                  );
              await partial.writeAsBytes(replacement, flush: true);
            }
          },
        );
        expect(result, isFalse);
        expect(Hive.box('userNoBackup').get('offlineSongs'), registry);
      },
    );
  }

  test(
    'completed registration whose payload later becomes empty survives restart without false success',
    () async {
      const id = 'registered-after-interruption';
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async => body([1, 2, 3, 4]),
        ),
        isTrue,
      );
      final file = File(FilePaths.getAudioPath(id));
      await file.writeAsBytes(
        [],
        flush: true,
      ); // Synthetic storage-loss state, not a claim about its native cause.
      final registry = Hive.box('userNoBackup').get('offlineSongs');
      await Hive.close();
      await initPriorityReviewHive();
      reloadSongLibraryStateFromStorage();
      var calls = 0;
      expect(
        await makeSongOffline(
          song(id),
          audioLoader: (_) async {
            calls++;
            return body([5, 6, 7, 8]);
          },
        ),
        isFalse,
      );
      expect(calls, 0);
      expect(await file.length(), 0);
      expect(Hive.box('userNoBackup').get('offlineSongs'), registry);
    },
  );

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
