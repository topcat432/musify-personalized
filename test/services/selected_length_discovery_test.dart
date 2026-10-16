import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:musify/utilities/app_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _id = 'fixture1234';
const _url = 'https://r1.fixture.googlevideo.com/owned?sig=owned%2Ffixture';
String _player({bool tie = false}) => jsonEncode({
  'playabilityStatus': {'status': 'OK'},
  'videoDetails': {'videoId': _id, 'lengthSeconds': '120'},
  'streamingData': {
    'formats': [
      for (final tag in [18, 22])
        {
          'itag': tag,
          'url': tag == 18 ? _url : 'https://r1.fixture.googlevideo.com/other',
          'mimeType': 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
          'bitrate': 500000,
          'width': 640,
          'height': tag == 18 || tie ? 360 : 720,
          'qualityLabel': tag == 18 || tie ? '360p' : '720p',
          'fps': 30,
          if (tie && tag == 22) 'contentLength': '50',
        },
    ],
  },
});

class _Wire extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  final requests = <http.BaseRequest>[];
  _Wire(this.handler);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return handler(request);
  }
}

http.StreamedResponse _metadata(http.BaseRequest request, {bool tie = false}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(_player(tie: tie))),
      200,
      request: request,
    );
http.StreamedResponse _probe(
  http.BaseRequest request, {
  int status = 206,
  String range = 'bytes 0-0/100',
  String type = 'video/mp4',
  int? length = 1,
  List<int> body = const [0],
}) => http.StreamedResponse(
  Stream.value(body),
  status,
  request: request,
  contentLength: length,
  headers: {'content-range': range, 'content-type': type},
);
Future<StreamManifest> _manifest(
  YoutubeExplode yt, {
  int cap = 1000,
  Duration timeout = const Duration(seconds: 1),
}) => yt.videos.streams.getManifestWithSelectedLength(
  _id,
  ytClients: [YoutubeApiClient.androidSdkless],
  streamForValidation: (streams) => selectPlaybackStreamForQuality(
    StreamManifest(streams),
    _id,
    preferMuxed: true,
  ),
  maximumStreamBytes: cap,
  probeTimeout: timeout,
);

class _CredentialClient extends YoutubeHttpClient {
  _CredentialClient(super.client);
  @override
  Map<String, String> get headers => {
    ...super.headers,
    'cookie': 'synthetic-api-cookie',
    'authorization': 'synthetic-api-authorization',
    'proxy-authorization': 'synthetic-proxy-authorization',
  };
}

