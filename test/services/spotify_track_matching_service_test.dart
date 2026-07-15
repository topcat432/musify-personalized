import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_track_matching_service.dart';

void main() {
  late Directory hiveRoot;

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp(
      'track-matching-test-',
    );
    Hive.init(hiveRoot.path);
    await Hive.openBox('user');
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) await hiveRoot.delete(recursive: true);
  });

  test('restart preserves permanently excluded imported rows', () async {
    final box = Hive.box('user');
    await box.put('spotifyImportTracks', [
      {
        'sourceRow': 7,
        'title': 'Voice-over intro',
        'artist': 'Quincy Jones',
        'album': 'Off The Wall',
      },
    ]);
    await box.put('spotifyExcludedImportRows', ['7']);
    await box.put('spotifyImportMetadata', <String, dynamic>{});
    await box.put('spotifyMatchResults', [
      {
        'sourceRow': 7,
        'sourceTitle': 'Voice-over intro',
        'status': 'excluded',
      },
    ]);

    const service = SpotifyTrackMatchingService();
    final restarted = await service.restartMatching();
    expect(box.get('spotifyMatchResults'), isEmpty);
    expect(
      (box.get('spotifyImportMetadata') as Map)['nextTrackIndex'],
      0,
    );
    final completed = await service.matchNextBatch(batchSize: 1);
    final results = box.get('spotifyMatchResults') as List;
    final saved = Map<String, dynamic>.from(results.single as Map);
    final metadata = Map<String, dynamic>.from(
      box.get('spotifyImportMetadata') as Map,
    );

    expect(restarted.nextTrackIndex, 0);
    expect(completed.nextTrackIndex, 1);
    expect(completed.pendingResolutionCount, 0);
    expect(completed.unmatchedCount, 0);
    expect(completed.excludedCount, 1);
    expect(saved['status'], 'excluded');
    expect(saved['reviewDecision'], 'excluded_from_import');
    expect(metadata['excludedCount'], 1);
  });

  test('excluded pilot rows do not lower the full-library success rate', () {
    const snapshot = SpotifyMatchingSnapshot(
      totalTracks: 100,
      nextTrackIndex: 50,
      matchedCount: 44,
      reviewCount: 0,
      unmatchedCount: 0,
      errorCount: 0,
      excludedCount: 6,
      pendingResolutionCount: 0,
      status: 'paused',
      recentResults: [],
    );

    expect(
      SpotifyTrackMatchingService.isFullLibraryRunUnlocked(snapshot),
      isTrue,
    );
  });

  test('a pilot with too few usable attempts cannot unlock the full run', () {
    const snapshot = SpotifyMatchingSnapshot(
      totalTracks: 100,
      nextTrackIndex: 50,
      matchedCount: 1,
      reviewCount: 0,
      unmatchedCount: 0,
      errorCount: 24,
      excludedCount: 25,
      pendingResolutionCount: 0,
      status: 'paused',
      recentResults: [],
    );

    expect(
      SpotifyTrackMatchingService.isFullLibraryRunUnlocked(snapshot),
      isFalse,
    );
  });

  test('a stop requested after lookup prevents a stale checkpoint', () async {
    final box = Hive.box('user');
    await box.put('spotifyImportTracks', [
      {
        'sourceRow': 7,
        'title': 'Voice-over intro',
        'artist': 'Quincy Jones',
        'album': 'Off The Wall',
      },
    ]);
    await box.put('spotifyExcludedImportRows', ['7']);
    await box.put('spotifyImportMetadata', <String, dynamic>{
      'matchingStatus': 'not_started',
      'nextTrackIndex': 0,
    });
    await box.put('spotifyMatchResults', <dynamic>[]);
    var stopChecks = 0;

    final snapshot = await const SpotifyTrackMatchingService().matchNextBatch(
      batchSize: 1,
      shouldCancel: () => ++stopChecks > 1,
    );

    expect(stopChecks, 2);
    expect(snapshot.nextTrackIndex, 0);
    expect(box.get('spotifyMatchResults'), isEmpty);
    final metadata = Map<String, dynamic>.from(
      box.get('spotifyImportMetadata') as Map,
    );
    expect(metadata['nextTrackIndex'], 0);
  });

  test('a user pause after lookup checkpoints the completed track', () async {
    final box = Hive.box('user');
    await box.put('spotifyImportTracks', [
      {
        'sourceRow': 7,
        'title': 'Voice-over intro',
        'artist': 'Quincy Jones',
        'album': 'Off The Wall',
      },
    ]);
    await box.put('spotifyExcludedImportRows', ['7']);
    await box.put('spotifyImportMetadata', <String, dynamic>{
      'matchingStatus': 'not_started',
      'nextTrackIndex': 0,
    });
    await box.put('spotifyMatchResults', <dynamic>[]);
    var pauseChecks = 0;

    final snapshot = await const SpotifyTrackMatchingService().matchNextBatch(
      batchSize: 1,
      shouldPause: () => ++pauseChecks > 1,
    );

    expect(snapshot.nextTrackIndex, 1);
    expect(snapshot.excludedCount, 1);
    final saved = box.get('spotifyMatchResults') as List;
    expect(saved, hasLength(1));
    expect((saved.single as Map)['status'], 'excluded');
    final metadata = Map<String, dynamic>.from(
      box.get('spotifyImportMetadata') as Map,
    );
    expect(metadata['nextTrackIndex'], 1);
    expect(metadata['matchingStatus'], 'complete');
  });
}
