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
    expect(saved['status'], 'excluded');
    expect(saved['reviewDecision'], 'excluded_from_import');
    expect(metadata['excludedCount'], 1);
  });
}
