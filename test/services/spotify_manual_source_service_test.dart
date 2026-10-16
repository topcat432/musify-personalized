import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:musify/services/spotify_manual_source_service.dart';

void main() {
  final metadata = <String, dynamic>{
    'type': 'video',
    'provider_name': 'YouTube',
    'title': 'Fleetwood Mac - Dreams (Official Audio)',
    'author_name': 'Fleetwood Mac',
    'thumbnail_url': 'https://i.ytimg.com/vi/PgagPdVM7bk/hqdefault.jpg',
    'html': '<iframe>ignored</iframe>',
  };
  test(
    'exact public metadata preserves video identity without stream URLs or invented duration',
    () async {
      final client = _MetadataClient((request) async {
        expect(request.url.host, 'www.youtube.com');
        expect(request.url.path, '/oembed');
        expect(
          request.url.queryParameters['url'],
          'https://www.youtube.com/watch?v=PgagPdVM7bk',
        );
        expect(request.headers, isEmpty);
        expect(request.followRedirects, isFalse);
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(metadata))),
          200,
        );
      });
      final song = await SpotifyManualSourceService(clientFactory: () => client)
          .loadExactVideo(
            'https://music.youtube.com/watch?v=PgagPdVM7bk&list=ignored',
          );
      expect(song['ytid'], 'PgagPdVM7bk');
      expect(song['title'], 'Dreams');
      expect(song['artist'], 'Fleetwood Mac');
      expect(song['duration'], isNull);
      expect(song.containsKey('html'), isFalse);
      expect(client.closed, isTrue);
    },
  );
  for (final status in [302, 401, 403, 404]) {
    test(
      'metadata HTTP $status fails without fallback or reading denied body',
      () async {
        var listened = false;
        final body = StreamController<List<int>>(
          onListen: () => listened = true,
        );
        final client = _MetadataClient(
          (_) async => http.StreamedResponse(body.stream, status),
        );
        await expectLater(
          SpotifyManualSourceService(
            clientFactory: () => client,
          ).loadExactVideo('PgagPdVM7bk'),
          throwsStateError,
        );
        expect(client.requests, 1);
        expect(client.closed, isTrue);
        expect(listened, isFalse);
        unawaited(body.close());
      },
    );
  }
  test('oversized metadata is rejected and client closed', () async {
    final client = _MetadataClient(
      (_) async =>
          http.StreamedResponse(Stream.value(List.filled(65537, 32)), 200),
    );
    await expectLater(
      SpotifyManualSourceService(
        clientFactory: () => client,
      ).loadExactVideo('PgagPdVM7bk'),
      throwsFormatException,
    );
    expect(client.closed, isTrue);
  });
  test('metadata timeout closes pending request', () async {
    final client = _MetadataClient(
      (_) => Completer<http.StreamedResponse>().future,
    );
    await expectLater(
      SpotifyManualSourceService(
        clientFactory: () => client,
        timeout: const Duration(milliseconds: 15),
      ).loadExactVideo('PgagPdVM7bk'),
      throwsA(isA<TimeoutException>()),
    );
    expect(client.closed, isTrue);
  });
  group('SpotifyManualSourceService exact video parsing', () {
    test('parses ordinary YouTube links', () {
      expect(
        SpotifyManualSourceService.parseExactVideoId(
          'https://www.youtube.com/watch?v=yIVRs6YSbOM',
        ),
        'yIVRs6YSbOM',
      );
      expect(
        SpotifyManualSourceService.parseExactVideoId(
          'https://youtu.be/yIVRs6YSbOM?si=example',
        ),
        'yIVRs6YSbOM',
      );
    });

    test('parses YouTube Music links without keeping playlist parameters', () {
      expect(
        SpotifyManualSourceService.parseExactVideoId(
          'https://music.youtube.com/watch?v=yIVRs6YSbOM&list=OLAK5uy_test',
        ),
        'yIVRs6YSbOM',
      );
    });

    test('accepts a raw video id and rejects search text', () {
      expect(
        SpotifyManualSourceService.parseExactVideoId('yIVRs6YSbOM'),
        'yIVRs6YSbOM',
      );
      expect(
        SpotifyManualSourceService.parseExactVideoId('artist song title'),
        isNull,
      );
    });
  });
}

class _MetadataClient extends http.BaseClient {
  _MetadataClient(this.respond);
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  bool closed = false;
  int requests = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    return respond(request);
  }

  @override
  void close() {
    closed = true;
  }
}
