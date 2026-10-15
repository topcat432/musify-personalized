import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/playlist_song_rename.dart';
import 'package:musify/services/playlists_manager.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map playlist;
  late Map shared;
  late Map alternative;
  late List<Map> songs;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('playlist-rename-service-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    shared = {'ytid': 'same', 'title': 'Shared', 'artist': 'Artist'};
    alternative = {'ytid': 'same', 'title': 'Chosen', 'artist': 'Version artist', 'version': 'live', 'typed': Uint8List.fromList([1, 2]), 'at': DateTime.utc(2026, 1, 1)};
    songs = [shared, alternative, shared];
    playlist = {'ytid': 'customId-rename', 'source': 'user-created', 'title': 'Fixture', 'list': songs, 'legacy': {'keep': true}};
    userCustomPlaylists.value = [playlist];
    await Hive.box('user').put('customPlaylists', [playlist]);
  });
  tearDown(() async { await Hive.close(); await root.delete(recursive: true); });
  PlaylistSongRename token() => PlaylistSongRename(playlist, sourceIndex: 1, expectedSong: alternative);

  for (final folder in [false, true]) {
    test('selected alternative only, metadata and reopen preserved: folder=$folder', () async {
      final other = {'opaque': {'keep': true}, 'list': <Map>[]};
      final key = folder ? 'playlistFolders' : 'customPlaylists';
      final collection = folder
          ? <Map>[{'id': 'folder', 'name': 'Folder', 'playlists': [playlist, other]}]
          : <Map>[playlist, other];
      if (folder) {
        userCustomPlaylists.value = [];
        await Hive.box('user').put('customPlaylists', <Map>[]);
        userPlaylistFolders.value = collection;
      } else { userCustomPlaylists.value = collection; }
      await Hive.box('user').put(key, collection);
      final result = await token().apply(title: ' Renamed ', artist: ' New artist ');
      expect(result, isNotNull);
      final renamed = (result!['list'] as List)[1] as Map;
      expect(renamed['title'], 'Renamed');
      expect(renamed['artist'], 'New artist');
      expect(renamed['version'], 'live');
      expect(renamed['typed'], isA<Uint8List>());
      expect(renamed['typed'], [1, 2]);
      expect((renamed['at'] as DateTime).isUtc, isTrue);
      expect(renamed.keys.toSet(), alternative.keys.toSet());
      expect(alternative['title'], 'Chosen');
      expect(shared['title'], 'Shared');
      expect((result['list'] as List).map((s) => s['title']), ['Shared', 'Renamed', 'Shared']);
      await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
      final stored = Hive.box('user').get(key) as List;
      final children = folder ? stored.single['playlists'] as List : stored;
      expect((children.first['list'] as List).map((s) => s['title']), ['Shared', 'Renamed', 'Shared']);
      expect(children.last, other);
      expect(children.first['legacy'], {'keep': true});
    });
  }

  for (final change in ['replace-row', 'change-row', 'reorder', 'replace-playlist', 'duplicate-playlist', 'pending-other', 'stored-only']) {
    test('stale or ambiguous rename refuses without writing: $change', () async {
      final rename = token();
      final other = {'opaque': true, 'list': <Map>[]};
      switch (change) {
        case 'replace-row': songs[1] = {...alternative};
          // Equal-value replacement alone is safe; changing its recording must refuse.
          songs[1]['version'] = 'different';
        case 'change-row': alternative['title'] = 'Owner changed';
        case 'reorder': playlist['list'] = songs.reversed.toList()..[0] = alternative;
        case 'replace-playlist': userCustomPlaylists.value = [{...playlist}];
        case 'duplicate-playlist': userCustomPlaylists.value = [playlist, {...playlist}];
        case 'pending-other': userCustomPlaylists.value = [playlist, other];
        case 'stored-only': await Hive.box('user').put('customPlaylists', [playlist, other]);
      }
      await Hive.box('user').flush();
      final before = await File('${root.path}/user.hive').readAsBytes();
      var writes = 0;
      expect(await rename.apply(title: 'Renamed', artist: 'New', write: (key, value) async { writes++; await Hive.box('user').put(key, value); }), isNull);
      expect(writes, 0);
      await Hive.box('user').flush();
      expect(await File('${root.path}/user.hive').readAsBytes(), before);
      expect(await rename.apply(title: 'Retry', artist: 'New'), isNull);
    });
  }

  for (final change in ['folder-name', 'folder-child', 'stored-only']) {
    test('folder divergence preserves both states before writing: $change', () async {
      final other = {'opaque': {'keep': true}, 'list': <Map>[]};
      final storedFolder = <String, dynamic>{'id': 'folder', 'name': 'Saved folder', 'playlists': [playlist, other]};
      final liveFolder = <String, dynamic>{
        ...storedFolder,
        'name': change == 'folder-name' ? 'Pending folder' : 'Saved folder',
        'playlists': [playlist, if (change != 'stored-only') (change == 'folder-child' ? {...other, 'pending': true} : other)],
      };
      userCustomPlaylists.value = [];
      await Hive.box('user').put('customPlaylists', <Map>[]);
      userPlaylistFolders.value = [liveFolder];
      await Hive.box('user').put('playlistFolders', [storedFolder]);
      await Hive.box('user').flush();
      final before = await File('${root.path}/user.hive').readAsBytes();
      var writes = 0;
      expect(await token().apply(title: 'Renamed', artist: 'New', write: (key, value) async { writes++; await Hive.box('user').put(key, value); }), isNull);
      expect(writes, 0);
      expect(userPlaylistFolders.value, [liveFolder]);
      await Hive.box('user').flush();
      expect(await File('${root.path}/user.hive').readAsBytes(), before);
      await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
      expect(Hive.box('user').get('playlistFolders'), [storedFolder]);
    });
  }

  test('overlapping repeat consumes one writer before awaiting', () async {
    final rename = token();
    final gate = Completer<void>();
    var writes = 0;
    final first = rename.apply(title: 'Renamed', artist: 'New', write: (key, value) async { writes++; await gate.future; await Hive.box('user').put(key, value); });
    expect(await rename.apply(title: 'Again', artist: 'Other'), isNull);
    expect(writes, 1);
    gate.complete();
    expect(await first, isNotNull);
    expect((Hive.box('user').get('customPlaylists').single['list'] as List)[1]['title'], 'Renamed');
  });

  test('failure before saving retains byte-exact old file and live values', () async {
    await Hive.box('user').flush();
    final before = await File('${root.path}/user.hive').readAsBytes();
    final rename = token();
    expect(await rename.apply(title: 'Renamed', artist: 'New', write: (_, _) async { throw StateError('synthetic before save'); }), isNull);
    expect(alternative['title'], 'Chosen');
    await Hive.box('user').flush();
    expect(await File('${root.path}/user.hive').readAsBytes(), before);
    expect(await rename.apply(title: 'Retry', artist: 'New'), isNull);
  });

  test('uncertain saved result is retained across reopen without replay', () async {
    final rename = token();
    expect(await rename.apply(title: 'Renamed', artist: 'New', write: (key, value) async { await Hive.box('user').put(key, value); throw StateError('synthetic after save'); }), isNull);
    expect(alternative['title'], 'Chosen');
    expect(await rename.apply(title: 'Retry', artist: 'New'), isNull);
    await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
    expect((Hive.box('user').get('customPlaylists').single['list'] as List).map((s) => s['title']), ['Shared', 'Renamed', 'Shared']);
  });

  test('newer saved owner write wins without compensation', () async {
    final owner = {...playlist, 'title': 'Owner', 'list': [{'ytid': 'owner', 'title': 'Owner song'}]};
    expect(await token().apply(title: 'Renamed', artist: 'New', write: (key, value) async { await Hive.box('user').put(key, value); userCustomPlaylists.value = [owner]; await Hive.box('user').put(key, [owner]); }), isNull);
    expect(userCustomPlaylists.value, [owner]);
    await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
    expect(Hive.box('user').get('customPlaylists'), [owner]);
  });

  test('pending edit during save refuses publication without overwriting it', () async {
    expect(await token().apply(title: 'Renamed', artist: 'New', write: (key, value) async { await Hive.box('user').put(key, value); playlist['title'] = 'Pending owner'; }), isNull);
    expect(userCustomPlaylists.value.single['title'], 'Pending owner');
    expect(alternative['title'], 'Chosen');
  });

  test('reversed visible slots save the original source order', () async {
    final bridge = {'ytid': 'bridge', 'title': 'Bridge', 'artist': 'B'};
    playlist['list'] = [shared, alternative, bridge, shared];
    await Hive.box('user').put('customPlaylists', [playlist]);
    playlist['list'] = [shared, bridge, alternative, shared];
    final rename = PlaylistSongRename(playlist, sourceIndex: 2, expectedSong: alternative, sourceOrder: [3, 2, 1, 0]);
    final result = await rename.apply(title: 'Renamed', artist: 'New');
    expect(result, isNotNull);
    expect((result!['list'] as List).map((s) => s['title']), ['Shared', 'Renamed', 'Bridge', 'Shared']);
    await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
    expect((Hive.box('user').get('customPlaylists').single['list'] as List).map((s) => s['title']), ['Shared', 'Renamed', 'Bridge', 'Shared']);
  });

  test('invalid source permutations cannot drop or duplicate occurrences', () async {
    for (final order in [[0, 0, 2], [-1, 1, 2], [0, 1]]) {
      var writes = 0;
      final rename = PlaylistSongRename(playlist, sourceIndex: 1, expectedSong: alternative, sourceOrder: order);
      expect(await rename.apply(title: 'Renamed', artist: 'New', write: (_, _) async { writes++; }), isNull);
      expect(writes, 0);
    }
  });

  test('blank fields and invalid positions cannot write', () async {
    for (final index in [-1, 3]) {
      var writes = 0;
      expect(await PlaylistSongRename(playlist, sourceIndex: index, expectedSong: alternative).apply(title: 'New', artist: 'Artist', write: (_, _) async { writes++; }), isNull);
      expect(writes, 0);
    }
    expect(await token().apply(title: ' ', artist: 'Artist'), isNull);
    expect(await token().apply(title: 'Title', artist: ' '), isNull);
    expect(Hive.box('user').get('customPlaylists'), [playlist]);
  });
}
