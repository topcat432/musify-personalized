import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

Map<String, dynamic> _row(int id, {bool safe = false}) => {
  'sourceRow': id, 'sourceTitle': 'Owned song $id',
  'sourceArtist': 'Owned artist', 'status': 'needs_review',
  'alternatives': [{
    'candidate': {'ytid': 'owned-$id', 'title': 'Owned song $id',
      'artist': 'Owned artist', 'videoAuthor': 'Owned artist - Topic',
      'sourceType': 'youtube_music_song'},
    'score': safe ? 0.99 : 0.4,
    'evidence': {'titleScore': 1.0, 'primaryArtistScore': 1.0,
      'reasons': <String>[]},
  }],
};

void main() {
  late Directory root;
  late Box<dynamic> box;
  const service = SpotifyReviewWorkflowService();
  Future<void> reopen() async {
    await Hive.close();
    Hive.init(root.path);
    box = await Hive.openBox('user');
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('owned-rescue-checkpoint-');
    Hive.init(root.path);
    box = await Hive.openBox('user');
    await box.putAll({
      'spotifyMatchResults': [{..._row(7), 'status': 'excluded'}, _row(8)],
      'spotifyExcludedImportRows': ['7'],
      'spotifyImportMetadata': {'importSessionId': 'owned-rescue',
        'ownerBytes': Uint8List.fromList([1, 2]),
        'ownerTime': DateTime.utc(2026, 1, 1)},
      'likedSongs': [{'ytid': 'owned-existing-like'}],
    });
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  Future<SpotifyResolutionResult> saveManual(Map<String, dynamic> item) =>
      service.resolveManualItem(item: item, query: 'Owned newer query',
        isDirectUrl: false, selectedAlternative: {
          'candidate': {'ytid': 'owned-newer-manual', 'title': 'Chosen recording',
            'artist': 'Owned artist', 'version': 'owned alternate'},
          'score': 0.3, 'evidence': {'owned': true},
        });

  void expectManualRetained() {
    final rows = box.get('spotifyMatchResults') as List;
    final saved = rows.last as Map;
    expect((saved['bestCandidate'] as Map?)?['ytid'], 'owned-newer-manual');
    expect(saved['status'], 'manually_matched');
    expect(saved['manualSearchQuery'], 'Owned newer query');
    expect(rows.first['sourceRow'], 7);
    expect(rows.first['status'], 'excluded');
    expect(box.get('spotifyExcludedImportRows'), ['7']);
    final metadata = box.get('spotifyImportMetadata') as Map;
    expect(metadata['ownerBytes'], isA<Uint8List>());
    expect(metadata['ownerBytes'], [1, 2]);
    expect((metadata['ownerTime'] as DateTime).isUtc, isTrue);
    expect(metadata['matchedCount'], 1);
    expect(metadata['excludedCount'], 1);
    expect(metadata['pendingResolutionCount'], 0);
    expect(box.get('likedSongs'), [{'ytid': 'owned-existing-like'}]);
  }

  test('rescue cannot overwrite a newer real manual decision beside excluded row', () async {
    final queued = (await service.loadUnresolvedItems()).single;
    Future<SpotifyResolutionResult>? manual;
    final rescue = await service.runRescuePass(onProgress: (progress) {
      if (progress.processed == 1 && manual == null) manual = saveManual(queued);
    });
    expect(manual, isNotNull);
    await manual;
    expectManualRetained();
    expect(rescue.finished, isFalse);
    await reopen();
    expectManualRetained();
  });

  test('rescue cannot overwrite a newer real No-match decision', () async {
    final queued = (await service.loadUnresolvedItems()).single;
    Future<SpotifyResolutionResult>? decision;
    final rescue = await service.runRescuePass(onProgress: (progress) {
      if (progress.processed == 1 && decision == null) {
        decision = service.resolveItem(item: queued, accept: false);
      }
    });
    await decision;
    expect(rescue.finished, isFalse);
    expect((box.get('spotifyMatchResults') as List).last['status'], 'manual_unmatched');
    await reopen();
    expect((box.get('spotifyMatchResults') as List).last['status'], 'manual_unmatched');
    expect(box.get('spotifyExcludedImportRows'), ['7']);
  });

  test('rescue preserves a newer typed metadata owner even if rows are unchanged', () async {
    Future<void>? owner;
    final rescue = await service.runRescuePass(onProgress: (progress) {
      if (progress.processed == 1 && owner == null) {
        owner = box.put('spotifyImportMetadata', {
          ...Map<String, dynamic>.from(box.get('spotifyImportMetadata') as Map),
          'ownerBytes': Uint8List.fromList([9, 8]),
          'ownerTime': DateTime.utc(2026, 1, 1).toLocal(),
          'ownerMarker': 'retain-newer',
        });
      }
    });
    await owner;
    expect(rescue.finished, isFalse);
    await reopen();
    final metadata = box.get('spotifyImportMetadata') as Map;
    expect(metadata['ownerBytes'], isA<Uint8List>());
    expect(metadata['ownerBytes'], [9, 8]);
    expect((metadata['ownerTime'] as DateTime).isUtc, isFalse);
    expect(metadata['ownerMarker'], 'retain-newer');
  });

  test('rescue detects shared nested metadata mutation against its deep snapshot', () async {
    final metadata = Map<String, dynamic>.from(box.get('spotifyImportMetadata') as Map);
    metadata['nestedOwner'] = {'bytes': Uint8List.fromList([1, 2])};
    await box.put('spotifyImportMetadata', metadata);
    Future<void>? owner;
    final rescue = await service.runRescuePass(onProgress: (progress) {
      if (progress.processed == 1 && owner == null) {
        final current = box.get('spotifyImportMetadata') as Map;
        (current['nestedOwner']['bytes'] as Uint8List)[0] = 9;
        owner = box.put('spotifyImportMetadata', current);
      }
    });
    await owner;
    expect(rescue.finished, isFalse);
    await reopen();
    expect((box.get('spotifyImportMetadata') as Map)['nestedOwner']['bytes'], [9, 2]);
  });

  test('rescue advances its own baseline through multiple successful checkpoints', () async {
    await box.put('spotifyMatchResults', [
      {..._row(7), 'status': 'excluded'},
      for (var row = 8; row <= 13; row++) _row(row, safe: true),
    ]);
    final rescue = await service.runRescuePass();
    expect(rescue.finished, isTrue);
    expect(rescue.processed, 6);
    await reopen();
    final rows = box.get('spotifyMatchResults') as List;
    expect(rows.skip(1).every((row) => row['status'] == 'matched'), isTrue);
    expect((box.get('spotifyImportMetadata') as Map)['matchedCount'], 6);
    expect(box.get('spotifyExcludedImportRows'), ['7']);
  });

  test('new manual owner after an intermediate checkpoint defeats the final write', () async {
    await box.put('spotifyMatchResults', [
      {..._row(7), 'status': 'excluded'},
      for (var row = 8; row <= 13; row++) _row(row),
    ]);
    final queued = (await service.loadUnresolvedItems()).last;
    Future<SpotifyResolutionResult>? manual;
    final rescue = await service.runRescuePass(onProgress: (progress) {
      if (progress.processed == 5 && manual == null) manual = saveManual(queued);
    });
    await manual;
    expect(rescue.finished, isFalse);
    expect((box.get('spotifyMatchResults') as List).last['bestCandidate']['ytid'], 'owned-newer-manual');
    await reopen();
    expect((box.get('spotifyMatchResults') as List).last['bestCandidate']['ytid'], 'owned-newer-manual');
  });

  test('paused rescue can restart from its durable checkpoint with a fresh owner', () async {
    await box.put('spotifyMatchResults', [_row(8, safe: true), _row(9, safe: true)]);
    var pause = false;
    final first = await service.runRescuePass(shouldPause: () => pause,
      onProgress: (progress) { if (progress.processed == 1) pause = true; });
    expect(first.finished, isFalse);
    expect(first.processed, 1);
    await reopen();
    final second = await service.runRescuePass();
    expect(second.finished, isTrue);
    expect(second.processed, 1);
    await reopen();
    expect((box.get('spotifyMatchResults') as List).every((row) => row['status'] == 'matched'), isTrue);
  });
}
