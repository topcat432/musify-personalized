import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/playlist_slot_undo.dart';
import 'package:musify/services/playlists_manager.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map playlist;
  late List<dynamic> remaining;
  late Map removed;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('playlist-undo-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    remaining = [
      {'ytid': 'same', 'title': 'First'},
      {'ytid': 'other', 'title': 'Other'},
      {'ytid': 'same', 'title': 'Last'},
    ];
    removed = {
      'ytid': 'same',
      'title': 'Chosen alternative',
      'details': {
        'bytes': Uint8List.fromList([1, 2, 3]),
        'at': DateTime.utc(2026, 1, 1),
      },
    };
    playlist = {
      'ytid': 'customId-undo',
      'source': 'user-created',
      'title': 'Fixture',
      'list': remaining,
      'legacy': {'keep': true},
    };
    userCustomPlaylists.value = [playlist];
    await Hive.box('user').put('customPlaylists', [playlist]);
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  PlaylistSlotUndo token() => PlaylistSlotUndo(
    playlist,
    remainingSourceSongs: remaining,
    removedSong: removed,
    sourceIndex: 1,
  );
  test(
    'one-shot restore preserves chosen values, repeats, legacy metadata and loaded unrelated playlists',
    () async {
      final undo = token();
      removed['ytid'] = 'mutated';
      (removed['details']['bytes'] as Uint8List)[0] = 9;
      final source = undo.restoredSource(remaining)!;
      final manual = {
        'ytid': 'customId-manual',
        'source': 'user-created',
        'list': [],
        'name': 'Owner extra',
      };
      userCustomPlaylists.value = [playlist, manual];
      await Hive.box('user').put('customPlaylists', [playlist, manual]);
      final result = await undo.apply(
        expectedCurrentSongs: remaining,
        currentSourceOrder: [0, 1, 2],
        restoredOrder: List.generate(source.length, (i) => i),
      );
      expect(result, isNotNull);
      expect((result!['list'] as List).map((s) => s['ytid']), [
        'same',
        'same',
        'other',
        'same',
      ]);
      expect(
        result['list'][1]['details']['bytes'],
        Uint8List.fromList([1, 2, 3]),
      );
      expect(result['legacy'], {'keep': true});
      expect(userCustomPlaylists.value.last, manual);
      expect(undo.restoredSource(remaining), isNull);
      expect(
        await undo.apply(
          expectedCurrentSongs: remaining,
          currentSourceOrder: [0, 1, 2],
          restoredOrder: List.generate(source.length, (i) => i),
        ),
        isNull,
      );
      await Hive.close();
      Hive.init(root.path);
      await initPriorityReviewHive();
      final stored = Hive.box('user').get('customPlaylists') as List;
      expect(stored.length, 2);
      expect(stored.first, result);
    },
  );
  test(
    'source snapshot rejects edits and an identical-ID replaced destination is never adopted',
    () async {
      final undo = token();
      remaining[0]['title'] = 'Owner edit';
      expect(undo.restoredSource(remaining), isNull);
      final replacementUndo = token();
      final replacement = Map.of(playlist);
      userCustomPlaylists.value = [replacement];
      await Hive.box('user').put('customPlaylists', [replacement]);
      var writes = 0;
      expect(
        await replacementUndo.apply(
          expectedCurrentSongs: remaining,
          currentSourceOrder: [0, 1, 2],
          restoredOrder: [0, 1, 2, 3],
          write: (key, value) async {
            writes++;
          },
        ),
        isNull,
      );
      expect(writes, 0);
      expect(replacement['list'], remaining);
    },
  );
  test(
    'ambiguous root/folder target and malformed legacy collections refuse without writes',
    () async {
      for (final malformed in [false, true]) {
        final undo = token();
        await Hive.box('user').put(
          'playlistFolders',
          malformed
              ? 'retained legacy value'
              : [
                  {
                    'id': 'folder',
                    'playlists': [Map.of(playlist)],
                  },
                ],
        );
        var writes = 0;
        expect(
          await undo.apply(
            expectedCurrentSongs: remaining,
            currentSourceOrder: [0, 1, 2],
            restoredOrder: [0, 1, 2, 3],
            write: (key, value) async {
              writes++;
            },
          ),
          isNull,
        );
        expect(writes, 0);
      }
    },
  );
  test(
    'overlapping repeat is consumed before awaiting one successful write',
    () async {
      final undo = token();
      final source = undo.restoredSource(remaining)!;
      final gate = Completer<void>();
      var writes = 0;
      final pending = undo.apply(
        expectedCurrentSongs: remaining,
        currentSourceOrder: [0, 1, 2],
        restoredOrder: List.generate(source.length, (i) => i),
        write: (key, value) async {
          writes++;
          await gate.future;
          await Hive.box('user').put(key, value);
        },
      );
      expect(undo.used, isTrue);
      expect(
        await undo.apply(
          expectedCurrentSongs: remaining,
          currentSourceOrder: [0, 1, 2],
          restoredOrder: List.generate(source.length, (i) => i),
        ),
        isNull,
      );
      gate.complete();
      expect(await pending, isNotNull);
      expect(writes, 1);
    },
  );
  test(
    'failed write leaves old map and stored value unchanged; token does not replay',
    () async {
      final undo = token();
      final source = undo.restoredSource(remaining)!;
      expect(
        await undo.apply(
          expectedCurrentSongs: remaining,
          currentSourceOrder: [0, 1, 2],
          restoredOrder: List.generate(source.length, (i) => i),
          write: (key, value) async {
            throw const FileSystemException('synthetic write rejection');
          },
        ),
        isNull,
      );
      expect(playlist['list'], remaining);
      expect(Hive.box('user').get('customPlaylists'), [playlist]);
      expect(undo.used, isTrue);
    },
  );
  test(
    'error after saving retains saved value and never compensates over it',
    () async {
      final undo = token();
      final source = undo.restoredSource(remaining)!;
      expect(
        await undo.apply(
          expectedCurrentSongs: remaining,
          currentSourceOrder: [0, 1, 2],
          restoredOrder: List.generate(source.length, (i) => i),
          write: (key, value) async {
            await Hive.box('user').put(key, value);
            throw StateError('synthetic after-save failure');
          },
        ),
        isNull,
      );
      expect(
        (Hive.box('user').get('customPlaylists').single['list'] as List).length,
        4,
      );
      expect(undo.used, isTrue);
      await Hive.close();
      Hive.init(root.path);
      await initPriorityReviewHive();
      expect(
        (Hive.box('user').get('customPlaylists').single['list'] as List).length,
        4,
      );
    },
  );
  test(
    'late independent owner write wins without rollback or global replacement',
    () async {
      final undo = token();
      final source = undo.restoredSource(remaining)!;
      final owner = {
        'ytid': 'customId-undo',
        'source': 'user-created',
        'title': 'Owner changed',
        'list': [
          {'ytid': 'owner'},
        ],
      };
      expect(
        await undo.apply(
          expectedCurrentSongs: remaining,
          currentSourceOrder: [0, 1, 2],
          restoredOrder: List.generate(source.length, (i) => i),
          write: (key, value) async {
            await Hive.box('user').put(key, value);
            userCustomPlaylists.value = [owner];
            await Hive.box('user').put(key, [owner]);
          },
        ),
        isNull,
      );
      expect(userCustomPlaylists.value.single, owner);
      expect(Hive.box('user').get('customPlaylists'), [owner]);
    },
  );
  test(
    'invalid slot orders cannot drop or duplicate retained entries',
    () async {
      for (final badCurrent in [false, true]) {
        final undo = token();
        var writes = 0;
        expect(
          await undo.apply(
            expectedCurrentSongs: remaining,
            currentSourceOrder: badCurrent ? [0, 0, 2] : [0, 1, 2],
            restoredOrder: badCurrent ? [0, 1, 2, 3] : [0, 0, 2, 3],
            write: (key, value) async {
              writes++;
            },
          ),
          isNull,
        );
        expect(writes, 0);
        expect(Hive.box('user').get('customPlaylists'), [playlist]);
      }
    },
  );
  test(
    'typed metadata changes are stale despite equal scalar values',
    () async {
      for (final bytes in [false, true]) {
        remaining[0] = Map<String, dynamic>.from(remaining[0] as Map);
        remaining[0]['typed'] = bytes
            ? Uint8List.fromList([1, 2])
            : DateTime.utc(2026, 1, 1);
        final undo = token();
        remaining[0]['typed'] = bytes
            ? <int>[1, 2]
            : DateTime.utc(2026, 1, 1).toLocal();
        expect(undo.restoredSource(remaining), isNull);
        var writes = 0;
        expect(
          await undo.apply(
            expectedCurrentSongs: remaining,
            currentSourceOrder: [0, 1, 2],
            restoredOrder: [0, 1, 2, 3],
            write: (key, value) async {
              writes++;
            },
          ),
          isNull,
        );
        expect(writes, 0);
      }
    },
  );
  test(
    'pending live metadata edits are not overwritten by Undo publication',
    () async {
      final other = {
        'ytid': 'customId-other',
        'source': 'user-created',
        'title': 'Before',
        'list': <Map>[],
      };
      userCustomPlaylists.value = [playlist, other];
      await Hive.box('user').put('customPlaylists', [playlist, other]);
      final undo = token();
      final source = undo.restoredSource(remaining)!;
      final result = await undo.apply(
        expectedCurrentSongs: remaining,
        currentSourceOrder: [0, 1, 2],
        restoredOrder: List.generate(source.length, (i) => i),
        write: (key, value) async {
          await Hive.box('user').put(key, value);
          playlist['title'] = 'Owner pending name';
          other['title'] = 'Owner pending other';
        },
      );
      expect(result, isNull);
      expect(userCustomPlaylists.value.first['title'], 'Owner pending name');
      expect(userCustomPlaylists.value.last['title'], 'Owner pending other');
      expect(undo.used, isTrue);
    },
  );
  for (final state in ['root', 'folder-child', 'folder-name']) {
    test('pre-apply live divergence is refused before writing: $state', () async {
      final savedOther = <String, dynamic>{
        'ytid': 'customId-other',
        'source': 'user-created',
        'title': 'Saved other',
        'list': <Map>[],
      };
      final pendingOther = {...savedOther, 'title': 'Pending other'};
      final folder = state != 'root';
      final key = folder ? 'playlistFolders' : 'customPlaylists';
      final List<Map> stored;
      final List<Map> live;
      if (folder) {
        final savedFolder = <String, dynamic>{
          'id': 'folder',
          'name': 'Saved folder',
          'playlists': [playlist, savedOther],
        };
        stored = [savedFolder];
        live = [
          {
            ...savedFolder,
            'name': state == 'folder-name' ? 'Pending folder' : 'Saved folder',
            'playlists': [
              playlist,
              state == 'folder-child' ? pendingOther : savedOther,
            ],
          },
        ];
        userCustomPlaylists.value = [];
        await Hive.box('user').put('customPlaylists', <Map>[]);
        userPlaylistFolders.value = live;
      } else {
        stored = [playlist, savedOther];
        live = [playlist, pendingOther];
        userCustomPlaylists.value = live;
      }
      await Hive.box('user').put(key, stored);
      final rawTarget = folder
          ? (Hive.box('user').get(key).first['playlists'] as List).first
          : Hive.box('user').get(key).first;
      final liveTarget = folder
          ? (live.first['playlists'] as List).first
          : live.first;
      // Target-only identity checks must pass in this regression.
      expect(identical(rawTarget, liveTarget), isTrue);
      final undo = token();
      var writes = 0;
      final result = await undo.apply(
        expectedCurrentSongs: remaining,
        currentSourceOrder: [0, 1, 2],
        restoredOrder: [0, 1, 2, 3],
        write: (key, value) async {
          writes++;
          await Hive.box('user').put(key, value);
        },
      );
      expect(result, isNull);
      expect(writes, 0);
      expect(Hive.box('user').get(key), stored);
      expect(folder ? userPlaylistFolders.value : userCustomPlaylists.value, live);
      if (state == 'folder-name') {
        expect(userPlaylistFolders.value.first['name'], 'Pending folder');
      } else {
        final items = folder
            ? userPlaylistFolders.value.first['playlists'] as List
            : userCustomPlaylists.value;
        expect(items.last['title'], 'Pending other');
      }
    });
  }
  for (final folder in [false, true]) {
    test(
      'stored-only legacy entries remain untouched when live omits them: folder=$folder',
      () async {
        final legacy = {
          'opaque': {
            'version': 99,
            'bytes': Uint8List.fromList([4, 5]),
            'at': DateTime.utc(2026, 1, 1),
          },
          'list': <Map>[],
        };
        final key = folder ? 'playlistFolders' : 'customPlaylists';
        final List<Map> stored;
        final List<Map> live;
        if (folder) {
          stored = [
            {'id': 'folder', 'name': 'Fixture', 'playlists': [playlist, legacy]},
          ];
          live = [
            {'id': 'folder', 'name': 'Fixture', 'playlists': [playlist]},
          ];
          userCustomPlaylists.value = [];
          await Hive.box('user').put('customPlaylists', <Map>[]);
          userPlaylistFolders.value = live;
        } else {
          stored = [playlist, legacy];
          live = [playlist];
          userCustomPlaylists.value = live;
        }
        await Hive.box('user').put(key, stored);
        await Hive.box('user').flush();
        final beforeBytes = await File('${root.path}/user.hive').readAsBytes();
        final undo = token();
        var writes = 0;
        expect(
          await undo.apply(
            expectedCurrentSongs: remaining,
            currentSourceOrder: [0, 1, 2],
            restoredOrder: [0, 1, 2, 3],
            write: (key, value) async {
              writes++;
              await Hive.box('user').put(key, value);
            },
          ),
          isNull,
        );
        expect(writes, 0);
        expect(folder ? userPlaylistFolders.value : userCustomPlaylists.value, live);
        await Hive.box('user').flush();
        expect(await File('${root.path}/user.hive').readAsBytes(), beforeBytes);
        await Hive.close();
        Hive.init(root.path);
        await initPriorityReviewHive();
        expect(Hive.box('user').get(key), stored);
      },
    );
  }
}
