// Real review decisions/swipes with isolated Hive and owned file previews.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_review_sprint_page.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/review_sprint_audio_player.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';
import 'acceptance_mini_shell_native.dart';

Future<void> main() async {
  await runOwnedShellRehearsal(namespace: 'acceptance_review_gestures_v2');
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
      'namespace': 'acceptance_review_gestures_v2',
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
          dataSource: const OwnedTracingReviewSource(),
          audioPlayer: OwnedTracingReviewPlayer(),
          streamResolver: (_) async =>
              Uri.file('$applicationDirPath/owned-mini-8.wav').toString(),
        ),
      ),
    ),
  );
}

void traceOwnedReview(String event, [Object? detail]) => debugPrint(
  'OwnedReviewTrace ${jsonEncode({'event': event, 'detail': detail})}',
);

class OwnedTracingReviewSource implements SpotifyReviewSprintDataSource {
  const OwnedTracingReviewSource();
  static const delegate = SpotifyReviewWorkflowService();
  @override
  Future<List<Map<String, dynamic>>> loadUnresolvedItems() =>
      delegate.loadUnresolvedItems();
  @override
  Future<SpotifyResolutionResult> resolveItem({
    required Map<String, dynamic> item,
    required bool accept,
    Map<String, dynamic>? selectedAlternative,
  }) async {
    traceOwnedReview('resolve-start', {
      'row': item['sourceRow'],
      'accept': accept,
    });
    try {
      final result = await delegate.resolveItem(
        item: item,
        accept: accept,
        selectedAlternative: selectedAlternative,
      );
      traceOwnedReview('resolve-end');
      return result;
    } catch (error) {
      traceOwnedReview('resolve-error', error.toString());
      rethrow;
    }
  }

  @override
  Future<SpotifyResolutionResult> excludeItem({
    required Map<String, dynamic> item,
  }) => delegate.excludeItem(item: item);
  @override
  Future<int> bulkApproveCluster({
    required String key,
    required String importSessionId,
  }) => delegate.bulkApproveCluster(key: key, importSessionId: importSessionId);
}

class OwnedTracingReviewPlayer implements ReviewSprintAudioPlayer {
  final delegate = JustAudioReviewSprintPlayer();
  @override
  Stream<ReviewSprintAudioState> get stateStream =>
      delegate.stateStream.map((state) {
        traceOwnedReview('state', {
          'playing': state.playing,
          'completed': state.completed,
        });
        return state;
      });
  @override
  Future<void> setUrl(String url) async {
    traceOwnedReview('load-start');
    await delegate.setUrl(url);
    traceOwnedReview('load-end');
  }

  @override
  Future<void> play() async {
    traceOwnedReview('play-start');
    await delegate.play();
    traceOwnedReview('play-end');
  }

  @override
  Future<void> pause() => delegate.pause();
  @override
  Future<void> stop() async {
    traceOwnedReview('stop-start');
    await delegate.stop();
    traceOwnedReview('stop-end');
  }

  @override
  Future<void> seek(Duration position) => delegate.seek(position);
  @override
  Future<void> dispose() => delegate.dispose();
}
