import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/playlists_manager.dart';

import '../../tool/visual_review_harness.dart';

dynamic _copy(dynamic value) {
  if (value is Uint8List) return Uint8List.fromList(value);
  if (value is Map) return value.map((key, item) => MapEntry(key, _copy(item)));
  if (value is List) return value.map(_copy).toList();
  return value;
}

void main() {
  late Directory root;
  late Map selected;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('owned-folder-move-');
    Hive.init(root.path); await initPriorityReviewHive(); resetPriorityReviewGlobals();
    selected = {'ytid': 'owned-selected', 'title': 'Owned playlist', 'source': 'user-created',
      'list': [{'ytid': 'owned-recording', 'title': 'First version'},
        {'ytid': 'owned-recording', 'title': 'Chosen version'},
        {'ytid': 'owned-recording', 'title': 'First version'}],
      'bytes': Uint8List.fromList([1, 2]), 'at': DateTime.utc(2026, 1, 1)};
  });
  tearDown(() async { await Hive.close(); await root.delete(recursive: true); });

  Future<void> seed({String? invalid, bool inRoot = false, bool youtube = false}) async {
    if (youtube) selected['source'] = 'user-youtube';
    userPlaylistFolders.value = [
      {'id': 'source', 'name': 'Source', 'opaque': {'keep': true},
        'playlists': [if (!inRoot) selected, {'ytid': 'source-other', 'title': 'Source other'}]},
      {'id': 'target', 'name': 'Target', 'playlists': [{'ytid': 'target-other', 'title': 'Target other'}]},
      if (invalid == 'duplicate') {'id': 'target', 'name': 'Ambiguous target', 'playlists': <Map>[]},
      if (invalid == 'malformed-list') {'id': 'opaque', 'playlists': 'retain opaque payload'},
      if (invalid == 'malformed-child') {'id': 'opaque', 'playlists': [{'ytid': 'opaque-child'}, 'retain opaque child']},
    ];
    userCustomPlaylists.value = [
      {'ytid': 'root-other', 'source': 'user-created', 'title': 'Root other'},
      if (inRoot && !youtube) selected,
    ];
    userPlaylists.value = ['youtube-other', if (inRoot && youtube) 'owned-selected'];
    userLikedPlaylists.value = [selected]; pinnedPlaylistIds.value = ['owned-selected'];
    await Hive.box('user').putAll({
      'playlistFolders': userPlaylistFolders.value,
      'customPlaylists': userCustomPlaylists.value,
      'playlists': userPlaylists.value,
      'likedPlaylists': userLikedPlaylists.value,
      'pinnedPlaylistIds': pinnedPlaylistIds.value,
      'ownedUnrelated': {'retain': true},
    });
    await Hive.box('user').flush();
  }

  Map snapshot() => _copy({
    'folders': userPlaylistFolders.value, 'custom': userCustomPlaylists.value,
    'youtube': userPlaylists.value, 'likes': userLikedPlaylists.value,
    'pins': pinnedPlaylistIds.value,
    'stored': Hive.box('user').toMap(),
  }) as Map;

  Future<void> withContext(WidgetTester tester, Future<void> Function(BuildContext) action) async {
    late BuildContext context;
    await tester.pumpWidget(priorityReviewApp(brightness: Brightness.light,
      child: Builder(builder: (value) { context = value; return const SizedBox.shrink(); })));
    await tester.pumpAndSettle();
    await tester.runAsync(() => action(context));
    await tester.pumpWidget(const SizedBox.shrink());
  }

  for (final invalid in ['missing', 'duplicate', 'malformed-list', 'malformed-child']) {
    testWidgets('rejected folder move preserves membership and stored bytes: $invalid', (tester) async {
      await withContext(tester, (context) async {
        await seed(invalid: invalid);
        final before = snapshot();
        final bytes = await File('${root.path}/user.hive').readAsBytes();
        var notifications = 0;
        void notified() { notifications++; }
        userPlaylistFolders.addListener(notified);
        userCustomPlaylists.addListener(notified);
        userPlaylists.addListener(notified);
        try {
          final result = movePlaylistToFolder(selected, invalid == 'missing' ? 'deleted-target' : 'target', context);
          expect(result, context.l10n!.error);
          expect(snapshot(), before, reason: 'REJECTED_FOLDER_MOVE_CHANGED_MEMBERSHIP');
          expect(notifications, 0);
          await Hive.box('user').flush();
          expect(await File('${root.path}/user.hive').readAsBytes(), bytes);
          await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
          expect(Hive.box('user').toMap(), before['stored']);
        } finally {
          userPlaylistFolders.removeListener(notified);
          userCustomPlaylists.removeListener(notified);
          userPlaylists.removeListener(notified);
        }
      });
    });
  }

  for (final mode in ['folder-to-folder', 'folder-to-root', 'custom-root-to-folder', 'youtube-root-to-folder']) {
    testWidgets('successful move preserves order typed payload and unrelated state: $mode', (tester) async {
      await withContext(tester, (context) async {
        await seed(inRoot: mode.contains('root-to'), youtube: mode.startsWith('youtube'));
        final oldFolders = userPlaylistFolders.value;
        final oldSnapshot = _copy(oldFolders);
        final toRoot = mode == 'folder-to-root';
        final changed = Hive.box('user').watch().where((event) =>
          ['playlistFolders', 'customPlaylists', 'playlists'].contains(event.key)).take(3).toList();
        expect(movePlaylistToFolder(selected, toRoot ? null : 'target', context), '${context.l10n!.addedSuccess}!');
        await changed.timeout(const Duration(seconds: 3));
        await Hive.box('user').flush();
        expect(oldFolders, oldSnapshot);
        final folders = userPlaylistFolders.value;
        expect((folders.first['playlists'] as List).map((p) => p['ytid']), ['source-other']);
        if (!toRoot) {
          expect((folders[1]['playlists'] as List).map((p) => p['ytid']), ['target-other', 'owned-selected']);
        }
        final storedBefore = _copy(Hive.box('user').toMap()) as Map;
        await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
        expect(Hive.box('user').toMap(), storedBefore);
        final saved = toRoot
            ? (Hive.box('user').get('customPlaylists') as List).last as Map
            : ((Hive.box('user').get('playlistFolders') as List)[1]['playlists'] as List).last as Map;
        expect(saved['list'], selected['list']);
        expect(saved['bytes'], isA<Uint8List>()); expect(saved['bytes'], [1, 2]);
        expect((saved['at'] as DateTime).isUtc, isTrue);
        expect(Hive.box('user').get('likedPlaylists'), [selected]);
        expect(Hive.box('user').get('pinnedPlaylistIds'), ['owned-selected']);
        expect(Hive.box('user').get('ownedUnrelated'), {'retain': true});
        expect((Hive.box('user').get('customPlaylists') as List).first['ytid'], 'root-other');
        expect(Hive.box('user').get('playlists'), ['youtube-other']);
      });
    });
  }
  for (final entry in [
    ('changed-root', true, false), ('changed-folder', false, false),
    ('deleted-root', true, false), ('deleted-folder', false, false),
    ('ambiguous-root', true, false), ('ambiguous-folder', false, false),
    ('cross-location', true, false), ('stored-only', true, false),
    ('live-only', true, false), ('unrelated-stored-only', true, false), ('source-type', false, false),
    ('typed-storage', true, false), ('youtube-deleted', true, true),
    ('youtube-duplicate', true, true),
  ]) {
    final (change, inRoot, youtube) = entry;
    testWidgets('retained source move refuses newer or missing owner: $change', (tester) async {
      await withContext(tester, (context) async {
        selected['ownerCount'] = 1;
        await seed(inRoot: inRoot, youtube: youtube);
        final requested = _copy(selected) as Map;
        final newer = (_copy(selected) as Map)
          ..['title'] = 'Newer owner playlist'
          ..['bytes'] = Uint8List.fromList([9, 8])
          ..['at'] = DateTime.utc(2026, 1, 1).toLocal()
          ..['list'] = [...selected['list'] as List, {'ytid': 'owned-newer', 'title': 'New owner member'}];
        void replaceSource(Map? value) {
          if (inRoot) {
            userCustomPlaylists.value = [
              userCustomPlaylists.value.first,
              if (value != null) value,
            ];
          } else {
            userPlaylistFolders.value = [
              {...userPlaylistFolders.value.first, 'playlists': [
                if (value != null) value, (userPlaylistFolders.value.first['playlists'] as List).last,
              ]},
              ...userPlaylistFolders.value.skip(1),
            ];
          }
        }
        Future<void> persist() => Hive.box('user').putAll({
          'playlistFolders': userPlaylistFolders.value,
          'customPlaylists': userCustomPlaylists.value,
          'playlists': userPlaylists.value,
        });
        if (change.startsWith('changed-') || change == 'live-only') replaceSource(newer);
        if (change.startsWith('deleted-')) replaceSource(null);
        if (change == 'ambiguous-root') userCustomPlaylists.value = [...userCustomPlaylists.value, _copy(selected) as Map];
        if (change == 'ambiguous-folder' || change == 'cross-location') {
          userPlaylistFolders.value = [
            {...userPlaylistFolders.value.first, 'playlists': [
              ...userPlaylistFolders.value.first['playlists'] as List, _copy(selected),
            ]},
            ...userPlaylistFolders.value.skip(1),
          ];
        }
        if (change == 'source-type') replaceSource({...selected, 'source': 'user-youtube'});
        if (change == 'youtube-deleted') userPlaylists.value = ['youtube-other'];
        if (change == 'youtube-duplicate') userPlaylists.value = ['youtube-other', 'owned-selected', 'owned-selected'];
        if (change != 'live-only') await persist();
        if (change == 'stored-only' || change == 'typed-storage') {
          await Hive.box('user').put('customPlaylists', [
            userCustomPlaylists.value.first,
            change == 'typed-storage' ? {...selected, 'ownerCount': 1.0} : newer,
          ]);
        }
        if (change == 'unrelated-stored-only') {
          await Hive.box('user').put('customPlaylists', [
            ...userCustomPlaylists.value, {'ytid': 'opaque-new-owner', 'opaque': {'keep': true}},
          ]);
        }
        await Hive.box('user').flush();
        final before = snapshot();
        final bytes = await File('${root.path}/user.hive').readAsBytes();
        expect(movePlaylistToFolder(requested, 'target', context), context.l10n!.error,
          reason: 'STALE_SOURCE_MOVE_MUST_REFUSE');
        expect(snapshot(), before);
        await Hive.box('user').flush();
        expect(await File('${root.path}/user.hive').readAsBytes(), bytes);
        await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
        expect(Hive.box('user').toMap(), before['stored']);
        if (change == 'typed-storage') {
          expect((Hive.box('user').get('customPlaylists') as List).last['ownerCount'], isA<double>());
        }
      });
    });
  }

  testWidgets('an equal retained card can move repeatedly without duplicating current source', (tester) async {
    await withContext(tester, (context) async {
      await seed(inRoot: true);
      final requested = _copy(selected) as Map;
      for (var attempt = 0; attempt < 2; attempt++) {
        final writes = Hive.box('user').watch().where((event) =>
          ['playlistFolders', 'customPlaylists', 'playlists'].contains(event.key)).take(3).toList();
        expect(movePlaylistToFolder(requested, 'target', context), '${context.l10n!.addedSuccess}!');
        await writes.timeout(const Duration(seconds: 3));
        await Hive.box('user').flush();
      }
      final target = userPlaylistFolders.value[1]['playlists'] as List;
      expect(target.map((p) => p['ytid']), ['target-other', 'owned-selected']);
      expect(target.last, selected);
      await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
      expect(((Hive.box('user').get('playlistFolders') as List)[1]['playlists'] as List).last, selected);
    });
  });

}
