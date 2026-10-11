import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:musify/services/stream_url_validation.dart';

class ProbeClient extends http.BaseClient {
  ProbeClient(this.respond);
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      respond(request);

  @override
  void close() => closed = true;
}

void main() {
  test('accepts partial media GET where HEAD would be rejected', () async {
    final client = ProbeClient((request) async {
      if (request.method == 'HEAD') {
        return http.StreamedResponse(const Stream.empty(), 403);
      }
      expect(request.headers['Range'], 'bytes=0-0');
      return http.StreamedResponse(const Stream.empty(), 206);
    });
    expect(
      await validateStreamUrl('https://media.example/audio', client: client),
      isTrue,
    );
    expect(client.closed, isTrue);
  });

  test(
    'closes after headers without consuming an ignored-Range body',
    () async {
      var listened = false;
      final body = StreamController<List<int>>(onListen: () => listened = true);
      final client = ProbeClient(
        (_) async => http.StreamedResponse(body.stream, 200),
      );
      expect(
        await validateStreamUrl('https://media.example/audio', client: client),
        isTrue,
      );
      expect(listened, isFalse);
      expect(client.closed, isTrue);
      unawaited(body.close());
    },
  );

  for (final status in [401, 403, 404, 429, 500]) {
    test('rejects HTTP $status and closes the request', () async {
      final client = ProbeClient(
        (_) async => http.StreamedResponse(const Stream.empty(), status),
      );
      expect(
        await validateStreamUrl('https://media.example/audio', client: client),
        isFalse,
      );
      expect(client.closed, isTrue);
    });
  }

  test('bounds stalled validation and closes its client', () async {
    final stalled = Completer<http.StreamedResponse>();
    final client = ProbeClient((_) => stalled.future);
    expect(
      await validateStreamUrl(
        'https://media.example/audio',
        client: client,
        timeout: const Duration(milliseconds: 10),
      ),
      isFalse,
    );
    expect(client.closed, isTrue);
  });

  test('rejects request exceptions and closes its client', () async {
    final client = ProbeClient(
      (_) async => throw http.ClientException('unavailable'),
    );
    expect(
      await validateStreamUrl('https://media.example/audio', client: client),
      isFalse,
    );
    expect(client.closed, isTrue);
  });
}
