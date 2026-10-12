import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

String fixture() => jsonEncode({
  'playabilityStatus': {'status': 'OK'},
  'videoDetails': {'videoId': 'fixture1234', 'title': 'Owned fixture'},
  'streamingData': {
    'formats': [
      for (final height in [720, 360])
        {
          'itag': height == 720 ? 22 : 18,
          'url': 'https://media.example/owned-$height',
          'mimeType': 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
          'bitrate': 1000000,
          'contentLength': '16',
          'width': 640,
          'height': height,
          'fps': 30,
          'qualityLabel': '${height}p',
        },
    ],
  },
});

void main() {
  for (final status in [206, 403]) {
    test('only selected offered format is probed, status $status', () async {
      final requests = <http.Request>[];
      final yt = YoutubeExplode(
        httpClient: YoutubeHttpClient(
          MockClient((r) async {
            requests.add(r);
            if (r.method == 'POST')
              return http.Response(fixture(), 200, request: r);
            expect(r.url.path, '/owned-360');
            expect(r.headers['Range'], 'bytes=0-0');
            return http.Response('', status, request: r);
          }),
        ),
      );
      try {
        final result = yt.videos.streams.getManifest(
          'fixture1234',
          requireWatchPage: false,
          ytClients: [YoutubeApiClient.androidSdkless],
          streamForValidation: (streams) =>
              streams.whereType<MuxedStreamInfo>().last,
        );
        if (status == 403) {
          await expectLater(result, throwsA(isA<FatalFailureException>()));
        } else {
          expect((await result).muxed, hasLength(2));
        }
        expect(requests.map((r) => r.method), ['POST', 'GET']);
      } finally {
        yt.close();
      }
    });
  }
  test('no eligible selection stops before any media request', () async {
    final requests = <http.Request>[];
    final yt = YoutubeExplode(
      httpClient: YoutubeHttpClient(
        MockClient((r) async {
          requests.add(r);
          expect(r.method, 'POST');
          return http.Response(fixture(), 200, request: r);
        }),
      ),
    );
    try {
      await expectLater(
        yt.videos.streams.getManifest(
          'fixture1234',
          requireWatchPage: false,
          ytClients: [YoutubeApiClient.androidSdkless],
          streamForValidation: (_) => null,
        ),
        throwsA(isA<YoutubeExplodeException>()),
      );
      expect(requests, hasLength(1));
    } finally {
      yt.close();
    }
  });
}
