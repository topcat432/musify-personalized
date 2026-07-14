import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_manual_source_service.dart';

void main() {
  group('SpotifyManualSourceService exact video parsing', () {
    test('parses ordinary YouTube links', () {
      expect(
        SpotifyManualSourceService.parseExactVideoId(
          'https://www.youtube.com/watch?v=yIVRs6YSbOM',
        ),
        'yIVRs6YSbOM',
      );
      expect(
        SpotifyManualSourceService.parseExactVideoId(
          'https://youtu.be/yIVRs6YSbOM?si=example',
        ),
        'yIVRs6YSbOM',
      );
    });

    test('parses YouTube Music links without keeping playlist parameters', () {
      expect(
        SpotifyManualSourceService.parseExactVideoId(
          'https://music.youtube.com/watch?v=yIVRs6YSbOM&list=OLAK5uy_test',
        ),
        'yIVRs6YSbOM',
      );
    });

    test('accepts a raw video id and rejects search text', () {
      expect(
        SpotifyManualSourceService.parseExactVideoId('yIVRs6YSbOM'),
        'yIVRs6YSbOM',
      );
      expect(
        SpotifyManualSourceService.parseExactVideoId('artist song title'),
        isNull,
      );
    });
  });
}
