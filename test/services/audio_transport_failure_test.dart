import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio/src/stream_audio_response_writer.dart';
import 'package:musify/services/audio_transport_failure.dart';
import 'package:musify/services/online_audio_source.dart';

final _uri = Uri.parse(
  'https://owned.fixture.googlevideo.com/media?clen=10&sig=PRIVATE_SIGNATURE&token=PRIVATE_TOKEN',
);

class _Client extends http.BaseClient {
  _Client(this.respond, {this.onClose});
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  final void Function()? onClose;
  final requests = <http.BaseRequest>[];
  var closes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    expect(request.url, _uri);
    expect(request.method, 'GET');
    expect(request.followRedirects, isFalse);
    return respond(request);
  }

  @override
  void close() {
    closes++;
    onClose?.call();
  }
}

http.StreamedResponse _response(
  List<int> bytes, {
  int status = 206,
  String range = 'bytes 0-9/10',
  int? length,
}) => http.StreamedResponse(
  Stream.value(bytes),
  status,
  headers: {'content-range': range},
  contentLength: length,
);
Future<AudioTransportFailure> _failure(GoogleVideoByteSource source) async {
  try {
    await (await source.request()).stream.drain<void>();
  } on AudioTransportFailure catch (error) {
    return error;
  }
  throw StateError('Expected a fixture failure.');
}

void _redacted(Object diagnostic) {
  final text = '$diagnostic';
  for (final private in [
    'PRIVATE_SIGNATURE',
    'PRIVATE_TOKEN',
    'SECRET_BODY',
    'PRIVATE_METADATA',
    'googlevideo.com',
    'https://',
    'videoplayback',
  ]) {
    expect(text, isNot(contains(private)));
  }
}