void main() {
  test(
    'unknown-length advertised muxed source is selected then learned without HEAD',
    () async {
      final wire = _Wire(
        (r) async => r.method == 'POST' ? _metadata(r) : _probe(r),
      );
      final yt = YoutubeExplode(httpClient: YoutubeHttpClient(wire));
      try {
        final manifest = await _manifest(yt);
        final chosen = selectPlaybackStreamForQuality(
          manifest,
          _id,
          preferMuxed: true,
        )!;
        expect(chosen, isA<MuxedStreamInfo>());
        expect(chosen.tag, 18);
        expect(chosen.size.totalBytes, 100);
        expect(chosen.url.toString(), _url);
        expect(manifest.muxed, hasLength(1));
        expect(chosen.videoId.value, _id);
        expect(chosen.container, StreamContainer.mp4);
        expect(wire.requests.map((r) => r.method), ['POST', 'GET']);
        expect(wire.requests.last.followRedirects, isFalse);
        expect(wire.requests.last.headers['Range'], 'bytes=0-0');
        expect(wire.requests.last.followRedirects, false);
        expect(
          yt.videos.streams.requestHeadersFor(chosen)?['User-Agent'],
          isNotEmpty,
        );
      } finally {
        yt.close();
      }
    },
  );
  test(
    'learning size does not reselect an unprobed same-resolution format',
    () async {
      final wire = _Wire(
        (r) async => r.method == 'POST' ? _metadata(r, tie: true) : _probe(r),
      );
      final yt = YoutubeExplode(httpClient: YoutubeHttpClient(wire));
      try {
        final manifest = await _manifest(yt);
        expect(manifest.muxed, hasLength(2));
        expect(
          selectPlaybackStreamForQuality(manifest, _id, preferMuxed: true)!.tag,
          18,
        );
        expect(manifest.validatedStream!.size.totalBytes, 100);
        expect(wire.requests.last.url.toString(), _url);
      } finally {
        yt.close();
      }
    },
  );
  for (final sample in [
    (
      name: '200 ignores Range',
      status: 200,
      range: 'bytes 0-0/100',
      type: 'video/mp4',
      length: 100,
      body: const <int>[],
    ),
    (
      name: '403 error body',
      status: 403,
      range: '',
      type: 'text/html',
      length: 9,
      body: const <int>[],
    ),
    (
      name: 'wrong start',
      status: 206,
      range: 'bytes 1-1/100',
      type: 'video/mp4',
      length: 1,
      body: const [0],
    ),
    (
      name: 'unknown total',
      status: 206,
      range: 'bytes 0-0/*',
      type: 'video/mp4',
      length: 1,
      body: const [0],
    ),
    (
      name: 'wrong content type',
      status: 206,
      range: 'bytes 0-0/100',
      type: 'text/html',
      length: 1,
      body: const [0],
    ),
    (
      name: 'wrong length',
      status: 206,
      range: 'bytes 0-0/100',
      type: 'video/mp4',
      length: 2,
      body: const [0, 1],
    ),
    (
      name: 'empty body',
      status: 206,
      range: 'bytes 0-0/100',
      type: 'video/mp4',
      length: 1,
      body: const <int>[],
    ),
    (
      name: 'oversized body',
      status: 206,
      range: 'bytes 0-0/100',
      type: 'video/mp4',
      length: 1,
      body: const [0, 1],
    ),
    (
      name: 'over cap',
      status: 206,
      range: 'bytes 0-0/1001',
      type: 'video/mp4',
      length: 1,
      body: const [0],
    ),
    (
      name: 'redirect302',
      status: 302,
      range: 'bytes 0-0/100',
      type: 'video/mp4',
      length: 1,
      body: const [0],
    ),
  ]) {
    test(
      '${sample.name} is terminal with one selected GET and no fallback',
      () async {
        final wire = _Wire(
          (r) async => r.method == 'POST'
              ? _metadata(r)
              : _probe(
                  r,
                  status: sample.status,
                  range: sample.range,
                  type: sample.type,
                  length: sample.length,
                  body: sample.body,
                ),
        );
        final yt = YoutubeExplode(httpClient: YoutubeHttpClient(wire));
        try {
          await expectLater(
            _manifest(yt),
            throwsA(
              isA<FatalFailureException>()
                  .having((e) => e.terminal, 'terminal', true)
                  .having(
                    (e) => e.statusCode,
                    'preserved HTTP status',
                    sample.status == 206 ? 0 : sample.status,
                  ),
            ),
          );
          expect(wire.requests.map((r) => r.method), ['POST', 'GET']);
          expect(wire.requests.last.followRedirects, isFalse);
        } finally {
          yt.close();
        }
      },
    );
  }
  test(
    'ignored200 cancels promptly without consuming a full response',
    () async {
      var cancelled = false;
      var bytesSeen = 0;
      late StreamController<List<int>> controller;
      controller = StreamController(
        onListen: () => controller.add(List.filled(10000, 0)),
        onCancel: () {
          cancelled = true;
        },
      );
      final wire = _Wire(
        (r) async => r.method == 'POST'
            ? _metadata(r)
            : http.StreamedResponse(
                controller.stream.map((bytes) {
                  bytesSeen += bytes.length;
                  return bytes;
                }),
                200,
                request: r,
                contentLength: 10000,
              ),
      );
      final yt = YoutubeExplode(httpClient: YoutubeHttpClient(wire));
      try {
        await expectLater(_manifest(yt), throwsA(isA<FatalFailureException>()));
        expect(cancelled, true);
        expect(bytesSeen, 0);
      } finally {
        yt.close();
      }
    },
  );
  test(
    'header timeout aborts the single request without another metadata attempt',
    () async {
      var aborted = false;
      final wire = _Wire((r) async {
        if (r.method == 'POST') return _metadata(r);
        (r as http.Abortable).abortTrigger!.then((_) {
          aborted = true;
        });
        return Completer<http.StreamedResponse>().future;
      });
      final yt = YoutubeExplode(httpClient: YoutubeHttpClient(wire));
      try {
        await expectLater(
          _manifest(yt, timeout: const Duration(milliseconds: 20)),
          throwsA(isA<FatalFailureException>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(aborted, true);
        expect(wire.requests, hasLength(2));
      } finally {
        yt.close();
      }
    },
  );
  test(
    'cancellation timeout is terminal and cannot publish a learned format',
    () async {
      late StreamController<List<int>> controller;
      controller = StreamController(
        onListen: () => controller.add([0]),
        onCancel: () => Completer<void>().future,
      );
      final wire = _Wire(
        (r) async => r.method == 'POST'
            ? _metadata(r)
            : http.StreamedResponse(
                controller.stream,
                206,
                request: r,
                contentLength: 1,
                headers: {
                  'content-range': 'bytes 0-0/100',
                  'content-type': 'video/mp4',
                },
              ),
      );
      final yt = YoutubeExplode(httpClient: YoutubeHttpClient(wire));
      try {
        await expectLater(
          _manifest(yt, timeout: const Duration(milliseconds: 20)),
          throwsA(isA<FatalFailureException>()),
        );
        expect(wire.requests, hasLength(2));
      } finally {
        yt.close();
      }
    },
  );
  test(
    'two explicit same-provider redirects preserve selection and headers',
    () async {
      final first = Uri.parse(_url);
      final second = Uri.parse(
        'https://r2.fixture.googlevideo.com/owned?itag=18',
      );
      final finalUri = Uri.parse(
        'https://r3.fixture.googlevideo.com/owned?itag=18',
      );
      final wire = _Wire((r) async {
        if (r.method == 'POST') return _metadata(r);
        if (r.url == first || r.url == second)
          return http.StreamedResponse(
            Stream.value(const [0]),
            302,
            headers: {
              'location': (r.url == first ? second : finalUri).toString(),
            },
            request: r,
          );
        return _probe(r);
      });
      final yt = YoutubeExplode(httpClient: _CredentialClient(wire));
      try {
        final manifest = await _manifest(yt);
        final chosen = selectPlaybackStreamForQuality(
          manifest,
          _id,
          preferMuxed: true,
        )!;
        expect(chosen.videoId.value, _id);
        expect(chosen.tag, 18);
        expect(chosen.url, finalUri);
        expect(chosen.size.totalBytes, 100);
        final media = wire.requests.where((r) => r.method == 'GET').toList();
        expect(media.length, 3);
        for (final r in media) {
          expect(r.followRedirects, isFalse);
          expect(r.headers, media.first.headers);
          expect(
            r.headers.keys.map((k) => k.toLowerCase()),
            isNot(contains('cookie')),
          );
          expect(
            r.headers.keys.map((k) => k.toLowerCase()),
            isNot(contains('authorization')),
          );
          expect(
            r.headers.keys.map((k) => k.toLowerCase()),
            isNot(contains('proxy-authorization')),
          );
        }
        expect(
          yt.videos.streams.requestHeadersFor(chosen),
          yt.videos.streams.requestHeadersFor(manifest.validatedStream!),
        );
      } finally {
        yt.close();
      }
    },
  );
  for (final location in [
    'http://r2.fixture.googlevideo.com/owned',
    'https://googlevideo.com.evil.example/owned',
    'https://evilgooglevideo.com/owned',
    'https://localhost/owned',
    'https://localhost.googlevideo.com/owned',
    'https://127.0.0.1/owned',
    'https://10.0.0.1/owned',
    'https://192.168.1.1/owned',
    'https://[::1]/owned',
    'https://127.0.0.1.googlevideo.com/owned',
    'https://user:pass@r2.fixture.googlevideo.com/owned',
    'https://r2.fixture.googlevideo.com:8443/owned',
    'https://r2.fixture.googlevideo.com/other',
    'https://r2.fixture.googlevideo.com/owned?itag=22',
    'https://r2.fixture.googlevideo.com/owned#fragment',
    _url,
  ]) {
    test(
      'unapproved or looping redirect rejected before another request: $location',
      () async {
        final wire = _Wire(
          (r) async => r.method == 'POST'
              ? _metadata(r)
              : http.StreamedResponse(
                  Stream.value(const [0]),
                  302,
                  headers: {'location': location},
                  request: r,
                ),
        );
        final yt = YoutubeExplode(httpClient: YoutubeHttpClient(wire));
        try {
          await expectLater(
            _manifest(yt),
            throwsA(
              isA<FatalFailureException>()
                  .having((e) => e.terminal, 'terminal', true)
                  .having((e) => e.statusCode, 'status', 302),
            ),
          );
          expect(wire.requests.map((r) => r.method), ['POST', 'GET']);
        } finally {
          yt.close();
        }
      },
    );
  }
  test('third redirect exceeds hop cap without fourth GET', () async {
    var n = 0;
    final wire = _Wire(
      (r) async => r.method == 'POST'
          ? _metadata(r)
          : http.StreamedResponse(
              Stream.value(const [0]),
              302,
              headers: {
                'location':
                    'https://r${++n + 1}.fixture.googlevideo.com/owned?itag=18',
              },
              request: r,
            ),
    );
    final yt = YoutubeExplode(httpClient: YoutubeHttpClient(wire));
    try {
      await expectLater(_manifest(yt), throwsA(isA<FatalFailureException>()));
      expect(wire.requests.where((r) => r.method == 'GET'), hasLength(3));
    } finally {
      yt.close();
    }
  });
  for (final denied in [401, 403]) {
    test('redirect then$denied stops without following its Location', () async {
      var n = 0;
      final wire = _Wire(
        (r) async => r.method == 'POST'
            ? _metadata(r)
            : http.StreamedResponse(
                Stream.value(const [0]),
                ++n == 1 ? 302 : denied,
                headers: {
                  'location':
                      'https://r${n + 1}.fixture.googlevideo.com/owned?itag=18',
                },
                request: r,
              ),
      );
      final yt = YoutubeExplode(httpClient: YoutubeHttpClient(wire));
      try {
        await expectLater(
          _manifest(yt),
          throwsA(
            isA<FatalFailureException>().having(
              (e) => e.statusCode,
              'status',
              denied,
            ),
          ),
        );
        expect(wire.requests.where((r) => r.method == 'GET'), hasLength(2));
      } finally {
        yt.close();
      }
    });
  }
}
