import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

void main() {
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

    test('does not put a user-rejected result back in the queue', () {
      expect(
        SpotifyReviewWorkflowService.isPendingResolution({
          'status': 'manual_unmatched',
        }),
        isFalse,
      );
    });
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