void main() {
  test(
    'first later-range denial survives local retry and pre-created read',
    () async {
      final diagnostics = <Map<String, Object?>>[];
      final client = _Client(
        (request) async => request.headers['Range'] == 'bytes=0-3'
            ? _response([0, 1, 2, 3], range: 'bytes 0-3/10', length: 4)
            : _response(
                [],
                status: 403,
                range: 'SECRET_BODY PRIVATE_TOKEN',
                length: 0,
              ),
      );
      var callbacks = 0;
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        chunkSize: 4,
        clientFactory: () => client,
        onDiagnostic: diagnostics.add,
        onUnavailable: () => callbacks++,
      );
      final waiting = await source.request(4, 8);
      final failure = await _failure(source);
      expect(source.failure, same(failure));
      expect(failure.kind, 'httpStatus');
      expect(failure.httpStatus, 403);
      expect(failure.rangeStart, 4);
      expect(failure.rangeLastInclusive, 7);
      expect(failure.receivedBytes, 0);
      expect(failure.deliveredBytes, 4);
      expect(failure.responseLength, 0);
      expect(failure.contentRange, isNull);
      expect(failure.diagnostic['contentRangeState'], 'invalid');
      expect(failure.cause, isA<StateError>());
      await expectLater(source.request(4), throwsA(same(failure)));
      await expectLater(waiting.stream.drain<void>(), throwsA(same(failure)));
      expect(client.requests.length, 2);
      expect(client.closes, 1);
      expect(callbacks, 1);
      expect(diagnostics.length, 1);
      _redacted(failure);
      _redacted(jsonEncode(diagnostics));
    },
  );

  for (final range in ['Bytes 0-9/10', 'bytes 0-9/*', ' bytes 0-9/10 ']) {
    test('valid Content-Range variant delivers exact bytes: $range', () async {
      final client = _Client(
        (_) async =>
            _response(List.generate(10, (i) => i), range: range, length: 10),
      );
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        clientFactory: () => client,
      );
      expect(
        await (await source.request()).stream.expand((b) => b).toList(),
        List.generate(10, (i) => i),
      );
      expect(source.failure, isNull);
      expect(client.requests.single.headers['Range'], 'bytes=0-9');
    });
  }

  for (final fixture in [
    ('contentRange', _response([], range: 'bytes 0-9/11')),
    ('contentRange', _response([], range: 'bytes 1-9/10')),
    ('contentRange', _response([], range: 'bytes */10')),
    ('contentLength', _response([], length: 9)),
    ('truncatedBody', _response([0, 1, 2])),
    ('oversizedBody', _response(List.filled(11, 0))),
  ]) {
    test('classifies ${fixture.$1} separately from provider denial', () async {
      final diagnostics = <Map<String, Object?>>[];
      final client = _Client((_) async => fixture.$2);
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        clientFactory: () => client,
        onDiagnostic: diagnostics.add,
      );
      final failure = await _failure(source);
      expect(failure.kind, fixture.$1);
      expect(failure.httpStatus, 206);
      expect(failure.rangeStart, 0);
      expect(failure.rangeLastInclusive, 9);
      expect(failure.sourceLength, 10);
      expect(failure.nativeEndExclusive, 10);
      if (fixture.$1 == 'truncatedBody') {
        expect(failure.receivedBytes, 3);
        expect(failure.deliveredBytes, 3);
      }
      if (fixture.$1 == 'oversizedBody') {
        expect(failure.receivedBytes, 11);
        expect(failure.deliveredBytes, 0);
      }
      await expectLater(source.request(), throwsA(same(failure)));
      expect(client.requests.length, 1);
      _redacted(jsonEncode(diagnostics));
    });
  }

  test(
    'network exception retains original object/stack but redacts its URI/message',
    () async {
      final cause = http.ClientException('PRIVATE_METADATA $_uri', _uri);
      final stack = StackTrace.fromString('owned-original-stack');
      final diagnostics = <Map<String, Object?>>[];
      final client = _Client((_) => Future.error(cause, stack));
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        clientFactory: () => client,
        onDiagnostic: diagnostics.add,
      );
      final failure = await _failure(source);
      expect(failure.kind, 'network');
      expect(failure.httpStatus, isNull);
      expect(failure.cause, same(cause));
      expect(failure.originStack.toString(), contains('owned-original-stack'));
      expect(failure.receivedBytes, 0);
      expect(failure.diagnostic['causeTypes'], [
        'AudioTransportFailure',
        'ClientException',
      ]);
      _redacted(failure);
      _redacted(jsonEncode(diagnostics));
    },
  );

  test(
    'body exception retains partial-byte counts and originating status',
    () async {
      final cause = http.ClientException('SECRET_BODY PRIVATE_TOKEN', _uri);
      final client = _Client(
        (_) async => http.StreamedResponse(
          Stream.fromIterable([
            [1, 2, 3],
          ]).asyncExpand((bytes) async* {
            yield bytes;
            throw cause;
          }),
          206,
          headers: {'content-range': 'bytes 0-9/10'},
        ),
      );
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        clientFactory: () => client,
      );
      final failure = await _failure(source);
      expect(failure.kind, 'network');
      expect(failure.cause, same(cause));
      expect(failure.httpStatus, 206);
      expect(failure.receivedBytes, 3);
      expect(failure.deliveredBytes, 3);
      _redacted(failure);
    },
  );

  test(
    'invalid native range is diagnostic only and fetches no upstream bytes',
    () async {
      final diagnostics = <Map<String, Object?>>[];
      final client = _Client((_) async => _response([]));
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        clientFactory: () => client,
        onDiagnostic: diagnostics.add,
      );
      await expectLater(source.request(10, 11), throwsRangeError);
      expect(client.requests, isEmpty);
      expect(source.failure, isNull);
      expect(diagnostics.single['kind'], 'invalidRange');
      expect(diagnostics.single['stage'], 'nativeRequest');
    },
  );

  for (final phase in ['headers', 'body']) {
    test('$phase timeout retains the original phase/status', () async {
      final body = StreamController<List<int>>();
      final pending = Completer<http.StreamedResponse>();
      final client = _Client(
        (_) => phase == 'headers'
            ? pending.future
            : Future.value(
                http.StreamedResponse(
                  body.stream,
                  206,
                  headers: {'content-range': 'bytes 0-9/10'},
                ),
              ),
      );
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        clientFactory: () => client,
        timeout: const Duration(milliseconds: 15),
      );
      final failure = await _failure(source);
      expect(failure.kind, 'timeout');
      expect(failure.phase, phase);
      expect(failure.cause, isA<TimeoutException>());
      expect(failure.httpStatus, phase == 'body' ? 206 : null);
      await expectLater(source.request(), throwsA(same(failure)));
      expect(client.requests.length, 1);
      unawaited(body.close());
    });
  }

  test(
    'an already active read retains the first denial and yields no later bytes',
    () async {
      final pending = Completer<http.StreamedResponse>();
      final started = Completer<void>();
      final waiting = _Client((_) {
        started.complete();
        return pending.future;
      });
      final denied = _Client(
        (_) async => _response([], status: 403, length: 0),
      );
      var factories = 0;
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        clientFactory: () => ++factories == 1 ? waiting : denied,
      );
      final active = (await source.request()).stream.drain<void>();
      await started.future;
      final firstFailure = await _failure(source);
      final checkActive = expectLater(active, throwsA(same(firstFailure)));
      pending.complete(_response(List.generate(10, (i) => i), length: 10));
      await checkActive;
      expect(waiting.requests.length, 1);
      expect(denied.requests.length, 1);
      expect(waiting.closes, 1);
      expect(denied.closes, 1);
      expect(source.failure, same(firstFailure));
    },
  );

  test(
    'real loopback retains source cause through later close/disconnect error',
    () async {
      final diagnostics = <Map<String, Object?>>[];
      final failures = <StreamAudioResponseFailure>[];
      final originClient = _Client(
        (request) async => request.headers['Range'] == 'bytes=0-3'
            ? _response([0, 1, 2, 3], range: 'bytes 0-3/10', length: 4)
            : _response([], status: 403, length: 0),
      );
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        chunkSize: 4,
        clientFactory: () => originClient,
        onDiagnostic: diagnostics.add,
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final finished = Completer<void>();
      server.listen((request) async {
        final response = await source.request();
        request.response.contentLength = response.contentLength!;
        await writeStreamAudioResponse(
          response.stream,
          request.response,
          onFailure: (failure) {
            failures.add(failure);
            source.onResponseFailure(failure);
          },
        );
        finished.complete();
      });
      final nativeClient = HttpClient();
      try {
        await expectLater(() async {
          final response = await (await nativeClient.getUrl(
            Uri.http('127.0.0.1:${server.port}', '/owned-fixture'),
          )).close();
          await response.drain<void>();
        }(), throwsA(isA<HttpException>()));
        await finished.future.timeout(const Duration(seconds: 2));
        expect(failures.first.phase, 'source');
        expect(failures.first.cause, same(source.failure));
        expect(failures.first.writtenBytes, 4);
        expect(failures.first.expectedBytes, 10);
        expect(source.failure!.httpStatus, 403);
        for (final failure in failures.skip(1)) {
          expect(failure.preceding, same(failures.first));
        }
        expect(diagnostics.first['stage'], 'origin');
        expect(diagnostics.last['stage'], 'loopback');
        expect(diagnostics.last['origin'], source.failure!.diagnostic);
        _redacted(jsonEncode(diagnostics));
        await expectLater(source.request(), throwsA(same(source.failure)));
        expect(originClient.requests.length, 2);
      } finally {
        nativeClient.close(force: true);
        await server.close(force: true);
      }
    },
  );
}
