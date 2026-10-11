import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/online_audio_source.dart';
import 'package:musify/services/audio_transport_failure.dart';

class _Client extends http.BaseClient {
  _Client(this.respond, {this.onClose});
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  final void Function()? onClose;
  final requests = <http.BaseRequest>[];
  int closes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    expect(request.method, 'GET');
    expect(request.url.scheme, 'https');
    expect(request.followRedirects, isFalse);
    expect(request.headers.keys.map((e) => e.toLowerCase()), ['range']);
    return respond(request);
  }

  @override
  void close() {
    closes++;
    onClose?.call();
  }
}

final _uri = Uri.parse(
  'https://r1.test.googlevideo.com/videoplayback?clen=10&mime=audio%2Fmp4',
);
http.StreamedResponse _correct(http.BaseRequest request) {
  final range = RegExp(
    r'^bytes=(\d+)-(\d+)$',
  ).firstMatch(request.headers['Range']!)!;
  final start = int.parse(range[1]!);
  final last = int.parse(range[2]!);
  return http.StreamedResponse(
    Stream.value([for (var i = start; i <= last; i++) i]),
    206,
    headers: {'content-range': 'bytes $start-$last/10'},
    contentLength: last - start + 1,
  );
}

void main() {
  test(
    'open native read is lazy and returns exact finite chunks including tail',
    () async {
      var factories = 0;
      final client = _Client((r) async => _correct(r));
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        chunkSize: 4,
        clientFactory: () {
          factories++;
          return client;
        },
      );
      final response = await source.request();
      expect(factories, 0);
      expect(client.requests, isEmpty);
      expect(response.sourceLength, 10);
      expect(response.contentLength, 10);
      expect(response.offset, 0);
      expect(response.contentType, 'audio/mp4');
      expect(
        await response.stream.expand((e) => e).toList(),
        List.generate(10, (i) => i),
      );
      expect(client.requests.map((r) => r.headers['Range']), [
        'bytes=0-3',
        'bytes=4-7',
        'bytes=8-9',
      ]);
      expect(client.closes, 1);
    },
  );

  test('native seek honors inclusive start and exclusive end', () async {
    final client = _Client((r) async => _correct(r));
    final source = GoogleVideoByteSource(
      _uri,
      sourceLength: 10,
      chunkSize: 4,
      clientFactory: () => client,
    );
    final response = await source.request(5, 9);
    expect(response.offset, 5);
    expect(response.contentLength, 4);
    expect(await response.stream.expand((e) => e).toList(), [5, 6, 7, 8]);
    expect(client.requests.single.headers['Range'], 'bytes=5-8');
    expect(client.closes, 1);
  });

  test('requested end beyond media is clamped without an open range', () async {
    final client = _Client((r) async => _correct(r));
    final source = GoogleVideoByteSource(
      _uri,
      sourceLength: 10,
      clientFactory: () => client,
    );
    final response = await source.request(8, 99);
    expect(await response.stream.expand((e) => e).toList(), [8, 9]);
    expect(response.contentLength, 2);
    expect(client.requests.single.headers['Range'], 'bytes=8-9');
  });

  test('invalid native ranges fail without fetching', () async {
    final source = GoogleVideoByteSource(_uri, sourceLength: 10);
    for (final range in [
      [-1, 2],
      [10, 11],
      [4, 4],
      [5, 3],
    ]) {
      await expectLater(source.request(range[0], range[1]), throwsRangeError);
    }
  });

  for (final status in [200, 302, 401, 403, 429, 500]) {
    test(
      'HTTP $status rejected without redirect, auth fallback or body read',
      () async {
        var listened = false;
        final body = StreamController<List<int>>(
          onListen: () => listened = true,
        );
        final client = _Client(
          (_) async => http.StreamedResponse(body.stream, status),
        );
        final source = GoogleVideoByteSource(
          _uri,
          sourceLength: 10,
          clientFactory: () => client,
        );
        await expectLater(
          (await source.request()).stream.drain<void>(),
          throwsStateError,
        );
        expect(listened, isFalse);
        expect(client.closes, 1);
        expect(client.requests.length, 1);
        unawaited(body.close());
      },
    );
  }

  for (final header in ['bytes 1-9/10', 'bytes 0-9/11', 'bytes 0-10/10']) {
    test('mismatched Content-Range $header rejected', () async {
      final client = _Client(
        (_) async => http.StreamedResponse(
          const Stream.empty(),
          206,
          headers: {'content-range': header},
        ),
      );
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        clientFactory: () => client,
      );
      await expectLater(
        (await source.request()).stream.drain<void>(),
        throwsStateError,
      );
      expect(client.closes, 1);
    });
  }

  for (final bytes in [9, 11]) {
    test(
      'truncated or oversized body ($bytes bytes) closes without another request',
      () async {
        final client = _Client(
          (_) async => http.StreamedResponse(
            Stream.value(List.filled(bytes, 0)),
            206,
            headers: {'content-range': 'bytes 0-9/10'},
          ),
        );
        final source = GoogleVideoByteSource(
          _uri,
          sourceLength: 10,
          clientFactory: () => client,
        );
        await expectLater(
          (await source.request()).stream.drain<void>(),
          throwsStateError,
        );
        expect(client.closes, 1);
        expect(client.requests.length, 1);
      },
    );
  }

  test('header timeout closes the request', () async {
    final pending = Completer<http.StreamedResponse>();
    final client = _Client((_) => pending.future);
    final source = GoogleVideoByteSource(
      _uri,
      sourceLength: 10,
      clientFactory: () => client,
      timeout: const Duration(milliseconds: 15),
    );
    await expectLater(
      (await source.request()).stream.drain<void>(),
      throwsA(
        isA<AudioTransportFailure>().having(
          (e) => e.cause,
          'originating cause',
          isA<TimeoutException>(),
        ),
      ),
    );
    expect(client.closes, 1);
  });

  test('stalled body times out and cancels upstream', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    final client = _Client(
      (_) async => http.StreamedResponse(
        body.stream,
        206,
        headers: {'content-range': 'bytes 0-9/10'},
      ),
    );
    final source = GoogleVideoByteSource(
      _uri,
      sourceLength: 10,
      clientFactory: () => client,
      timeout: const Duration(milliseconds: 15),
    );
    await expectLater(
      (await source.request()).stream.drain<void>(),
      throwsA(
        isA<AudioTransportFailure>().having(
          (e) => e.cause,
          'originating cause',
          isA<TimeoutException>(),
        ),
      ),
    );
    expect(cancelled, isTrue);
    expect(client.closes, 1);
    unawaited(body.close());
  });

  test('native cancellation closes pending headers immediately', () async {
    final pending = Completer<http.StreamedResponse>();
    final started = Completer<void>();
    final client = _Client((_) {
      started.complete();
      return pending.future;
    }, onClose: () => pending.completeError(StateError('cancelled')));
    final source = GoogleVideoByteSource(
      _uri,
      sourceLength: 10,
      clientFactory: () => client,
    );
    final subscription = (await source.request()).stream.listen(
      (_) {},
      onError: (Object _) {},
    );
    await started.future;
    await subscription.cancel();
    expect(client.closes, 1);
    expect(client.requests.length, 1);
  });

  test('native early cancellation fetches no following chunk', () async {
    final client = _Client((r) async => _correct(r));
    final source = GoogleVideoByteSource(
      _uri,
      sourceLength: 10,
      chunkSize: 4,
      clientFactory: () => client,
    );
    await (await source.request()).stream.take(1).drain<void>();
    expect(client.requests.length, 1);
    expect(client.closes, 1);
  });

  test(
    'a later denied range permanently fails this source without upstream retry',
    () async {
      final client = _Client((request) async {
        if (request.headers['Range'] == 'bytes=0-3') return _correct(request);
        return http.StreamedResponse(const Stream.empty(), 403);
      });
      var factories = 0;
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        chunkSize: 4,
        clientFactory: () {
          factories++;
          return client;
        },
      );
      final received = <int>[];
      await expectLater(
        (await source.request()).stream.map((bytes) {
          received.addAll(bytes);
          return bytes;
        }).drain<void>(),
        throwsStateError,
      );
      expect(received, [0, 1, 2, 3]);
      expect(client.requests.length, 2);
      await expectLater(source.request(4), throwsStateError);
      await expectLater(source.request(), throwsStateError);
      expect(client.requests.length, 2);
      expect(factories, 1);
      expect(client.closes, 1);
    },
  );

  test(
    'four active reads bound concurrency and cancellation releases a slot',
    () async {
      final clients = <_Client>[];
      final started = <Completer<void>>[];
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        clientFactory: () {
          final pending = Completer<http.StreamedResponse>();
          final ready = Completer<void>();
          started.add(ready);
          final client = _Client((_) {
            ready.complete();
            return pending.future;
          }, onClose: () => pending.completeError(StateError('cancelled')));
          clients.add(client);
          return client;
        },
      );
      final subscriptions = <StreamSubscription<List<int>>>[];
      for (var i = 0; i < 4; i++) {
        subscriptions.add(
          (await source.request()).stream.listen(
            (_) {},
            onError: (Object _) {},
          ),
        );
        await started[i].future;
      }
      await expectLater(
        (await source.request()).stream.drain<void>(),
        throwsStateError,
      );
      expect(clients.length, 4);
      await subscriptions.first.cancel();
      subscriptions.add(
        (await source.request()).stream.listen((_) {}, onError: (Object _) {}),
      );
      await started.last.future;
      expect(clients.length, 5);
      for (final subscription in subscriptions.skip(1)) {
        await subscription.cancel();
      }
      expect(clients.every((client) => client.closes == 1), isTrue);
    },
  );

  test('pause provides backpressure until native consumer resumes', () async {
    final client = _Client((r) async => _correct(r));
    final source = GoogleVideoByteSource(
      _uri,
      sourceLength: 10,
      chunkSize: 4,
      clientFactory: () => client,
    );
    final received = <int>[];
    final first = Completer<void>();
    final done = Completer<void>();
    late StreamSubscription<List<int>> sub;
    sub = (await source.request()).stream.listen((bytes) {
      received.addAll(bytes);
      if (!first.isCompleted) {
        sub.pause();
        first.complete();
      }
    }, onDone: done.complete);
    await first.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(client.requests.length, 1);
    sub.resume();
    await done.future;
    expect(received, List.generate(10, (i) => i));
    expect(client.closes, 1);
  });

  test(
    'explicit source cancellation closes all pending reads without a failure callback',
    () async {
      var failures = 0;
      final clients = <_Client>[];
      final started = <Completer<void>>[];
      final source = GoogleVideoByteSource(
        _uri,
        sourceLength: 10,
        onUnavailable: () => failures++,
        clientFactory: () {
          final pending = Completer<http.StreamedResponse>();
          final ready = Completer<void>();
          started.add(ready);
          final client = _Client((_) {
            ready.complete();
            return pending.future;
          }, onClose: () => pending.completeError(StateError('cancelled')));
          clients.add(client);
          return client;
        },
      );
      for (var i = 0; i < 2; i++) {
        (await source.request()).stream.listen((_) {}, onError: (Object _) {});
        await started[i].future;
      }
      await source.cancelRequests().timeout(const Duration(milliseconds: 200));
      expect(clients.every((client) => client.closes == 1), isTrue);
      expect(failures, 0);
      await expectLater(source.request(), throwsStateError);
      expect(clients.length, 2);
    },
  );

  test(
    'transport rejects external HTTP, lookalike hosts, invalid lengths and ports',
    () {
      for (final url in [
        'http://r1.googlevideo.com/v?clen=10',
        'https://googlevideo.com.attacker.test/v?clen=10',
        'https://r1.googlevideo.com:444/v?clen=10',
        'https://r1.googlevideo.com/v?clen=0',
        'https://r1.googlevideo.com/v',
        'https://r1.googlevideo.com/v?clen=2147483649',
      ]) {
        expect(
          onlineAudioSource(url, enableBoundedTransport: true),
          isA<UriAudioSource>(),
        );
      }
      expect(
        onlineAudioSource(_uri.toString(), enableBoundedTransport: false),
        isA<UriAudioSource>(),
      );
      expect(
        onlineAudioSource(_uri.toString(), enableBoundedTransport: true),
        isA<GoogleVideoByteSource>(),
      );
    },
  );

  test('only GitHub flavor declares the exact IPv4 loopback exception', () {
    final config = File(
      'android/app/src/github/res/xml/network_security_config.xml',
    ).readAsStringSync();
    expect(
      config,
      contains('<base-config cleartextTrafficPermitted="false" />'),
    );
    expect(RegExp(r'<domain(?:\s|>)').allMatches(config).length, 1);
    expect(
      config,
      contains('<domain includeSubdomains="false">127.0.0.1</domain>'),
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      isNot(contains('networkSecurityConfig')),
    );
    expect(
      File('android/app/src/github/AndroidManifest.xml').readAsStringSync(),
      contains('@xml/network_security_config'),
    );
    expect(
      File(
        'android/app/src/fdroid/res/xml/network_security_config.xml',
      ).existsSync(),
      isFalse,
    );
  });
}
