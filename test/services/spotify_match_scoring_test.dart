import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_match_scoring.dart';

void main() {
  group('SpotifyMatchScorer', () {
    test('gives a strong score to an exact Topic-channel recording', () {
      const input = SpotifyMatchInput(
        title: 'Billie Jean',
        artist: 'Michael Jackson',
        durationMs: 294000,
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Billie Jean',
        'artist': 'Michael Jackson',
        'videoAuthor': 'Michael Jackson - Topic',
        'duration': 294,
      });

      expect(result.disqualified, isFalse);
      expect(result.score, greaterThanOrEqualTo(0.90));
      expect(result.reasons, contains('Official or Topic source'));
    });

    test('rejects a long compilation offered as one song', () {
      const input = SpotifyMatchInput(
        title: 'Billie Jean',
        artist: 'Michael Jackson',
        durationMs: 294000,
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Michael Jackson Best Of Greatest Hits Full Album',
        'artist': 'Michael Jackson',
        'videoAuthor': 'Random Uploads',
        'duration': 7200,
      });

      expect(result.disqualified, isTrue);
      expect(result.score, 0);
    });

    test('penalizes an unrequested live version', () {
      const input = SpotifyMatchInput(
        title: 'Nights',
        artist: 'Frank Ocean',
      );
      final studio = SpotifyMatchScorer.score(input, {
        'title': 'Nights',
        'artist': 'Frank Ocean',
        'videoAuthor': 'Frank Ocean - Topic',
        'duration': 307,
      });
      final live = SpotifyMatchScorer.score(input, {
        'title': 'Nights Live',
        'artist': 'Frank Ocean',
        'videoAuthor': 'Concert Archive',
        'duration': 325,
      });

      expect(studio.score, greaterThan(live.score));
      expect(live.reasons, contains('Alternate version not requested'));
    });

    test('rejects a candidate with an unrelated artist identity', () {
      const input = SpotifyMatchInput(
        title: 'Place',
        artist: 'Playboi Carti',
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Place',
        'artist': 'Completely Different Artist',
        'videoAuthor': 'Random Channel',
        'duration': 180,
      });

      expect(result.disqualified, isTrue);
    });
  });
}
