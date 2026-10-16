import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test(
    'unknown-length format HEAD403 is terminal before any media GET',
    () async {
      final methods = <String>[];
      final client = YoutubeExplode(
        httpClient: YoutubeHttpClient(
          MockClient((request) async {
            methods.add(request.method);
            if (request.method == 'POST') {
              return http.Response(
                jsonEncode({
                  'playabilityStatus': {'status': 'OK'},
                  'videoDetails': {
                    'videoId': 'abcdefghijk',
                    'lengthSeconds': '120',
                  },
                  'streamingData': {
                    'formats': [
                      {
                        'itag': 18,
                        'url': 'https://example.googlevideo.com/videoplayback',
                        'mimeType':
                            'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
                        'bitrate': 500000,
                        'width': 640,
                        'height': 360,
                        'qualityLabel': '360p',
                        'fps': 30,
                      },
                    ],
                  },
                }),
                200,
                request: request,
              );
            }
            if (request.method == 'HEAD') {
              return http.Response(
                'Forbidden',
                403,
                headers: {'content-length': '9'},
                request: request,
              );
            }
            return http.Response(
              'x',
              206,
              headers: {'content-range': 'bytes 0-0/100'},
              request: request,
            );
          }),
        ),
      );
      try {
        await expectLater(
          client.videos.streams.getManifest(
            'abcdefghijk',
            ytClients: [YoutubeApiClient.androidSdkless],
            requireWatchPage: false,
            streamForValidation: (streams) => streams.first,
          ),
          throwsA(
            isA<FatalFailureException>().having(
              (error) => error.statusCode,
              'status',
              403,
            ),
          ),
        );
        expect(methods, ['POST', 'HEAD']);
      } finally {
        client.close();
      }
    },
  );

  test('success HEAD length stays usable with validate false', () async {
    final client = YoutubeHttpClient(
      MockClient(
        (request) async => http.Response(
          '',
          200,
          headers: {'content-length': '100'},
          request: request,
        ),
      ),
    );
    try {
      expect(
        await client.getContentLength(
          Uri.parse('https://example.googlevideo.com/videoplayback'),
          validate: false,
        ),
        100,
      );
    } finally {
      client.close();
    }
  });

  test('redirect response body length is not a media length', () async {
    final client = YoutubeHttpClient(
      MockClient(
        (request) async => http.Response(
          'Moved',
          302,
          headers: {'content-length': '5'},
          request: request,
        ),
      ),
    );
    try {
      expect(
        await client.getContentLength(
          Uri.parse('https://example.googlevideo.com/videoplayback'),
          validate: false,
        ),
        isNull,
      );
    } finally {
      client.close();
    }
  });
}
