// Real review decisions/swipes with isolated Hive and owned file previews.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_review_sprint_page.dart';
import 'package:musify/services/io_service.dart';
import 'acceptance_mini_shell_native.dart';

Future<void> main() async {
  await runOwnedShellRehearsal(namespace: 'acceptance_review_gestures_v1');
  final box = Hive.box('user');
  if (!box.containsKey('ownedReviewSeeded')) {
    final rows = [
      for (var row = 1; row <= 3; row++)
        <String, dynamic>{
          'sourceRow': row,
          'sourceTitle': 'Owned review row $row',
          'sourceArtist': 'Owned artist $row',
          'sourceAlbum': 'Owned album',
          'sourceIsrc': 'OWNEDREVIEW$row',
          'status': 'needs_review',
          'alternatives': [
            {
              'score': 0.82,
              'candidate': {
                'ytid': 'owned-review-$row',
                'title': 'Owned candidate $row',
                'artist': 'Owned artist $row',
                'album': 'Owned album',
                'duration': 8,
                'sourceType': 'owned_fixture',
              },
              'evidence': {
                'titleScore': 1.0,
                'primaryArtistScore': 0.95,
                'reasons': ['Owned identity fixture'],
              },
            },
          ],
        },
    ];
    await box.putAll({
      'ownedReviewSeeded': true,
      'spotifyImportMetadata': {
        'importSessionId': 'owned-review-session',
        'fileName': 'owned-review.csv',
        'matchingStatus': 'complete',
        'totalTracks': 3,
        'nextTrackIndex': 3,
      },
      'spotifyImportTracks': [
        for (final row in rows)
          {
            'sourceRow': row['sourceRow'],
            'title': row['sourceTitle'],
            'artist': row['sourceArtist'],
            'album': row['sourceAlbum'],
            'isrc': row['sourceIsrc'],
          },
      ],
      'spotifyMatchResults': rows,
      'spotifyExcludedImportRows': <String>[],
    });
    await box.flush();
  }
  await File('$applicationDirPath/review-native-source.json').writeAsString(
    jsonEncode({
      'sourceSha': const String.fromEnvironment('GIT_SHA'),
      'namespace': 'acceptance_review_gestures_v1',
      'localPreviewOnly': true,
      'providerRequested': false,
    }),
    flush: true,
  );
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Owned review gestures')),
        body: SpotifyReviewSprintPage(
          streamResolver: (_) async =>
              Uri.file('$applicationDirPath/owned-mini-8.wav').toString(),
        ),
      ),
    ),
  );
}
