import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_parser/http_parser.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../tool/visual_review_harness.dart';

MuxedStreamInfo muxed(
  String id, {
  int height = 360,
  String audioCodec = 'mp4a.40.2',
}) => MuxedStreamInfo(
  VideoId(id),
  18,
  Uri.parse('https://media.invalid/$id-$height.mp4'),
  StreamContainer.mp4,
  const FileSize(8192),
  const Bitrate(1000000),
  audioCodec,
  'avc1',
  '${height}p',
  VideoQuality.medium360,
  VideoResolution(640, height),
  const Framerate(30),
  MediaType('video', 'mp4'),
);
Future<void> waitForCache(String key, String value) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (Hive.box('cache').get(key) == value) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(Hive.box('cache').get(key), value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('muxed-owned-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  test(
    'same-selected-video muxed-only manifest remains playable without a second lookup',
    () async {
      var calls = 0;
      final stream = muxed('owned-muxed');
      final url = await fetchSongStreamUrl(
        'owned-muxed',
        false,
        manifestLoader: (id) async {
          calls++;
          expect(id, 'owned-muxed');
          return StreamManifest([stream]);
        },
      );
      expect(url, stream.url.toString());
      await waitForCache('song_owned-muxed_high_url', stream.url.toString());
      expect(calls, 1);
    },
  );
  test('foreign video and unsupported muxed audio stay unavailable', () {
    expect(
      selectPlaybackStreamForQuality(
        StreamManifest([muxed('other-muxed')]),
        'owned-muxed',
      ),
      isNull,
    );
    expect(
      selectPlaybackStreamForQuality(
        StreamManifest([muxed('owned-muxed', audioCodec: 'ec-3')]),
        'owned-muxed',
      ),
      isNull,
    );
  });
  test(
    'muxed selection minimizes video data without ranking it as audio quality',
    () {
      final low = muxed('owned-muxed');
      expect(
        selectPlaybackStreamForQuality(
          StreamManifest([muxed('owned-muxed', height: 720), low]),
          'owned-muxed',
        ),
        same(low),
      );
    },
  );
  test('audio preference remains primary and muxed preference is explicit', () {
    final audio = AudioOnlyStreamInfo(
      VideoId('owned-muxed'),
      140,
      Uri.parse('https://media.invalid/audio'),
      StreamContainer.mp4,
      const FileSize(100),
      const Bitrate(128000),
      'mp4a.40.2',
      'medium',
      const [],
      MediaType('audio', 'mp4'),
      null,
    );
    final video = muxed('owned-muxed');
    final manifest = StreamManifest([video, audio]);
    expect(
      selectPlaybackStreamForQuality(manifest, 'owned-muxed'),
      same(audio),
    );
    expect(
      selectPlaybackStreamForQuality(
        manifest,
        'owned-muxed',
        preferMuxed: true,
      ),
      same(video),
    );
  });
  test(
    'explicit muxed mode preserves the older audio cache and source identity',
    () async {
      const key = 'song_owned-mode1_high_url';
      await Hive.box('cache').put(key, 'https://media.invalid/older-audio');
      var calls = 0;
      final video = muxed('owned-mode1');
      final url = await fetchSongStreamUrl(
        'owned-mode1',
        false,
        preferMuxed: true,
        manifestLoader: (id) async {
          calls++;
          return StreamManifest([video]);
        },
      );
      expect(url, video.url.toString());
      await waitForCache(
        'song_owned-mode1_muxed_high_url',
        video.url.toString(),
      );
      expect(calls, 1);
      expect(Hive.box('cache').get(key), 'https://media.invalid/older-audio');
    },
  );
}
