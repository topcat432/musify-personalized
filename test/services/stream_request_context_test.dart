import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/online_audio_source.dart';
import 'package:musify/services/stream_request_context.dart';
import 'package:musify/services/stream_url_validation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _fixtureAgent = 'Musify-Owned-Fixture/1.0';
const _signedUrl =
    'https://r1.fixture.googlevideo.com/videoplayback?c=ANDROID&clen=16&mime=audio%2Fwebm&sig=owned%2Ffixture';

const _fixtureClient = YoutubeApiClient(
  {
    'context': {
      'client': {
        'clientName': 'ANDROID',
        'clientVersion': 'owned-fixture',
        'userAgent': _fixtureAgent,
      },
    },
  },
  'https://www.youtube.com/youtubei/v1/player',
  headers: {
    'Cookie': 'owned-private-fixture',
    'X-Goog-Visitor-Id': 'owned-private-fixture',
  },
);

class _RefreshedStreamClient extends StreamClient {
  _RefreshedStreamClient(super.client, this.stream);
  final StreamInfo stream;
  var refreshes = 0;

  @override
  Future<StreamManifest> getManifest(
    dynamic videoId, {
    bool fullManifest = false,
    List<YoutubeApiClient>? ytClients,
    bool requireWatchPage = true,
  }) async {
    refreshes++;
    return StreamManifest([stream]);
  }

  @override
  Map<String, String> requestHeadersFor(StreamInfo stream) => const {
    'User-Agent': _fixtureAgent,
  };
}

