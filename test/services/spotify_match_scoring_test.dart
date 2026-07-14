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
      expect(result.automaticEligible, isTrue);
      expect(result.score, greaterThanOrEqualTo(0.90));
      expect(result.reasons, contains('Official or Topic source'));
    });

    test('accepts a structured YouTube Music song result', () {
      const input = SpotifyMatchInput(
        title: 'Lucy in the Sky with Diamonds',
        artist: 'The Beatles',
        album: "Sgt. Pepper's Lonely Hearts Club Band",
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Lucy In The Sky With Diamonds',
        'artist': 'The Beatles',
        'artists': ['The Beatles'],
        'album': "Sgt. Pepper's Lonely Hearts Club Band",
        'sourceType': 'youtube_music_song',
      });

      expect(result.disqualified, isFalse);
      expect(result.automaticEligible, isTrue);
      expect(result.score, greaterThanOrEqualTo(0.90));
      expect(result.reasons, contains('YouTube Music song result'));
      expect(result.reasons, contains('Album matches'));
    });

    test('does not reject collaborations when the primary artist matches', () {
      const input = SpotifyMatchInput(
        title: 'Like That',
        artist: 'Future, Metro Boomin, Kendrick Lamar',
        album: "WE DON'T TRUST YOU",
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Like That',
        'artist': 'Future',
        'artists': ['Future'],
        'album': "WE DON'T TRUST YOU",
        'sourceType': 'youtube_music_song',
      });

      expect(result.disqualified, isFalse);
      expect(result.primaryArtistScore, greaterThanOrEqualTo(0.95));
      expect(result.score, greaterThanOrEqualTo(0.80));
    });

    test('ignores a featured-artist suffix when comparing song titles', () {
      const input = SpotifyMatchInput(
        title: 'Song Name (feat. Guest Artist)',
        artist: 'Main Artist, Guest Artist',
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Song Name',
        'artists': ['Main Artist', 'Guest Artist'],
        'sourceType': 'youtube_music_song',
      });

      expect(result.disqualified, isFalse);
      expect(result.titleScore, 1);
      expect(result.artistScore, greaterThanOrEqualTo(0.95));
    });

    test('uses album identity to prefer the correct release', () {
      const input = SpotifyMatchInput(
        title: 'Intro',
        artist: 'Example Artist',
        album: 'First Album',
      );
      final correct = SpotifyMatchScorer.score(input, {
        'title': 'Intro',
        'artists': ['Example Artist'],
        'album': 'First Album',
        'sourceType': 'youtube_music_song',
      });
      final wrongAlbum = SpotifyMatchScorer.score(input, {
        'title': 'Intro',
        'artists': ['Example Artist'],
        'album': 'Second Album',
        'sourceType': 'youtube_music_song',
      });

      expect(correct.score, greaterThan(wrongAlbum.score));
      expect(correct.albumScore, 1);
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
      expect(live.automaticEligible, isFalse);
      expect(live.reasons, contains('Alternate version not requested'));
    });

    test('uses a fallback raw title to retain stripped version evidence', () {
      const input = SpotifyMatchInput(
        title: 'Example Song',
        artist: 'Example Artist',
        durationMs: 180000,
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Example Song',
        'rawTitle': 'Example Song Karaoke',
        'artist': 'Example Artist',
        'videoAuthor': 'Example Artist',
        'duration': 180,
      });

      expect(result.automaticEligible, isFalse);
      expect(result.reasons, contains('Alternate version not requested'));
    });

    test('does not treat ordinary source-title words as version requests', () {
      const input = SpotifyMatchInput(
        title: 'Live Forever',
        artist: 'Oasis',
        durationMs: 276000,
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Live Forever Live',
        'rawTitle': 'Live Forever (Live)',
        'artist': 'Oasis',
        'videoAuthor': 'Oasis - Topic',
        'duration': 276,
      });

      expect(result.automaticEligible, isFalse);
      expect(result.reasons, contains('Alternate version not requested'));
    });

    test('keeps an ordinary version word eligible when both titles match', () {
      const input = SpotifyMatchInput(
        title: 'Live Forever',
        artist: 'Oasis',
        durationMs: 276000,
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Live Forever',
        'rawTitle': 'Live Forever',
        'artist': 'Oasis',
        'videoAuthor': 'Oasis - Topic',
        'duration': 276,
      });

      expect(result.automaticEligible, isTrue);
      expect(result.reasons, isNot(contains('Alternate version not requested')));
    });

    test('uses a fallback raw title to retain long-form evidence', () {
      const input = SpotifyMatchInput(
        title: 'Example Song',
        artist: 'Example Artist',
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Example Song',
        'rawTitle': 'Example Song (Official Full Album)',
        'artist': 'Example Artist',
        'videoAuthor': 'Example Artist Official',
      });

      expect(result.automaticEligible, isFalse);
      expect(result.reasons, contains('Title suggests compilation content'));
    });

    test('does not treat version-term substrings as alternate versions', () {
      const input = SpotifyMatchInput(
        title: 'Life Goes On',
        artist: 'Oliver Tree',
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Life Goes On',
        'artist': 'Oliver Tree',
        'videoAuthor': 'Oliver Tree - Topic',
        'duration': 161,
      });

      expect(result.disqualified, isFalse);
      expect(result.automaticEligible, isTrue);
      expect(result.reasons, isNot(contains('Alternate version not requested')));
    });

    test('does not treat an artist or Topic channel as version evidence', () {
      const input = SpotifyMatchInput(
        title: 'Lightning Crashes',
        artist: 'Live',
        durationMs: 325000,
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Lightning Crashes',
        'artist': 'Live',
        'videoAuthor': 'Live - Topic',
        'duration': 325,
      });

      expect(result.disqualified, isFalse);
      expect(result.automaticEligible, isTrue);
      expect(result.reasons, isNot(contains('Alternate version not requested')));
    });

    test('does not treat a normal song title as compilation content', () {
      const input = SpotifyMatchInput(
        title: 'Best of You',
        artist: 'Foo Fighters',
        durationMs: 256000,
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Best of You',
        'artist': 'Foo Fighters',
        'videoAuthor': 'Foo Fighters - Topic',
        'duration': 256,
      });

      expect(result.disqualified, isFalse);
      expect(result.automaticEligible, isTrue);
      expect(
        result.reasons,
        isNot(contains('Title suggests compilation content')),
      );
    });

    test(
      'accepts a long recording when source and candidate durations match',
      () {
        const input = SpotifyMatchInput(
          title: 'Long Classical Movement',
          artist: 'Example Orchestra',
          durationMs: 1200000,
        );
        final result = SpotifyMatchScorer.score(input, {
          'title': 'Long Classical Movement',
          'artist': 'Example Orchestra',
          'sourceType': 'youtube_music_song',
          'duration': 1200,
        });

        expect(result.disqualified, isFalse);
        expect(result.automaticEligible, isTrue);
        expect(
          result.reasons,
          isNot(contains('Rejected because duration is far too long')),
        );
      },
    );

    test('blocks an album-only mastering variant from automatic approval', () {
      const input = SpotifyMatchInput(
        title: 'Example Song',
        artist: 'Example Artist',
        album: 'Original Album',
        durationMs: 180000,
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Example Song',
        'artist': 'Example Artist',
        'album': 'Original Album Anniversary Edition',
        'duration': 180,
        'sourceType': 'youtube_music_song',
      });

      expect(result.automaticEligible, isFalse);
      expect(result.reasons, contains('Different mastering or mix version'));
    });

    test('allows a mastering variant explicitly requested by source album', () {
      const input = SpotifyMatchInput(
        title: 'Example Song',
        artist: 'Example Artist',
        album: 'Original Album Remastered',
        durationMs: 180000,
      );
      final result = SpotifyMatchScorer.score(input, {
        'title': 'Example Song',
        'artist': 'Example Artist',
        'album': 'Original Album Remastered',
        'duration': 180,
        'sourceType': 'youtube_music_song',
      });

      expect(result.automaticEligible, isTrue);
      expect(
        result.reasons,
        isNot(contains('Different mastering or mix version')),
      );
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
      expect(
        result.reasons,
        contains('Primary artist identity is too weak'),
      );
    });
  });
}
