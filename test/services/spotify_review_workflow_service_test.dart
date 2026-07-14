import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

void main() {
  late Directory hiveRoot;

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('review-workflow-test-');
    Hive.init(hiveRoot.path);
    await Hive.openBox('user');
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) await hiveRoot.delete(recursive: true);
  });

  group('SpotifyReviewWorkflowService pending decisions', () {
    test('keeps machine-unmatched and review results pending', () {
      expect(
        SpotifyReviewWorkflowService.isPendingResolution({
          'status': 'needs_review',
        }),
        isTrue,
      );
      expect(
        SpotifyReviewWorkflowService.isPendingResolution({
          'status': 'unmatched',
        }),
        isTrue,
      );
    });

    test('keeps a user-marked unmatched result reopenable', () {
      expect(
        SpotifyReviewWorkflowService.isPendingResolution({
          'status': 'manual_unmatched',
        }),
        isTrue,
      );
    });

    test('keeps a permanently excluded result out of every review queue', () {
      expect(
        SpotifyReviewWorkflowService.isPendingResolution({
          'status': 'excluded',
        }),
        isFalse,
      );
      expect(
        SpotifyReviewWorkflowService.isExcluded({'status': 'excluded'}),
        isTrue,
      );
    });
  });

  test('permanent exclusion is audited and leaves pending resolution', () async {
    final box = Hive.box('user');
    await box.put('spotifyMatchResults', [
      {
        'sourceRow': 7,
        'sourceTitle': 'Voice-over intro',
        'status': 'manual_unmatched',
      },
    ]);
    await box.put('spotifyImportMetadata', <String, dynamic>{});

    final result = await const SpotifyReviewWorkflowService().excludeItem(
      item: {'sourceRow': 7},
    );
    final saved = Map<String, dynamic>.from(
      (box.get('spotifyMatchResults') as List).single as Map,
    );
    final metadata = Map<String, dynamic>.from(
      box.get('spotifyImportMetadata') as Map,
    );

    expect(result.remainingUnresolved, 0);
    expect(saved['status'], 'excluded');
    expect(saved['reviewDecision'], 'excluded_from_import');
    expect(saved['excludedAt'], isNotNull);
    expect(metadata['excludedCount'], 1);
    expect(metadata['pendingResolutionCount'], 0);
  });

  test('cancellation after rescue work prevents a stale checkpoint', () async {
    final box = Hive.box('user');
    final original = <String, dynamic>{
      'sourceRow': 7,
      'status': 'needs_review',
      'sourceTitle': 'Example Song',
      'sourceArtist': 'Example Artist',
      'sourceAlbum': 'Example Album',
      'sourceDurationMs': 180000,
      'alternatives': [
        {
          'score': 0.84,
          'candidate': {
            'ytid': 'abc123',
            'title': 'Example Song',
            'artist': 'Example Artist',
            'album': 'Example Album',
            'duration': 180,
            'sourceType': 'youtube_music_song',
          },
          'evidence': {
            'titleScore': 1.0,
            'primaryArtistScore': 1.0,
            'albumScore': 1.0,
            'durationScore': 1.0,
            'sourceScore': 1.0,
            'reasons': [
              'Exact title match',
              'Primary artist matches',
              'Album matches',
              'Duration closely matches',
            ],
          },
        },
      ],
    };
    await box.put('spotifyMatchResults', [original]);
    await box.put('spotifyImportMetadata', <String, dynamic>{
      'importSessionId': 'current-session',
    });
    var stopChecks = 0;

    final progress = await const SpotifyReviewWorkflowService().runRescuePass(
      shouldStop: () => ++stopChecks > 1,
    );

    expect(stopChecks, 2);
    expect(progress.processed, 0);
    expect(progress.finished, isFalse);
    final saved = Map<String, dynamic>.from(
      (box.get('spotifyMatchResults') as List).single as Map,
    );
    expect(saved['status'], 'needs_review');
    expect(saved['reviewDecision'], isNull);
  });

  group('SpotifyReviewWorkflowService cluster safety', () {
    Map<String, dynamic> safeItem() => {
      'status': 'needs_review',
      'sourceTitle': 'Example Song',
      'sourceArtist': 'Example Artist',
      'sourceAlbum': 'Example Album',
      'sourceDurationMs': 180000,
      'alternatives': [
        {
          'score': 0.84,
          'candidate': {
            'ytid': 'abc123',
            'title': 'Example Song',
            'artist': 'Example Artist',
            'album': 'Example Album',
            'duration': 180,
            'sourceType': 'youtube_music_song',
          },
          'evidence': {
            'titleScore': 1.0,
            'primaryArtistScore': 1.0,
            'albumScore': 1.0,
            'durationScore': 1.0,
            'sourceScore': 1.0,
            'reasons': [
              'Exact title match',
              'Primary artist matches',
              'Album matches',
              'Duration closely matches',
            ],
          },
        },
      ],
    };

    test('allows a strict structured-song evidence pattern', () {
      final item = safeItem();
      expect(SpotifyReviewWorkflowService.isSafeClusterItem(item), isTrue);
      expect(
        SpotifyReviewWorkflowService.clusterLabel(item),
        contains('YouTube Music song'),
      );
    });

    test('blocks an alternate-version evidence pattern', () {
      final item = safeItem();
      final alternative = item['alternatives'][0] as Map<String, dynamic>;
      final evidence = alternative['evidence'] as Map<String, dynamic>;
      evidence['reasons'] = [
        'Exact title match',
        'Primary artist matches',
        'Alternate version not requested',
      ];

      expect(SpotifyReviewWorkflowService.isSafeClusterItem(item), isFalse);
      expect(
        SpotifyReviewWorkflowService.clusterKey(item),
        contains('version-risk'),
      );
    });

    test('blocks weak artist identity even with an exact title', () {
      final item = safeItem();
      final alternative = item['alternatives'][0] as Map<String, dynamic>;
      final evidence = alternative['evidence'] as Map<String, dynamic>;
      evidence['primaryArtistScore'] = 0.72;

      expect(SpotifyReviewWorkflowService.isSafeClusterItem(item), isFalse);
    });

    test('places equivalent evidence in the same cluster', () {
      final first = safeItem();
      final second = safeItem()
        ..['sourceTitle'] = 'Another Song'
        ..['sourceDurationMs'] = 240000;
      final secondAlternative =
          (second['alternatives'] as List).first as Map<String, dynamic>;
      final secondCandidate =
          secondAlternative['candidate'] as Map<String, dynamic>;
      secondCandidate
        ..['ytid'] = 'xyz789'
        ..['title'] = 'Another Song'
        ..['duration'] = 240;

      expect(
        SpotifyReviewWorkflowService.clusterKey(first),
        SpotifyReviewWorkflowService.clusterKey(second),
      );
    });
  });
}