void main() {
  test('cached validation retains the exact URL and recorded agent', () async {
    final contexts = StreamRequestContexts();
    contexts.remember(_signedUrl, const {'User-Agent': _fixtureAgent});
    expect(
      await validateStreamUrl(
        _signedUrl,
        headers: contexts.forUrl(_signedUrl)!,
        client: MockClient((request) async {
          expect(request.url.toString(), _signedUrl);
          expect(request.method, 'GET');
          expect(request.headers, {
            'User-Agent': _fixtureAgent,
            'Range': 'bytes=0-0',
          });
          return http.Response('', 206, request: request);
        }),
      ),
      isTrue,
    );
  });

  test(
    'a transient retry keeps the permitted refreshed URL and its context',
    () async {
      final urls = <String>[];
      var refreshedReads = 0;
      const refreshedUrl = '$_signedUrl&generation=2';
      final transport = YoutubeHttpClient(
        MockClient((request) async {
          urls.add(request.url.toString());
          expect(request.headers['user-agent'], _fixtureAgent);
          expect(request.headers['Range'], 'bytes=0-15');
          if (request.url.toString() == _signedUrl) {
            return http.Response('', 404, request: request);
          }
          expect(request.url.toString(), refreshedUrl);
          if (++refreshedReads == 1) {
            return http.Response('', 503, request: request);
          }
          return http.Response.bytes(
            List.generate(16, (i) => i),
            206,
            request: request,
          );
        }),
      );
      AudioOnlyStreamInfo fixture(String url) => AudioOnlyStreamInfo(
        VideoId('fixture1234'),
        251,
        Uri.parse(url),
        StreamContainer.parse('webm'),
        FileSize(16),
        Bitrate(128000),
        'opus',
        'owned',
        [],
        MediaType('audio', 'webm', {'codecs': 'opus'}),
        null,
      );
      final client = _RefreshedStreamClient(transport, fixture(refreshedUrl));
      try {
        expect(
          await transport
              .getStream(
                fixture(_signedUrl),
                streamClient: client,
                headers: const {'User-Agent': _fixtureAgent},
              )
              .expand((b) => b)
              .toList(),
          List.generate(16, (i) => i),
        );
        expect(client.refreshes, 1);
        expect(urls, [_signedUrl, refreshedUrl, refreshedUrl]);
      } finally {
        transport.close();
      }
    },
  );

  test(
    'native complete ranges retain the original agent and signed query',
    () async {
      final requests = <http.Request>[];
      final source = GoogleVideoByteSource(
        Uri.parse(_signedUrl),
        sourceLength: 16,
        chunkSize: 4,
        requestHeaders: const {'User-Agent': _fixtureAgent},
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          final range = RegExp(
            r'bytes=(\d+)-(\d+)',
          ).firstMatch(request.headers['Range']!)!;
          final start = int.parse(range[1]!);
          final end = int.parse(range[2]!);
          return http.Response.bytes(
            [for (var i = start; i <= end; i++) i],
            206,
            request: request,
            headers: {'content-range': 'bytes $start-$end/16'},
          );
        }),
      );
      expect(
        await (await source.request()).stream.expand((b) => b).toList(),
        List.generate(16, (i) => i),
      );
      expect(requests, hasLength(4));
      for (final request in requests) {
        expect(request.url.toString(), _signedUrl);
        expect(request.headers['user-agent'], _fixtureAgent);
        expect(request.followRedirects, isFalse);
        expect(request.headers.keys.map((key) => key.toLowerCase()).toSet(), {
          'user-agent',
          'range',
        });
      }
    },
  );

  test(
    'legacy, partial, mismatched and credential-bearing contexts are unknown',
    () {
      final contexts = StreamRequestContexts();
      for (final raw in [
        null,
        {},
        {'version': 1},
        {
          'version': 1,
          'url': '$_signedUrl&other=1',
          'headers': {'User-Agent': _fixtureAgent},
        },
        {
          'version': 1,
          'url': _signedUrl,
          'headers': {'Cookie': 'owned-fixture'},
        },
        {
          'version': 1,
          'url': _signedUrl,
          'headers': {'User-Agent': 'bad\r\nheader'},
        },
        {
          'version': 1,
          'url': _signedUrl,
          'headers': {
            'User-Agent': _fixtureAgent,
            'user-agent': 'ambiguous-owned-fixture',
          },
        },
      ]) {
        expect(contexts.restore(_signedUrl, raw), isFalse);
        expect(contexts.forUrl(_signedUrl), isNull);
      }
      expect(
        contexts.remember('https://media.example/owned', {
          'User-Agent': _fixtureAgent,
        }),
        isFalse,
      );
    },
  );

  test(
    'request context survives Hive reopen without changing existing cache data',
    () async {
      final directory = await Directory.systemTemp.createTemp('owned-context-');
      Hive.init(directory.path);
      final box = await Hive.openBox('ownedCache');
      final contexts = StreamRequestContexts();
      try {
        await box.put('legacyUrl', _signedUrl);
        await box.put('legacyMarker', {
          'kept': true,
          'order': [2, 1],
        });
        expect(
          contexts.remember(_signedUrl, {'User-Agent': _fixtureAgent}),
          isTrue,
        );
        await box.put('requestContext', contexts.snapshot(_signedUrl));
        await box.close();
        final reopened = await Hive.openBox('ownedCache');
        final restarted = StreamRequestContexts();
        expect(
          restarted.restore(_signedUrl, reopened.get('requestContext')),
          isTrue,
        );
        expect(restarted.forUrl(_signedUrl), {'User-Agent': _fixtureAgent});
        expect(reopened.get('legacyUrl'), _signedUrl);
        expect(reopened.get('legacyMarker'), {
          'kept': true,
          'order': [2, 1],
        });
        await reopened.close();
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'native source factory uses known context and does not guess for another URL',
    () {
      streamRequestContexts.remember(_signedUrl, {'User-Agent': _fixtureAgent});
      final bounded =
          onlineAudioSource(_signedUrl, enableBoundedTransport: true)
              as GoogleVideoByteSource;
      expect(bounded.requestHeaders, {'User-Agent': _fixtureAgent});
      final direct =
          onlineAudioSource(_signedUrl, enableBoundedTransport: false)
              as UriAudioSource;
      expect(direct.headers, {'User-Agent': _fixtureAgent});
      final unknown =
          onlineAudioSource(
                '$_signedUrl&unknown=1',
                enableBoundedTransport: true,
              )
              as GoogleVideoByteSource;
      expect(unknown.requestHeaders, isEmpty);
    },
  );

  for (final declaredLength in [true, false]) {
    test(
      'same resolving agent reaches media with declared length $declaredLength '
      'without forwarding session headers',
      () async {
        final requests = <http.Request>[];
        final yt = YoutubeExplode(
          httpClient: YoutubeHttpClient(
            MockClient((request) async {
              requests.add(request);
              if (request.method == 'POST') {
                return http.Response(
                  jsonEncode({
                    'playabilityStatus': {'status': 'OK'},
                    'streamingData': {
                      'adaptiveFormats': [
                        {
                          'itag': 251,
                          'url': _signedUrl,
                          'mimeType': 'audio/webm; codecs="opus"',
                          'bitrate': 128000,
                          if (declaredLength) 'contentLength': '16',
                          'audioSampleRate': '48000',
                          'audioChannels': 2,
                        },
                      ],
                    },
                    'videoDetails': {
                      'videoId': 'fixture1234',
                      'title': 'Owned fixture',
                    },
                  }),
                  200,
                  request: request,
                );
              }
              if (request.method == 'HEAD') {
                expect(request.headers['user-agent'], _fixtureAgent);
                expect(request.url.toString(), _signedUrl);
                return http.Response(
                  '',
                  200,
                  request: request,
                  headers: const {'content-length': '16'},
                );
              }
              return http.Response.bytes(
                request.headers['Range'] == 'bytes=0-0'
                    ? const <int>[]
                    : List.generate(16, (index) => index),
                206,
                request: request,
              );
            }),
          ),
        );
        try {
          final manifest = await yt.videos.streams.getManifest(
            'fixture1234',
            ytClients: [_fixtureClient],
            requireWatchPage: false,
          );
          final other = YoutubeExplode();
          try {
            expect(
              other.videos.streams.requestHeadersFor(manifest.audioOnly.single),
              {'User-Agent': _fixtureAgent},
            );
          } finally {
            other.close();
          }
          expect(
            await yt.videos.streams
                .get(manifest.audioOnly.single)
                .expand((bytes) => bytes)
                .toList(),
            List.generate(16, (i) => i),
          );
          expect(
            requests.where((request) => request.method == 'POST'),
            hasLength(1),
          );
          final media = requests
              .where((request) => request.method == 'GET')
              .toList();
          expect(media, hasLength(2));
          for (final request in media) {
            expect(
              request.headers['user-agent'],
              requests.first.headers['user-agent'],
            );
            expect(request.url.toString(), _signedUrl);
            expect(request.headers['cookie'], isNot('owned-private-fixture'));
            expect(request.headers.containsKey('x-goog-visitor-id'), isFalse);
          }
        } finally {
          yt.close();
        }
      },
    );
  }
}
