import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _fixtureId = 'fixture1234';

String _playerFixture({String url = 'https://media.example/owned-audio'}) =>
    jsonEncode({
      'playabilityStatus': {'status': 'OK'},
      'streamingData': {
        'adaptiveFormats': [
          {
            'itag': 251,
            'url': url,
            'mimeType': 'audio/webm; codecs="opus"',
            'bitrate': 128000,
            'contentLength': '16',
            'audioSampleRate': '48000',
            'audioChannels': 2,
          },
        ],
      },
      'videoDetails': {'videoId': _fixtureId, 'title': 'Owned fixture'},
    });

void main() {
  test(
    'complete owned byte fixture finishes and the next source can download',
    () async {
      final requests = <http.Request>[];
      var players = 0;
      final yt = YoutubeExplode(
        httpClient: YoutubeHttpClient(
          MockClient((r) async {
            requests.add(r);
            if (r.method == 'POST') {
              players++;
              return http.Response(
                _playerFixture(
                  url:
                      'https://media.example/owned-audio?c=ANDROID&fixture=$players',
                ),
                200,
                request: r,
              );
            }
            expect(r.method, 'GET');
            if (r.headers['Range'] == 'bytes=0-0')
              return http.Response('', 206, request: r);
            expect(r.headers['Range'], 'bytes=0-15');
            return http.Response.bytes(
              List.generate(16, (i) => i),
              206,
              request: r,
            );
          }),
        ),
      );
      try {
        for (final id in [_fixtureId, 'fixture5678']) {
          final manifest = await yt.videos.streams.getManifest(
            id,
            requireWatchPage: false,
          );
          expect(
            await yt.videos.streams
                .get(manifest.audioOnly.single)
                .expand((b) => b)
                .toList(),
            List.generate(16, (i) => i),
          );
        }
        expect(players, 2);
        expect(requests, hasLength(6));
        expect(requests[2].url.queryParameters['fixture'], '1');
        expect(requests[5].url.queryParameters['fixture'], '2');
      } finally {
        yt.close();
      }
    },
  );

  test(
    'player API denial is terminal before media or client fallback',
    () async {
      final requests = <http.Request>[];
      final yt = YoutubeExplode(
        httpClient: YoutubeHttpClient(
          MockClient((r) async {
            requests.add(r);
            return http.Response('', 403, request: r);
          }),
        ),
      );
      try {
        await expectLater(
          yt.videos.streams.getManifest(_fixtureId, requireWatchPage: false),
          throwsA(
            isA<FatalFailureException>().having(
              (e) => e.statusCode,
              'status',
              403,
            ),
          ),
        );
        expect(requests, hasLength(1));
        expect(requests.single.method, 'POST');
      } finally {
        yt.close();
      }
    },
  );

  test(
    'ignored Range body is cancelled without consuming media or changing URI',
    () async {
      const url =
          'https://media.example/owned-audio?sig=synthetic%2Ftest&x=1&x=2&c=ANDROID';
      var cancelled = false;
      var delivered = 0;
      final body = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final requests = <http.BaseRequest>[];
      final yt = YoutubeExplode(
        httpClient: YoutubeHttpClient(
          MockClient.streaming((r, _) async {
            requests.add(r);
            if (r.method == 'POST') {
              return http.StreamedResponse(
                Stream.value(utf8.encode(_playerFixture(url: url))),
                200,
                request: r,
              );
            }
            expect(r.method, 'GET');
            expect(r.url.toString(), url);
            expect(r.headers['Range'], 'bytes=0-0');
            expect(r.followRedirects, isFalse);
            return http.StreamedResponse(
              body.stream.map((chunk) {
                delivered += chunk.length;
                return chunk;
              }),
              200,
              request: r,
            );
          }),
        ),
      );
      try {
        final manifest = await yt.videos.streams.getManifest(
          _fixtureId,
          requireWatchPage: false,
        );
        expect(manifest.audioOnly.single.url.toString(), url);
        expect(cancelled, isTrue);
        expect(delivered, 0);
        expect(requests, hasLength(2));
      } finally {
        yt.close();
        unawaited(body.close());
      }
    },
  );

  test(
    'download GET denial does not refresh a URL or repeat the denied request',
    () async {
      const url = 'https://media.example/owned-audio?c=ANDROID';
      final requests = <http.Request>[];
      final yt = YoutubeExplode(
        httpClient: YoutubeHttpClient(
          MockClient((r) async {
            requests.add(r);
            if (r.method == 'POST')
              return http.Response(_playerFixture(url: url), 200, request: r);
            expect(r.url.toString(), url);
            expect(r.method, 'GET');
            return http.Response(
              '',
              r.headers['Range'] == 'bytes=0-0' ? 206 : 403,
              request: r,
            );
          }),
        ),
      );
      try {
        final manifest = await yt.videos.streams.getManifest(
          _fixtureId,
          requireWatchPage: false,
        );
        await expectLater(
          yt.videos.streams.get(manifest.audioOnly.single).drain<void>(),
          throwsA(
            isA<FatalFailureException>().having(
              (e) => e.statusCode,
              'status',
              403,
            ),
          ),
        );
        expect(requests, hasLength(3));
        expect(requests.last.headers['Range'], 'bytes=0-15');
      } finally {
        yt.close();
      }
    },
  );

  test(
    'real GET denial performs one availability request and no client fallback',
    () async {
      final requests = <http.Request>[];
      final yt = YoutubeExplode(
        httpClient: YoutubeHttpClient(
          MockClient((request) async {
            requests.add(request);
            if (request.method == 'POST')
              return http.Response(_playerFixture(), 200, request: request);
            if (request.method == 'GET')
              return http.Response('', 403, request: request);
            return http.Response(
              'Unexpected fixture route',
              404,
              request: request,
            );
          }),
        ),
      );
      try {
        await expectLater(
          yt.videos.streams.getManifest(_fixtureId, requireWatchPage: false),
          throwsA(isA<YoutubeExplodeException>()),
        );
        expect(requests.where((r) => r.method == 'GET'), hasLength(1));
        expect(requests.where((r) => r.method == 'POST'), hasLength(1));
        expect(requests, hasLength(2));
        expect(requests.last.headers['Range'], 'bytes=0-0');
        expect(
          requests.last.url.toString(),
          'https://media.example/owned-audio',
        );
        expect(requests.last.followRedirects, isFalse);
      } finally {
        yt.close();
      }
    },
  );

  for (final status in [200, 206]) {
    test(
      'allowed manifest HTTP $status retains audio stream selection',
      () async {
        final requests = <http.Request>[];
        final yt = YoutubeExplode(
          httpClient: YoutubeHttpClient(
            MockClient((request) async {
              requests.add(request);
              if (request.method == 'POST')
                return http.Response(_playerFixture(), 200, request: request);
              if (request.method == 'GET')
                return http.Response('', status, request: request);
              throw StateError('Unexpected fixture route or HEAD request');
            }),
          ),
        );
        try {
          final manifest = await yt.videos.streams.getManifest(
            _fixtureId,
            requireWatchPage: false,
          );
          expect(manifest.audioOnly.single.tag, 251);
          expect(
            manifest.audioOnly.single.url.toString(),
            'https://media.example/owned-audio',
          );
          expect(requests, hasLength(2));
        } finally {
          yt.close();
        }
      },
    );
  }

  test(
    'transient manifest failure retains bounded retry and can recover',
    () async {
      var players = 0;
      var availability = 0;
      final yt = YoutubeExplode(
        httpClient: YoutubeHttpClient(
          MockClient((request) async {
            if (request.method == 'POST') {
              players++;
              return http.Response(
                players == 1 ? 'Transient fixture' : _playerFixture(),
                players == 1 ? 503 : 200,
                request: request,
              );
            }
            if (request.method == 'GET') {
              availability++;
              return http.Response('', 200, request: request);
            }
            throw StateError('Unexpected fixture route or HEAD request');
          }),
        ),
      );
      try {
        final manifest = await yt.videos.streams.getManifest(
          _fixtureId,
          requireWatchPage: false,
        );
        expect(manifest.audioOnly, hasLength(1));
        expect(players, 2);
        expect(availability, 1);
      } finally {
        yt.close();
      }
    },
  );
}
