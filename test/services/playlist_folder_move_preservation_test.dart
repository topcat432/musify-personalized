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
}
