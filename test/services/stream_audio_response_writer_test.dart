import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/src/stream_audio_response_writer.dart';

void main() {
  test('complete loopback bytes retain declared length and finish', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final finished = Completer<void>();
    server.listen((request) async {
      request.response.contentLength = 4;
      await writeStreamAudioResponse(
        Stream.value([1, 2, 3, 4]),
        request.response,
      );
      finished.complete();
    });
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(
        Uri.http('127.0.0.1:${server.port}', '/fixture'),
      )).close();
      final bytes = await response.expand((bytes) => bytes).toList();
      expect(response.contentLength, 4);
      expect(bytes, [1, 2, 3, 4]);
      await finished.future.timeout(const Duration(seconds: 2));
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });

  test(
    'truncated stream fails native HTTP and consumes both close futures',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final finished = Completer<void>();
      var cancelled = false;
      server.listen((request) async {
        request.response.contentLength = 10;
        late final StreamController<List<int>> stream;
        stream = StreamController(
          onListen: () {
            stream.add([1, 2, 3]);
            stream.addError(StateError('fixture source failed'));
          },
          onCancel: () => cancelled = true,
        );
        await writeStreamAudioResponse(stream.stream, request.response);
        finished.complete();
      });
      final client = HttpClient();
      try {
        await expectLater(() async {
          final response = await (await client.getUrl(
            Uri.http('127.0.0.1:${server.port}', '/fixture'),
          )).close();
          await response.drain<void>();
        }(), throwsA(isA<HttpException>()));
        await finished.future.timeout(const Duration(seconds: 2));
        expect(cancelled, isTrue);
      } finally {
        client.close(force: true);
        await server.close(force: true);
      }
    },
  );

  test(
    'disconnected native read cancels its producing stream promptly',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final finished = Completer<void>();
      final cancelled = Completer<void>();
      server.listen((request) async {
        request.response.contentLength = 10000000;
        final stream = Stream<List<int>>.periodic(
          const Duration(milliseconds: 10),
          (_) => List.filled(8192, 0),
        );
        final controlled = stream.asBroadcastStream(
          onCancel: (sub) {
            sub.cancel();
            cancelled.complete();
          },
        );
        await writeStreamAudioResponse(controlled, request.response);
        finished.complete();
      });
      final client = HttpClient();
      try {
        final response = await (await client.getUrl(
          Uri.http('127.0.0.1:${server.port}', '/fixture'),
        )).close();
        await response.take(1).drain<void>();
        client.close(force: true);
        await cancelled.future.timeout(const Duration(seconds: 2));
        await finished.future.timeout(const Duration(seconds: 2));
      } finally {
        client.close(force: true);
        await server.close(force: true);
      }
    },
  );
}
