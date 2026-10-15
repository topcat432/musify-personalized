import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/playlist_song_rename.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import 'package:musify/services/spotify_playlist_copy_proof.dart';

import '../../tool/visual_review_harness.dart';
import '../support/spotify_source_copy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const service = SpotifyImportDestinationService();
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('source-copy-writer-');
    Hive.init(root.path); await initPriorityReviewHive(); resetPriorityReviewGlobals();
    await SpotifySourceCopyFixture.seed();
  });
  tearDown(() async { await Hive.close(); await root.delete(recursive: true); });
  Future<void> reopen([String? path]) async {
    await Hive.close(); Hive.init(path ?? root.path); await initPriorityReviewHive(); SpotifySourceCopyFixture.hydrate();
  }
  Map<String, dynamic> metadata() => Map<String, dynamic>.from(Hive.box('user').get('spotifyImportMetadata'));
  List<Map> playlists() => List<Map>.from(Hive.box('user').get('customPlaylists', defaultValue: const []));
  Object? inventory() => copyImportRoutingValue(Hive.box('user').toMap());
  Future<void> modifyResults(void Function(List<Map>) edit) async {
    final results = (copyImportRoutingValue(Hive.box('user').get('spotifyMatchResults')) as List).cast<Map>();
    edit(results); await Hive.box('user').put('spotifyMatchResults', results);
  }

  test('read-only preview expands all original slots/alternatives and cannot mutate choices', () async {
    final before = inventory(); final preview = await service.previewSourcePlaylistCopy(1);
    expect(preview.slotCount, 3); expect(preview.uniqueRecordingCount, 2);
    expect(preview.songs.map((song) => song['ytid']), SpotifySourceCopyFixture.expectedIds);
    expect(inventory(), before);
    expect(() => preview.songs.clear(), throwsUnsupportedError);
    expect(() => preview.songs.first['title'] = 'mutated', throwsUnsupportedError);
    expect(() => (preview.songs.first['nested'] as Map)['keep'].clear(), throwsUnsupportedError);
  });
  test('creation/retry/reopen preserve exact repeats, unrelated typed values and baseline', () async {
    final before = Hive.box('user').toMap(); final baseline = copyImportRoutingValue(metadata()[importRoutingBaselineKey]);
    final preview = await service.previewSourcePlaylistCopy(1); final result = await service.createSourcePlaylistCopy(preview);
    expect(result.created, isTrue); expect(result.trackingRecorded, isTrue);
    expect(playlists().last['list'].map((song) => song['ytid']), SpotifySourceCopyFixture.expectedIds);
    expect(playlists().first, before['customPlaylists'][0]);
    for (final key in ['likedSongs', 'playlistFolders', 'playlists', 'pinnedPlaylistIds', 'ownerSentinel']) expect(Hive.box('user').get(key), before[key]);
    expect(metadata()[importRoutingBaselineKey], baseline);
    expect(metadata().containsKey(importRoutingPendingKey), isFalse);
    final saved = inventory(); expect((await service.createSourcePlaylistCopy(preview)).created, isFalse);
    expect(inventory(), saved); await reopen();
    expect((await service.createSourcePlaylistCopy(await service.previewSourcePlaylistCopy(1))).created, isFalse);
    expect(inventory(), saved); expect((playlists().first['at'] as DateTime).isUtc, isTrue);
    expect(playlists().last.containsKey('importSourcePlaylistKey'), isFalse);
    expect(playlists().last.containsKey('importSourceName'), isFalse);
    expect((playlists().last['list'] as List).every((song) => !song.containsKey('queueEntryId')), isTrue);
  });
  test('legacy count-only audit remains unknown; copied slots do not certify unique routing', () async {
    final value = metadata()..remove(importRoutingBaselineKey)..['routingHistory'] = [{'addedCount': 2}];
    await Hive.box('user').put('spotifyImportMetadata', value);
    await service.createSourcePlaylistCopy(await service.previewSourcePlaylistCopy(1));
    expect(metadata().containsKey(importRoutingBaselineKey), isFalse);
    expect((await service.loadSnapshot()).newlyResolvedBaselineKnown, isFalse);
    final audit = (metadata()['routingHistory'] as List).last as Map;
    expect(audit['copiedSlotCount'], 3); expect(audit['uniqueRecordingCount'], 2);
    expect(audit['recordingTransferBaselineAdvanced'], isFalse);
  });
  test('completed copy retains owner rename/folder move/removal/addition and no-op retry', () async {
    final preview = await service.previewSourcePlaylistCopy(1); await service.createSourcePlaylistCopy(preview);
    final rootValues = playlists(); final target = rootValues.removeLast();
    target['title'] = 'Owner renamed'; target['list'] = [{'ytid': 'manual-owner'}, {'ytid': 'chosen-B'}];
    final folders = List<Map>.from(Hive.box('user').get('playlistFolders'));
    (folders.first['playlists'] as List).add(target);
    await Hive.box('user').putAll({'customPlaylists': rootValues, 'playlistFolders': folders}); SpotifySourceCopyFixture.hydrate();
    final before = inventory(); final result = await service.createSourcePlaylistCopy(preview);
    expect(result.created, isFalse); expect(result.destinationTitle, 'Owner renamed'); expect(inventory(), before);
    await reopen(); expect((await service.createSourcePlaylistCopy(await service.previewSourcePlaylistCopy(1))).created, isFalse);
    expect(inventory(), before);
  });
  test('explicit additional-copy preview creates a new identity without adopting/editing old copy', () async {
    final first = await service.previewSourcePlaylistCopy(1); await service.createSourcePlaylistCopy(first);
    final ownerCopy = copyImportRoutingValue(playlists().last);
    final second = await service.previewSourcePlaylistCopy(1, additionalCopy: true);
    expect(second.proof.destinationId, isNot(first.proof.destinationId));
    await service.createSourcePlaylistCopy(second); expect(playlists(), hasLength(3));
    expect(playlists()[1], ownerCopy);
  });
  test('actual new owner supports renaming one repeated slot without changing marker or another slot', () async {
    final preview = await service.previewSourcePlaylistCopy(1); await service.createSourcePlaylistCopy(preview);
    final target = userCustomPlaylists.value.last; final list = target['list'] as List;
    final renamed = await PlaylistSongRename(target, sourceIndex: 2, expectedSong: list[2] as Map)
      .apply(title: 'Owner last occurrence', artist: 'Owner artist');
    expect(renamed, isNotNull); expect((renamed!['list'] as List).first['title'], 'Selected alternative A');
    expect((renamed['list'] as List).last['title'], 'Owner last occurrence');
    expect(renamed[SpotifyPlaylistCopyProof.markerKey], preview.proof.encode());
    final before = inventory(); await reopen();
    expect((await service.createSourcePlaylistCopy(await service.previewSourcePlaylistCopy(1))).created, isFalse);
    expect(inventory(), before);
  });

  for (final phase in ['checkpoint', 'destination', 'audit']) {
    for (final after in [false, true]) {
      test('$phase failure ${after ? 'after' : 'before'} Hive write retains honest phase/restart proof', () async {
        var metadataCalls = 0;
        final writer = SpotifyImportDestinationService(metadataWriter: (box, values) async {
          metadataCalls++; final fail = (phase == 'checkpoint' && metadataCalls == 1) || (phase == 'audit' && metadataCalls == 2);
          if (fail && !after) throw StateError('Injected $phase before');
          await box.put('spotifyImportMetadata', values);
          if (fail && after) throw StateError('Injected $phase after');
        }, destinationWriter: (box, key, values) async {
          if (phase == 'destination' && !after) throw StateError('Injected destination before');
          await box.put(key, values); if (phase == 'destination' && after) throw StateError('Injected destination after');
        });
        final before = inventory(); final preview = await writer.previewSourcePlaylistCopy(1);
        if (phase == 'audit') {
          final result = await writer.createSourcePlaylistCopy(preview); expect(result.created, isTrue); expect(result.trackingRecorded, isFalse);
        } else { await expectLater(writer.createSourcePlaylistCopy(preview), throwsStateError); }
        if (phase == 'checkpoint') expect(inventory(), before);
        else expect(metadata()[importRoutingPendingKey], isA<Map>());
        final interrupted = inventory(); await reopen(); expect(inventory(), interrupted);
        if (phase == 'destination') {
          expect(playlists(), hasLength(1)); await expectLater(service.previewSourcePlaylistCopy(1), throwsStateError);
        } else if (phase == 'audit') {
          var destinationWrites = 0;
          final recovery = SpotifyImportDestinationService(destinationWriter: (_, _, _) async { destinationWrites++; });
          final pending = await recovery.previewSourcePlaylistCopy(1); expect(pending.recoveringPending, isTrue);
          final recovered = await recovery.createSourcePlaylistCopy(pending);
          expect(recovered.created, isFalse); expect(recovered.trackingRecorded, isTrue); expect(destinationWrites, 0);
          expect(playlists(), hasLength(2)); expect(metadata().containsKey(importRoutingPendingKey), isFalse);
        }
      });
    }
  }
  for (final phase in ['checkpoint', 'destination', 'audit']) {
    test('unacknowledged $phase write cannot report success', () async {
      var calls = 0;
      final writer = SpotifyImportDestinationService(metadataWriter: (box, values) async {
        calls++; if ((phase == 'checkpoint' && calls == 1) || (phase == 'audit' && calls == 2)) return;
        await box.put('spotifyImportMetadata', values);
      }, destinationWriter: (box, key, values) async { if (phase != 'destination') await box.put(key, values); });
      final preview = await writer.previewSourcePlaylistCopy(1);
      if (phase == 'audit') expect((await writer.createSourcePlaylistCopy(preview)).trackingRecorded, isFalse);
      else await expectLater(writer.createSourcePlaylistCopy(preview), throwsStateError);
    });
  }
  test('shared routing lock spans both destination and awaited audit; concurrent previews/ordinary routes refuse', () async {
    final entered = Completer<void>(); final release = Completer<void>(); var writes = 0;
    final writer = SpotifyImportDestinationService(metadataWriter: (box, values) async {
      writes++; await box.put('spotifyImportMetadata', values);
      if (writes == 2) { entered.complete(); await release.future; }
    });
    final preview = await writer.previewSourcePlaylistCopy(1); final running = writer.createSourcePlaylistCopy(preview);
    await entered.future;
    await expectLater(service.createSourcePlaylistCopy(preview), throwsStateError);
    await expectLater(service.previewSourcePlaylistCopy(1), throwsStateError);
    release.complete(); expect((await running).trackingRecorded, isTrue);
  });
  for (final change in ['choice', 'payload', 'session', 'membership', 'exclude', 'unresolved']) {
    test('stale $change confirmation writes nothing over newer source state', () async {
      final preview = await service.previewSourcePlaylistCopy(1);
      if (change == 'choice') await modifyResults((rows) => rows.first['bestCandidate']['ytid'] = 'new-choice');
      if (change == 'payload') await modifyResults((rows) => rows.first['bestCandidate']['title'] = 'New chosen metadata');
      if (change == 'unresolved') await modifyResults((rows) => rows.first['status'] = 'unmatched');
      if (change == 'exclude') await Hive.box('user').put('spotifyExcludedImportRows', [1]);
      if (change == 'session') await Hive.box('user').put('spotifyImportMetadata', {...metadata(), 'importSessionId': 'new-session'});
      if (change == 'membership') {
        final value = copyImportRoutingValue(metadata()) as Map; value['sourcePlaylists']['playlists'][0]['name'] = 'Owner changed source';
        await Hive.box('user').put('spotifyImportMetadata', value);
      }
      final before = inventory(); await expectLater(service.createSourcePlaylistCopy(preview), throwsStateError); expect(inventory(), before);
    });
  }
  test('source changes during checkpoint preserve new choice without any destination write', () async {
    final writer = SpotifyImportDestinationService(metadataWriter: (box, values) async {
      await box.put('spotifyImportMetadata', values); await modifyResults((rows) => rows.first['bestCandidate']['ytid'] = 'new-owner-choice');
    });
    await expectLater(writer.createSourcePlaylistCopy(await writer.previewSourcePlaylistCopy(1)), throwsStateError);
    expect(playlists(), hasLength(1)); expect(Hive.box('user').get('spotifyMatchResults')[0]['bestCandidate']['ytid'], 'new-owner-choice');
  });
  for (final owner in ['stored-library', 'live-library', 'checkpoint-metadata', 'audit-metadata']) {
    test('newer $owner edit survives an uncertain callback without compensation overwrite', () async {
      var calls = 0;
      final writer = SpotifyImportDestinationService(metadataWriter: (box, values) async {
        calls++; await box.put('spotifyImportMetadata', values);
        if ((owner == 'checkpoint-metadata' && calls == 1) || (owner == 'audit-metadata' && calls == 2)) {
          await box.put('spotifyImportMetadata', {...values, 'ownerEdit': 'newer'});
        }
      }, destinationWriter: (box, key, values) async {
        await box.put(key, values);
        if (owner == 'stored-library') { (values.first as Map)['title'] = 'Newer stored owner'; await box.put(key, values); }
        if (owner == 'live-library') userCustomPlaylists.value.first['title'] = 'Newer live owner';
      });
      final preview = await writer.previewSourcePlaylistCopy(1);
      if (owner == 'audit-metadata') expect((await writer.createSourcePlaylistCopy(preview)).trackingRecorded, isFalse);
      else await expectLater(writer.createSourcePlaylistCopy(preview), throwsStateError);
      if (owner.endsWith('metadata')) expect(metadata()['ownerEdit'], 'newer');
      if (owner == 'stored-library') expect(playlists().first['title'], 'Newer stored owner');
      if (owner == 'live-library') expect(userCustomPlaylists.value.first['title'], 'Newer live owner');
    });
  }
  test('deleted or copied-marker destination is never adopted or automatically recreated', () async {
    final preview = await service.previewSourcePlaylistCopy(1); await service.createSourcePlaylistCopy(preview);
    final values = playlists(); final copy = values.removeLast();
    await Hive.box('user').put('customPlaylists', values); SpotifySourceCopyFixture.hydrate();
    final before = inventory(); await expectLater(service.previewSourcePlaylistCopy(1), throwsStateError); expect(inventory(), before);
    await Hive.box('user').put('customPlaylists', [...values, copy, {...copy, 'ytid': 'customId-marker-copy'}]); SpotifySourceCopyFixture.hydrate();
    final ambiguous = inventory(); await expectLater(service.previewSourcePlaylistCopy(1), throwsStateError); expect(inventory(), ambiguous);
  });
  test('pending edited destination refuses audit; ordinary routing cannot bury its proof', () async {
    var calls = 0;
    final writer = SpotifyImportDestinationService(metadataWriter: (box, values) async {
      calls++; if (calls == 2) throw StateError('Injected final audit failure'); await box.put('spotifyImportMetadata', values);
    });
    await writer.createSourcePlaylistCopy(await writer.previewSourcePlaylistCopy(1));
    final values = playlists(); values.last['list'] = [{'ytid': 'manual-owner'}];
    await Hive.box('user').put('customPlaylists', values); SpotifySourceCopyFixture.hydrate();
    final before = inventory(); await expectLater(service.previewSourcePlaylistCopy(1), throwsStateError);
    await expectLater(service.route(snapshot: await service.loadSnapshot(), requestedCount: 2,
      destinationKind: SpotifyImportDestinationKind.likedSongs), throwsStateError);
    expect(inventory(), before);
  });
  test('absent root collection remains absent after owned destination compensation', () async {
    await Hive.box('user').delete('customPlaylists'); SpotifySourceCopyFixture.hydrate();
    final writer = SpotifyImportDestinationService(destinationWriter: (box, key, values) async { await box.put(key, values); throw StateError('Injected after-write fault'); });
    await expectLater(writer.createSourcePlaylistCopy(await writer.previewSourcePlaylistCopy(1)), throwsStateError);
    expect(Hive.box('user').containsKey('customPlaylists'), isFalse);
    expect(metadata()[importRoutingPendingKey], isA<Map>()); await reopen(); expect(Hive.box('user').containsKey('customPlaylists'), isFalse);
  });
  test('completed actual writer output survives saved-file independent restore and restart with no second creation', () async {
    await service.createSourcePlaylistCopy(await service.previewSourcePlaylistCopy(1)); final before = inventory();
    await Hive.box('user').flush(); await Hive.box('settings').flush();
    final bytes = await MusifyBackupService.createBundleBytesForTesting({'user': await File('${root.path}/user.hive').readAsBytes(), 'settings': await File('${root.path}/settings.hive').readAsBytes()});
    final saved = File('${root.path}/synthetic-created-copy.musifybackup'); await saved.writeAsBytes(bytes, flush: true);
    final inspected = await MusifyBackupService.inspectBundleFileForTesting(saved);
    final independent = await Directory('${root.path}/independent').create(); await reopen(independent.path);
    expect((await MusifyBackupService.restoreValidatedBackup(inspected)).success, isTrue);
    await reopen(independent.path); expect(inventory(), before);
    expect((await service.createSourcePlaylistCopy(await service.previewSourcePlaylistCopy(1))).created, isFalse); expect(inventory(), before);
  });
}
