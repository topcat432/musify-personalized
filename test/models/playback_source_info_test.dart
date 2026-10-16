import 'package:flutter_test/flutter_test.dart';
import 'package:musify/models/playback_source_info.dart';

void main() {
  test(
    'attribution uses the delivered MIME without guessing bitrate or codec',
    () {
      for (final mime in [
        'audio/mp4',
        'video/mp4',
        'audio/webm',
        'video/webm',
      ]) {
        final source = PlaybackSourceInfo.loaded(
          'https://r.example.googlevideo.com/videoplayback?mime=$mime&token=private',
          isOffline: false,
        );
        expect(source.kind, PlaybackSourceKind.youtube);
        expect(source.container, mime.endsWith('mp4') ? 'MP4' : 'WebM');
        expect(source.includesVideo, mime.startsWith('video/'));
      }
    },
  );
  test(
    'unknown MIME and foreign hosts do not inherit YouTube format claims',
    () {
      final unknown = PlaybackSourceInfo.loaded(
        'https://r.example.googlevideo.com/videoplayback',
        isOffline: false,
      );
      expect(unknown.container, isNull);
      expect(unknown.includesVideo, isNull);
      for (final url in [
        'https://googlevideo.com.evil.invalid/?mime=video/mp4',
        'https://example.invalid/?mime=video/mp4',
        'http://r.example.googlevideo.com/?mime=video/mp4',
      ]) {
        expect(
          PlaybackSourceInfo.loaded(url, isOffline: false).kind,
          PlaybackSourceKind.unknown,
        );
      }
    },
  );
  test('local file extension never establishes verified audio quality', () {
    final local = PlaybackSourceInfo.loaded(
      '/owned/file.flac',
      isOffline: true,
    );
    expect(local.kind, PlaybackSourceKind.local);
    expect(local.container, isNull);
    expect(local.includesVideo, isNull);
  });
}
