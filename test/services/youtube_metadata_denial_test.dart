import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musify/services/shared_song_metadata.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  for (final sorryRedirect in [false, true]) {
    test(
      'watch metadata stops after ${sorryRedirect ? 'Google sorry response' : 'HTTP 429'}',
      () async {
        final requests = <http.Request>[];
        final client = YoutubeExplode(
          httpClient: YoutubeHttpClient(
            MockClient((request) async {
              requests.add(request);
              return http.Response(
                'synthetic denied response',
                sorryRedirect ? 200 : 429,
                headers: {'retry-after': '120'},
                request: sorryRedirect
                    ? http.Request(
                        'GET',
                        Uri.parse('https://www.google.com/sorry/index'),
                      )
                    : request,
              );
            }),
          ),
        );
        addTearDown(client.close);

        await expectLater(
          client.videos.get('fixture1234'),
          throwsA(
            isA<RequestLimitExceededException>()
                .having(
                  (error) => error.statusCode,
                  'status',
                  sorryRedirect ? 200 : 429,
                )
                .having((error) => error.retryAfter, 'Retry-After', '120')
                .having(
                  (error) => error.googleSorry,
                  'sorry response',
                  sorryRedirect,
                ),
          ),
        );
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/watch');
      },
    );
  }

  test(
    'denial diagnostics omit request queries, bodies and invalid headers',
    () {
      final error = RequestLimitExceededException.httpRequest(
        http.Response(
          'private body',
          429,
          headers: {'retry-after': 'secret=private'},
          request: http.Request(
            'GET',
            Uri.parse('https://example.test/watch?key=private'),
          ),
        ),
      );
      expect(error.retryAfter, isNull);
      expect(error.toString(), isNot(contains('private')));
      final diagnostic = sharedSongFailureDiagnostic(error);
      expect(diagnostic, contains('phase=shared-song-resolution'));
      expect(diagnostic, contains('status=429'));
      expect(diagnostic, isNot(contains('private')));
      final date = 'Wed, 21 Oct 2026 07:28:00 GMT';
      final dated = RequestLimitExceededException.httpRequest(
        http.Response('', 429, headers: {'retry-after': date}),
      );
      expect(dated.retryAfter, date);
    },
  );

  test('manifest rate limit does not fall through to another client', () async {
    var requests = 0;
    final client = YoutubeExplode(
      httpClient: YoutubeHttpClient(
        MockClient((request) async {
          requests++;
          return http.Response('', 429, request: request);
        }),
      ),
    );
    addTearDown(client.close);
    await expectLater(
      client.videos.streams.getManifest(
        'fixture1234',
        requireWatchPage: false,
        ytClients: [
          YoutubeApiClient.androidSdkless,
          YoutubeApiClient.androidVr,
        ],
      ),
      throwsA(isA<RequestLimitExceededException>()),
    );
    expect(requests, 1);
  });

  test(
    'watch metadata retries a transient response then stops at denial',
    () async {
      final statuses = <int>[];
      final client = YoutubeExplode(
        httpClient: YoutubeHttpClient(
          MockClient((request) async {
            final status = statuses.isEmpty ? 503 : 403;
            statuses.add(status);
            return http.Response(
              'synthetic response',
              status,
              request: request,
            );
          }),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.videos.get('fixture1234'),
        throwsA(isA<FatalFailureException>()),
      );
      expect(statuses, [503, 403]);
    },
  );
}
