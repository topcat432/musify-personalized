import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

Map<String, dynamic> ownedAlternative({bool safe = true}) => {
  'score': safe ? 0.99 : 0.4,
  'candidate': {'ytid': 'owned-source', 'title': 'Owned song',
    'artist': 'Owned artist', 'videoAuthor': 'Owned artist - Topic',
    'sourceType': 'youtube_music_song', 'album': 'Owned album', 'duration': 180},
  'evidence': {'titleScore': 1.0, 'primaryArtistScore': 1.0,
    'albumScore': 1.0, 'durationScore': 1.0, 'reasons': <String>[]},
};

Map<String, dynamic> ownedRow(int row, {bool safe = true}) => {
  'sourceRow': row, 'sourceTitle': 'Owned song', 'sourceArtist': 'Owned artist',
  'sourceAlbum': 'Owned album', 'sourceDurationMs': 180000,
  'sourceIsrc': 'USOWN2600001', 'status': 'needs_review',
  'alternatives': [ownedAlternative(safe: safe)],
  'legacy': {'bytes': Uint8List.fromList([1, 2]), 'at': DateTime.utc(2026, 1, 1)},
};

void main() {
  late Directory root;
  const service = SpotifyReviewWorkflowService();
  setUp(() async {
    root = await Directory.systemTemp.createTemp('owned-stale-exclusion-');
    Hive.init(root.path);
    final box = await Hive.openBox('user');
    await box.put('spotifyMatchResults', [ownedRow(7)]);
    await box.put('spotifyImportMetadata', <String, dynamic>{});
    await box.put('unrelatedOwnedFixture', {'keep': true});
  });
  tearDown(() async { await Hive.close(); await root.delete(recursive: true); });
  Future<void> reopen() async { await Hive.close(); Hive.init(root.path); await Hive.openBox('user'); }

  for (final accept in [false, true]) {
    test('stale review cannot reactivate excluded row: accept=$accept', () async {
      final box = Hive.box('user');
      final stale = (await service.loadUnresolvedItems()).single;
      await service.excludeItem(item: stale);
      await box.flush();
      final before = await File('${root.path}/user.hive').readAsBytes();
      await expectLater(service.resolveItem(item: stale, accept: accept,
          selectedAlternative: ownedAlternative()), throwsA(isA<StateError>()));
      expect((box.get('spotifyMatchResults') as List).single['status'], 'excluded');
      expect(box.get('spotifyExcludedImportRows'), ['7']);
      expect((box.get('spotifyImportMetadata') as Map)['excludedCount'], 1);
      await box.flush();
      expect(await File('${root.path}/user.hive').readAsBytes(), before);
      await reopen();
      expect((Hive.box('user').get('spotifyMatchResults') as List).single['status'], 'excluded');
      expect(Hive.box('user').get('spotifyExcludedImportRows'), ['7']);
      expect(Hive.box('user').get('unrelatedOwnedFixture'), {'keep': true});
    });
    test('history-only permanent exclusion refuses explicit decision: accept=$accept', () async {
      final box = Hive.box('user');
      final stale = (await service.loadUnresolvedItems()).single;
      await box.put('spotifyExcludedImportRows', [7]);
      await box.flush();
      final before = await File('${root.path}/user.hive').readAsBytes();
      await expectLater(service.resolveItem(item: stale, accept: accept,
          selectedAlternative: ownedAlternative()), throwsA(isA<StateError>()));
      await box.flush();
      expect(await File('${root.path}/user.hive').readAsBytes(), before);
      await reopen();
      expect((Hive.box('user').get('spotifyMatchResults') as List).single['status'], 'needs_review');
      expect(Hive.box('user').get('spotifyExcludedImportRows'), [7]);
    });
  }
  for (final history in [<String, dynamic>{'unknown': true}, [<String, dynamic>{'unknown': true}]]) {
    test('unreadable exclusion history refuses without a write: $history', () async {
      final box = Hive.box('user');
      final stale = (await service.loadUnresolvedItems()).single;
      await box.put('spotifyExcludedImportRows', history);
      await box.flush();
      final before = await File('${root.path}/user.hive').readAsBytes();
      await expectLater(service.resolveItem(item: stale, accept: true,
          selectedAlternative: ownedAlternative()), throwsA(isA<StateError>()));
      await box.flush();
      expect(await File('${root.path}/user.hive').readAsBytes(), before);
      expect(box.get('spotifyExcludedImportRows'), history);
    });
  }
  test('authoritative exclusion is absent from pending queue and clusters', () async {
    final box = Hive.box('user');
    await box.put('spotifyMatchResults', [ownedRow(7), ownedRow(8)]);
    await box.put('spotifyExcludedImportRows', ['7']);
    expect((await service.loadUnresolvedItems()).map((r) => r['sourceRow']), [8]);
    expect((await service.loadClusters()).single.count, 1);
    expect((box.get('spotifyMatchResults') as List).first['status'], 'needs_review');
  });
  test('bulk approval preserves history-only excluded row and counts it separately', () async {
    final box = Hive.box('user');
    await box.put('spotifyMatchResults', [ownedRow(7), ownedRow(8)]);
    await box.put('spotifyImportMetadata', {'importSessionId': 'owned-session'});
    await box.put('spotifyExcludedImportRows', ['7']);
    final key = SpotifyReviewWorkflowService.clusterKey(ownedRow(8));
    expect(await service.bulkApproveCluster(key: key, importSessionId: 'owned-session'), 1);
    final rows = box.get('spotifyMatchResults') as List;
    expect(rows.first['status'], 'needs_review');
    expect(rows.last['status'], 'matched');
    final metadata = box.get('spotifyImportMetadata') as Map;
    expect(metadata['excludedCount'], 1);
    expect(metadata['matchedCount'], 1);
    expect(metadata['pendingResolutionCount'], 0);
  });
  test('exact ISRC propagation cannot overwrite an excluded partial row', () async {
    final box = Hive.box('user');
    await box.put('spotifyMatchResults', [ownedRow(7), ownedRow(8)]);
    await box.put('spotifyExcludedImportRows', ['7']);
    final selected = (await service.loadUnresolvedItems()).single;
    final result = await service.resolveItem(item: selected, accept: true,
        selectedAlternative: ownedAlternative());
    expect(result.duplicatesApplied, 0);
    expect(result.remainingUnresolved, 0);
    expect((box.get('spotifyMatchResults') as List).first['status'], 'needs_review');
    await reopen();
    expect(Hive.box('user').get('spotifyExcludedImportRows'), ['7']);
    expect((Hive.box('user').get('spotifyMatchResults') as List).first['legacy']['bytes'], isA<Uint8List>());
  });
  test('rescue excludes authoritative partial rows before local promotion', () async {
    final box = Hive.box('user');
    await box.put('spotifyExcludedImportRows', ['7']);
    final result = await service.runRescuePass();
    expect(result.processed, 0);
    expect(result.total, 0);
    expect((box.get('spotifyMatchResults') as List).single['status'], 'needs_review');
    expect((box.get('spotifyImportMetadata') as Map)['excludedCount'], 1);
  });
  test('exclusion during rescue progress defeats the stale final checkpoint', () async {
    final box = Hive.box('user');
    await box.put('spotifyMatchResults', [ownedRow(7, safe: false)]);
    final stale = (await service.loadUnresolvedItems()).single;
    Future<SpotifyResolutionResult>? exclusion;
    final result = await service.runRescuePass(onProgress: (progress) {
      if (progress.processed == 1 && exclusion == null) {
        exclusion = service.excludeItem(item: stale);
      }
    });
    await exclusion;
    expect(result.finished, isFalse);
    expect((box.get('spotifyMatchResults') as List).single['status'], 'excluded');
    expect(box.get('spotifyExcludedImportRows'), ['7']);
    expect((box.get('spotifyImportMetadata') as Map)['excludedCount'], 1);
    await reopen();
    expect((Hive.box('user').get('spotifyMatchResults') as List).single['status'], 'excluded');
  });
  test('repeat explicit exclusion remains usable without duplicate history', () async {
    final box = Hive.box('user');
    final stale = (await service.loadUnresolvedItems()).single;
    await service.excludeItem(item: stale);
    await service.excludeItem(item: stale);
    expect(box.get('spotifyExcludedImportRows'), ['7']);
    expect(await service.loadUnresolvedItems(), isEmpty);
  });
  test('new excluded row added during rescue cannot disappear at checkpoint', () async {
    final box = Hive.box('user');
    await box.put('spotifyMatchResults', [ownedRow(7, safe: false)]);
    Future<void>? ownerWrite;
    final result = await service.runRescuePass(onProgress: (progress) {
      if (progress.processed == 1 && ownerWrite == null) {
        ownerWrite = box.putAll({
          'spotifyMatchResults': [ownedRow(7, safe: false), {...ownedRow(9), 'status': 'excluded', 'reviewDecision': 'excluded_from_import'}],
          'spotifyExcludedImportRows': ['9'],
          'spotifyImportMetadata': {'excludedCount': 1, 'ownedMarker': 'retain'},
        });
      }
    });
    await ownerWrite;
    expect(result.finished, isFalse);
    expect((box.get('spotifyMatchResults') as List).map((row) => row['sourceRow']), [7, 9]);
    expect((box.get('spotifyImportMetadata') as Map)['ownedMarker'], 'retain');
    await reopen();
    expect((Hive.box('user').get('spotifyMatchResults') as List).last['status'], 'excluded');
  });
  test('ambiguous source rows refuse decision and exclusion without writes', () async {
    final box = Hive.box('user');
    final stale = (await service.loadUnresolvedItems()).single;
    await box.put('spotifyMatchResults', [ownedRow(7), {...ownedRow(7), 'sourceTitle': 'Other recording'}]);
    await box.flush();
    final before = await File('${root.path}/user.hive').readAsBytes();
    await expectLater(service.resolveItem(item: stale, accept: false), throwsA(isA<StateError>()));
    await expectLater(service.excludeItem(item: stale), throwsA(isA<StateError>()));
    await box.flush();
    expect(await File('${root.path}/user.hive').readAsBytes(), before);
  });

  test('rescue preserves a newer excluded-row timezone value with equal instant', () async {
    final box = Hive.box('user');
    final protected = {...ownedRow(7), 'status': 'excluded', 'ownerTime': DateTime.utc(2026, 1, 1)};
    final pending = ownedRow(8, safe: false);
    await box.put('spotifyMatchResults', [protected, pending]);
    await box.put('spotifyExcludedImportRows', ['7']);
    Future<void>? ownerWrite;
    final result = await service.runRescuePass(onProgress: (progress) {
      if (progress.processed == 1 && ownerWrite == null) {
        ownerWrite = box.put('spotifyMatchResults', [
          {...protected, 'ownerTime': DateTime.utc(2026, 1, 1).toLocal()}, pending,
        ]);
      }
    });
    await ownerWrite;
    expect(result.finished, isFalse);
    expect(((box.get('spotifyMatchResults') as List).first['ownerTime'] as DateTime).isUtc, isFalse);
    await reopen();
    expect(((Hive.box('user').get('spotifyMatchResults') as List).first['ownerTime'] as DateTime).isUtc, isFalse);
  });

}
