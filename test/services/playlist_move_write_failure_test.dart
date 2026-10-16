import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/playlist_slot_undo.dart';
import 'package:musify/services/playlist_song_rename.dart';
import 'package:musify/services/playlists_manager.dart';

import '../../tool/visual_review_harness.dart';

dynamic _copy(dynamic value) {
  if (value is Uint8List) return Uint8List.fromList(value);
  if (value is List) return value.map(_copy).toList();
  if (value is Map) return value.map((key, item) => MapEntry(key, _copy(item)));
  return value;
}

void main() {
  late Directory root;
  late Map<String, dynamic> selected;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('owned-move-failure-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    selected = {
      'ytid': 'owned-move',
      'source': 'user-created',
      'title': 'Owned playlist',
      'list': [
        {'ytid': 'recording-a', 'version': 'chosen'},
        {'ytid': 'recording-a', 'version': 'alternate'},
        {'ytid': 'tail'},
      ],
      'bytes': Uint8List.fromList([4, 8]),
      'at': DateTime.utc(2026, 1, 1),
      'opaque': {'retain': 42},
    };
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  Box<dynamic> box() => Hive.box('user');
  Map live() =>
      _copy({
            'playlistFolders': userPlaylistFolders.value,
            'customPlaylists': userCustomPlaylists.value,
            'playlists': userPlaylists.value,
          })
          as Map;
  Future<void> put(String key, List<dynamic>? value) =>
      value == null ? box().delete(key) : box().put(key, value);
  Future<void> seed(String direction, {bool absentRoot = false}) async {
    final youtube = direction.startsWith('youtube');
    final atRoot = direction.endsWith('root-folder');
    if (youtube) selected['source'] = 'user-youtube';
    userCustomPlaylists.value = [
      if (!absentRoot) {'ytid': 'root-other', 'source': 'user-created'},
      if (atRoot && !youtube) selected,
    ];
    userPlaylists.value = [
      'youtube-other',
      if (atRoot && youtube) 'owned-move',
    ];
    userPlaylistFolders.value = [
      {
        'id': 'source',
        'name': 'Source',
        'playlists': [
          {'ytid': 'folder-other'},
          if (!atRoot) selected,
        ],
      },
      {
        'id': 'target',
        'name': 'Target',
        'playlists': [
          {'ytid': 'target-other'},
        ],
      },
    ];
    userLikedPlaylists.value = [_copy(selected) as Map];
    pinnedPlaylistIds.value = ['owned-move'];
    await box().putAll({
      'playlistFolders': userPlaylistFolders.value,
      'customPlaylists': userCustomPlaylists.value,
      'playlists': userPlaylists.value,
      'likedPlaylists': userLikedPlaylists.value,
      'pinnedPlaylistIds': pinnedPlaylistIds.value,
      'ownedUnrelated': {
        'keep': Uint8List.fromList([9]),
        'at': DateTime.utc(2026, 2, 1),
      },
    });
    if (absentRoot) await box().delete('customPlaylists');
    await box().flush();
  }

  int memberships() {
    final maps = <Map>[
      ...(box().get('customPlaylists', defaultValue: []) as List).cast<Map>(),
      for (final folder
          in box().get('playlistFolders', defaultValue: []) as List)
        ...(folder['playlists'] as List).cast<Map>(),
    ];
    return maps.where((item) => item['ytid'] == 'owned-move').length +
        (box().get('playlists', defaultValue: []) as List)
            .where((id) => id == 'owned-move')
            .length;
  }

  Future<void> reopen() async {
    await box().flush();
    await Hive.close();
    Hive.init(root.path);
    await initPriorityReviewHive();
  }

  Future<void> withContext(
    WidgetTester tester,
    Future<void> Function(BuildContext) action,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      priorityReviewApp(
        brightness: Brightness.light,
        child: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => action(context));
    await tester.pumpWidget(const SizedBox.shrink());
  }

  String? target(String direction) =>
      direction.endsWith('folder-root') ? null : 'target';

  testWidgets(
    'folder-to-root failure retains original membership after reopen',
    (tester) async {
      await withContext(tester, (context) async {
        await seed('custom-folder-root', absentRoot: true);
        final before = _copy(box().toMap());
        final beforeLive = live();
        final errors = <Object>[];
        final completion = Completer<String>();
        runZonedGuarded(() {
          Future<String>.sync(
            () => movePlaylistToFolder(
              selected,
              null,
              context,
              write: (key, value) async {
                if (key == 'customPlaylists')
                  throw StateError('Owned destination failure');
                await put(key, value);
              },
            ),
          ).then(completion.complete, onError: completion.completeError);
        }, (error, _) => errors.add(error));
        final result = await completion.future;
        await Future<void>.delayed(Duration.zero);
        await box().flush();
        await reopen();
        expect(memberships(), 1, reason: 'MOVE_FAILURE_LOST_SOURCE_MEMBERSHIP');
        expect(box().toMap(), before);
        expect(live(), beforeLive);
        expect(result, context.l10n!.error);
        expect(errors, isEmpty);
      });
    },
  );

  const directions = [
    'custom-root-folder',
    'custom-folder-root',
    'youtube-root-folder',
    'youtube-folder-root',
    'custom-folder-folder',
  ];
  for (final direction in directions) {
    for (final phase in [
      'destination-before',
      'destination-after',
      if (direction != 'custom-folder-folder') 'source-before',
      if (direction != 'custom-folder-folder') 'source-after',
    ]) {
      testWidgets('move fault restores owned state: $direction $phase', (
        tester,
      ) async {
        await withContext(tester, (context) async {
          await seed(direction);
          final before = _copy(box().toMap());
          final beforeLive = live();
          var calls = 0;
          var failed = false;
          var notifications = 0;
          void changed() {
            notifications++;
          }

          userPlaylistFolders.addListener(changed);
          userCustomPlaylists.addListener(changed);
          userPlaylists.addListener(changed);
          try {
            final result = await movePlaylistToFolder(
              selected,
              target(direction),
              context,
              write: (key, value) async {
                final fail =
                    !failed &&
                    ++calls == (phase.startsWith('destination') ? 1 : 2);
                if (fail) failed = true;
                if (fail && phase.endsWith('before'))
                  throw StateError('Owned before-write failure');
                await put(key, value);
                if (fail && phase.endsWith('after'))
                  throw StateError('Owned after-save failure');
              },
            );
            expect(failed, isTrue);
            expect(result, context.l10n!.error);
            expect(live(), beforeLive);
            expect(notifications, 0);
            await reopen();
            expect(box().toMap(), before);
            expect(memberships(), 1);
          } finally {
            userPlaylistFolders.removeListener(changed);
            userCustomPlaylists.removeListener(changed);
            userPlaylists.removeListener(changed);
          }
        });
      });
    }
    testWidgets('move awaits acknowledgment and rejects overlap: $direction', (
      tester,
    ) async {
      await withContext(tester, (context) async {
        await seed(direction);
        final before = live();
        final gate = Completer<void>();
        final keys = <String>[];
        final moving = movePlaylistToFolder(
          selected,
          target(direction),
          context,
          write: (key, value) async {
            keys.add(key);
            if (keys.length == 1) await gate.future;
            await put(key, value);
          },
        );
        await Future<void>.delayed(Duration.zero);
        expect(live(), before);
        expect(keys, hasLength(1));
        expect(
          await movePlaylistToFolder(selected, target(direction), context),
          context.l10n!.error,
        );
        gate.complete();
        expect(await moving, '${context.l10n!.addedSuccess}!');
        expect(
          keys.first,
          target(direction) != null
              ? 'playlistFolders'
              : direction.startsWith('youtube')
              ? 'playlists'
              : 'customPlaylists',
        );
        final after = _copy(box().toMap());
        expect(
          await movePlaylistToFolder(
            selected,
            target(direction),
            context,
            write: (_, _) => throw StateError('Repeat must not write'),
          ),
          '${context.l10n!.addedSuccess}!',
        );
        await reopen();
        expect(box().toMap(), after);
        expect(memberships(), 1);
        for (final folder in box().get('playlistFolders') as List) {
          for (final item in folder['playlists'] as List) {
            if (item['ytid'] == 'owned-move') expect(item, selected);
          }
        }
      });
    });
  }

  for (final owner in [
    'live-source',
    'stored-source',
    'stored-destination',
    'stored-other',
  ]) {
    testWidgets('move preserves newer owner: $owner', (tester) async {
      await withContext(tester, (context) async {
        await seed('custom-root-folder');
        var calls = 0;
        late Map expectedDisk;
        late Map expectedLive;
        final result = await movePlaylistToFolder(
          selected,
          'target',
          context,
          write: (key, value) async {
            calls++;
            await put(key, value);
            if (owner == 'live-source') {
              userCustomPlaylists.value = [
                ...userCustomPlaylists.value.take(1),
                {...selected, 'title': 'New live owner'},
              ];
            } else if (owner == 'stored-source') {
              await box().put('customPlaylists', [
                ...userCustomPlaylists.value.take(1),
                {...selected, 'title': 'New stored owner'},
              ]);
            } else if (owner == 'stored-destination') {
              final folders = _copy(box().get('playlistFolders')) as List;
              folders.last['owner'] = 'New target owner';
              await box().put('playlistFolders', folders);
            } else {
              await box().put('playlists', ['youtube-other', 'new-owner']);
            }
            expectedDisk = _copy(box().toMap()) as Map;
            expectedLive = live();
          },
        );
        expect(result, contains('could not be verified'));
        expect(calls, 1);
        expect(live(), expectedLive);
        await reopen();
        expect(box().toMap(), expectedDisk);
        expect(memberships(), greaterThanOrEqualTo(1));
      });
    });
  }

  for (final failure in [
    'restore-source-before',
    'restore-source-after',
    'restore-destination-before',
    'restore-destination-after',
  ]) {
    testWidgets('move compensation never removes its last copy: $failure', (
      tester,
    ) async {
      await withContext(tester, (context) async {
        await seed('custom-root-folder');
        final before = _copy(box().toMap());
        final beforeLive = live();
        var calls = 0;
        final result = await movePlaylistToFolder(
          selected,
          'target',
          context,
          write: (key, value) async {
            calls++;
            final recoveryFault =
                calls == (failure.startsWith('restore-source') ? 3 : 4);
            if (recoveryFault && failure.endsWith('before'))
              throw StateError('Owned restoration failure');
            await put(key, value);
            if (calls == 2 || (recoveryFault && failure.endsWith('after')))
              throw StateError('Owned post-save failure');
          },
        );
        expect(live(), beforeLive);
        await reopen();
        expect(memberships(), greaterThanOrEqualTo(1));
        if (failure.endsWith('after')) {
          expect(box().toMap(), before);
          expect(result, context.l10n!.error);
        } else {
          expect(result, contains('could not be verified'));
        }
      });
    });
  }
  testWidgets('move rollback preserves an originally absent root key', (
    tester,
  ) async {
    await withContext(tester, (context) async {
      await seed('custom-folder-root', absentRoot: true);
      final before = _copy(box().toMap());
      var calls = 0;
      final result = await movePlaylistToFolder(
        selected,
        null,
        context,
        write: (key, value) async {
          calls++;
          await put(key, value);
          if (calls == 2)
            throw StateError('Owned source acknowledgment failure');
        },
      );
      expect(result, context.l10n!.error);
      await reopen();
      expect(box().containsKey('customPlaylists'), isFalse);
      expect(box().toMap(), before);
    });
  });
  testWidgets('move rollback retains a newer destination owner', (
    tester,
  ) async {
    await withContext(tester, (context) async {
      await seed('custom-root-folder');
      var calls = 0;
      late Map expected;
      final result = await movePlaylistToFolder(
        selected,
        'target',
        context,
        write: (key, value) async {
          calls++;
          await put(key, value);
          if (calls == 2)
            throw StateError('Owned source acknowledgment failure');
          if (calls == 3) {
            final folders = _copy(box().get('playlistFolders')) as List;
            folders.last['owner'] = 'New owner during compensation';
            await box().put('playlistFolders', folders);
            expected = _copy(box().toMap()) as Map;
          }
        },
      );
      expect(result, contains('could not be verified'));
      expect(calls, 3);
      await reopen();
      expect(box().toMap(), expected);
      expect(memberships(), 2);
    });
  });
  for (final direction in ['custom-root-folder', 'custom-folder-root', 'custom-folder-folder']) {
    for (final failed in [false, true]) {
      testWidgets('move keeps rename and Undo usable: $direction failed=$failed', (tester) async {
        await withContext(tester, (context) async {
          await seed(direction);
          var calls = 0;
          final result = await movePlaylistToFolder(selected, target(direction), context, write: (key, value) async {
            calls++; await put(key, value);
            if (failed && calls == (direction == 'custom-folder-folder' ? 1 : 2)) {
              throw StateError('Owned post-save failure before continued editing');
            }
          });
          expect(result, failed ? context.l10n!.error : '${context.l10n!.addedSuccess}!');
          final current = getUserCustomPlaylists().singleWhere((item) => item['ytid'] == 'owned-move');
          final expected = _copy(selected) as Map;
          (expected['list'] as List)[1] = {...(expected['list'] as List)[1] as Map,
            'title': 'Owned changed title', 'artist': 'Owned changed artist'};
          final renamed = await PlaylistSongRename(current, sourceIndex: 1,
            expectedSong: (current['list'] as List)[1] as Map).apply(title: 'Owned changed title', artist: 'Owned changed artist');
          expect(renamed, isNotNull, reason: 'MOVE_PUBLICATION_LOST_WRITER_OWNERSHIP');
          final removed = (renamed!['list'] as List)[1] as Map;
          expect(removeSongFromPlaylist(renamed, removed, removeOneAtIndex: 1), isTrue);
          await Future<void>.delayed(Duration.zero); await box().flush();
          final remaining = List<dynamic>.from(renamed['list'] as List);
          final undo = PlaylistSlotUndo(renamed, remainingSourceSongs: remaining, removedSong: removed, sourceIndex: 1);
          expect(await undo.apply(expectedCurrentSongs: remaining, currentSourceOrder: [0, 1], restoredOrder: [0, 1, 2]), isNotNull);
          expect(await undo.apply(expectedCurrentSongs: remaining, currentSourceOrder: [0, 1], restoredOrder: [0, 1, 2]), isNull);
          await reopen();
          final maps = <Map>[
            ...(box().get('customPlaylists', defaultValue: []) as List).cast<Map>(),
            for (final folder in box().get('playlistFolders') as List) ...(folder['playlists'] as List).cast<Map>(),
          ];
          expect(maps.singleWhere((item) => item['ytid'] == 'owned-move'), expected);
          expect(memberships(), 1);
          expect(box().get('likedPlaylists'), [selected]);
          expect(box().get('pinnedPlaylistIds'), ['owned-move']);
        });
      });
    }
  }

}
