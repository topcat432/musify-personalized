import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/utilities/queue_entry_utils.dart';

import '../../tool/visual_review_harness.dart';
import '../support/spotify_empty_source_fixture.dart';

// Existing-format feasibility only. No occurrence writer or ownership migration.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('occurrence-schema-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    await SpotifyEmptySourceFixture.seed();
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  Object? copy(Object? value) => jsonDecode(jsonEncode(value));
  Map<String, dynamic> repeatedPlaylist() => {
    'ytid': 'customId-occurrence-schema', 'title': 'Synthetic ordered repeats',
    'source': 'user-created', 'createdAt': 1,
    'list': [
      {'ytid': 'chosen-alternative', 'title': 'Chosen version', 'artist': 'Fixture'},
      {'ytid': 'chosen-B', 'title': 'Other recording', 'artist': 'Fixture'},
      {'ytid': 'chosen-alternative', 'title': 'Chosen version', 'artist': 'Fixture'},
    ],
    'unknownLegacyField': {'partial': true},
  };
  Future<void> reopen(String path) async {
    await Hive.close(); Hive.init(path); await initPriorityReviewHive();
  }

  test('existing playlist map retains repeated ordered slots on Hive reopen without adoption', () async {
    final playlist = repeatedPlaylist();
    await Hive.box('user').put('customPlaylists', [playlist]);
    final before = copy(Hive.box('user').toMap());
    await reopen(root.path);
    expect(Hive.box('user').toMap(), before);
    final stored = (Hive.box('user').get('customPlaylists') as List).single as Map;
    expect((stored['list'] as List).map((song) => song['ytid']),
      ['chosen-alternative', 'chosen-B', 'chosen-alternative']);
    expect(stored.keys.toSet(), playlist.keys.toSet());
    expect((stored['list'] as List).every((song) => !(song as Map).containsKey('queueEntryId')), isTrue);
  });

  test('saved-file checksum inspection and independent restore retain repeated slots and legacy fields', () async {
    await Hive.box('user').put('customPlaylists', [repeatedPlaylist()]);
    final before = copy(Hive.box('user').toMap());
    await Hive.box('user').flush(); await Hive.box('settings').flush();
    final bytes = await MusifyBackupService.createBundleBytesForTesting({
      'user': await File('${root.path}/user.hive').readAsBytes(),
      'settings': await File('${root.path}/settings.hive').readAsBytes(),
    });
    final saved = File('${root.path}/synthetic.musifybackup');
    await saved.writeAsBytes(bytes, flush: true);
    final inspected = await MusifyBackupService.inspectBundleFileForTesting(saved);
    final independent = await Directory('${root.path}/independent').create();
    await reopen(independent.path);
    await Hive.box('user').put('wrongTarget', true);
    expect((await MusifyBackupService.restoreValidatedBackup(inspected)).success, isTrue);
    await reopen(independent.path);
    expect(Hive.box('user').toMap(), before);
  });

  test('existing owned-write rollback preserves legacy repeated slots and partial fields after restart', () async {
    await Hive.box('user').put('customPlaylists', [repeatedPlaylist()]);
    final before = copy(Hive.box('user').toMap());
    final writer = SpotifyImportDestinationService(destinationWriter: (box, key, value) async {
      await box.put(key, value);
      throw StateError('Synthetic partial write');
    });
    final snapshot = await writer.loadSourcePlaylistSnapshot(1);
    await expectLater(writer.createEmptySourcePlaylist(snapshot: snapshot), throwsStateError);
    expect(Hive.box('user').toMap(), before);
    await reopen(root.path);
    expect(Hive.box('user').toMap(), before);
  });

  test('queue cloning assigns distinct runtime identities to repeats without changing durable song maps', () {
    final songs = List<Map>.from(repeatedPlaylist()['list']);
    final before = copy(songs);
    final manager = QueueEntryIdManager();
    final queue = songs.map(manager.createSong).toList();
    expect(queue.map((song) => song['ytid']), ['chosen-alternative', 'chosen-B', 'chosen-alternative']);
    expect(queue.map((song) => song['queueEntryId']).toSet().length, 3);
    expect(songs, before);
    queue.last['title'] = 'Runtime edit';
    expect(songs, before);
    expect(queue.first['title'], 'Chosen version');
  });
}
