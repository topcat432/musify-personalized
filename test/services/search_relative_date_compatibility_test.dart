import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_explode_dart/src/extensions/helpers_extension.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Map<String, Object> _video(String id, String date) => {
  'videoRenderer': {
    'videoId': id,
    'title': {
      'runs': [
        {'text': 'Owned search fixture $id'},
      ],
    },
    'ownerText': {
      'runs': [
        {
          'text': 'Owned fixture artist',
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': 'UCabcdefghijklmnopqrstuv'},
          },
        },
      ],
    },
    'publishedTimeText': {'simpleText': date},
    'viewCountText': {'simpleText': '123 views'},
    'lengthText': {'simpleText': '3:00'},
    'thumbnail': {'thumbnails': <Object>[]},
  },
};

void main() {
  test('compact streamed date stays unknown without throwing', () {
    expect('Streamed 3mo ago'.toDateTime(), isNull);
  });

  test('known prefixes retain ordinary relative dates', () {
    for (final prefix in ['Streamed', 'Premiered', 'Updated']) {
      final before = DateTime.now().subtract(const Duration(days: 60));
      final parsed = '$prefix 2 months ago'.toDateTime();
      final after = DateTime.now().subtract(const Duration(days: 60));
      expect(parsed, isNotNull);
      expect(parsed!.isBefore(before), isFalse);
      expect(parsed.isAfter(after), isFalse);
    }
  });

  test('unknown quantity does not manufacture an upload date', () {
    expect('many months ago'.toDateTime(), isNull);
    expect('Streamed recently'.toDateTime(), isNull);
    expect(''.toDateTime(), isNull);
    expect((null as String?).toDateTime(), isNull);
  });

  test('one compact date does not discard the full search result', () async {
    final data = {
      'estimatedResults': '2',
      'contents': {
        'twoColumnSearchResultsRenderer': {
          'primaryContents': {
            'sectionListRenderer': {
              'contents': [
                {
                  'itemSectionRenderer': {
                    'contents': [
                      _video('fixture1234', 'Streamed 3mo ago'),
                      _video('fixture5678', '2 years ago'),
                    ],
                  },
                },
              ],
            },
          },
        },
      },
    };
    final requests = <http.Request>[];
    final yt = YoutubeExplode(
      httpClient: YoutubeHttpClient(
        MockClient((request) async {
          requests.add(request);
          expect(request.method, 'GET');
          expect(request.url.path, '/results');
          return http.Response(
            '<html><script>var ytInitialData = ${jsonEncode(data)};</script></html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
            request: request,
          );
        }),
      ),
    );
    try {
      final results = await yt.search.search('Owned search fixture');
      expect(results.map((video) => video.id.value), [
        'fixture1234',
        'fixture5678',
      ]);
      expect(results.first.uploadDate, isNull);
      expect(results.last.uploadDate, isNotNull);
      expect(results.first.title, 'Owned search fixture fixture1234');
      expect(results.first.author, 'Owned fixture artist');
      expect(results.first.duration, const Duration(minutes: 3));
      expect(requests, hasLength(1));
    } finally {
      yt.close();
    }
  });
}
