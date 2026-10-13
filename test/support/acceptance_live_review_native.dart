// Approved source/context input remains outside Git. Real review UI/backend.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/screens/spotify_review_sprint_page.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/review_sprint_audio_player.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/stream_request_context.dart';

import 'acceptance_mini_shell_native.dart';

Future<void> main() async {
  await runOwnedShellRehearsal(
    namespace: 'acceptance_live_review_v1',
    mountApp: false,
    bootstrapQueue: false,
  );
  final input = Map<String, dynamic>.from(
    jsonDecode(
          await File(
            '$applicationDirPath/authorized-input.json',
          ).readAsString(),
        )
        as Map,
  );
  final id = input['videoId'] as String;
  final url = input['url'] as String;
  if (!streamRequestContexts.restore(url, input['requestContext'])) {
    throw StateError('Invalid approved media provenance');
  }
  if (streamRequestContexts.lengthForUrl(url) != input['bytes']) {
    throw StateError('Approved source length changed');
  }
  final date = DateTime.parse(input['cacheDateUtc'] as String);
  if (DateTime.now().difference(date) > const Duration(hours: 1)) {
    throw StateError('Approved validation too old; do not re-resolve');
  }
  final key = 'song_${id}_muxed_high_url';
  await Hive.box('cache').putAll({
    key: url,
    '${key}_date': date,
    '${key}_requestContext': input['requestContext'],
  });
  await Hive.box('settings').putAll({
    'offlineMode': false,
    'audioQuality': 'high',
    'shouldWeCheckUpdates': false,
    'externalRecommendations': false,
  });
  offlineMode.value = false;
  audioQualitySetting.value = 'high';
  final rows = [
    for (var row = 1; row <= 3; row++)
      <String, dynamic>{
        'sourceRow': row,
        'sourceTitle': 'Bounded review row $row',
        'sourceArtist': 'Owned review artist',
        'sourceAlbum': 'Owned review album',
        'sourceIsrc': 'OWNEDLIVE$row',
        'status': 'needs_review',
        'alternatives': [
          {
            'score': 0.82,
            'candidate': {
              'ytid': id,
              'title': 'Approved preview recording',
              'artist': 'Owned preview fixture',
              'duration': input['durationSeconds'],
              'sourceType': 'youtube',
            },
            'evidence': {'titleScore': 1.0, 'primaryArtistScore': 0.95},
          },
        ],
      },
  ];
  await Hive.box('user').putAll({
    'spotifyImportMetadata': {
      'importSessionId': 'owned-live-review-session',
      'fileName': 'owned-live-review.csv',
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
  await Hive.box('user').flush();
  final player = AudioPlayer(useProxyForRequestHeaders: false);
  await player.setVolume(0);
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Bounded real review acceptance')),
        body: SpotifyReviewSprintPage(
          audioPlayer: ObservedReviewPlayer(player, url),
        ),
      ),
    ),
  );
}

class ObservedReviewPlayer implements ReviewSprintAudioPlayer {
  ObservedReviewPlayer(this.native, this.approvedUrl)
    : delegate = JustAudioReviewSprintPlayer(player: native);
  final AudioPlayer native;
  final String approvedUrl;
  final JustAudioReviewSprintPlayer delegate;
  final events = <Map<String, Object?>>[];
  int loads = 0;
  Stopwatch? elapsed;
  Future<void> pending = Future.value();
  Future<void> record(String event) async {
    events.add({
      'event': event,
      'loads': loads,
      'positionMs': native.position.inMilliseconds,
      'elapsedMs': elapsed?.elapsedMilliseconds,
      'playing': native.playing,
      'state': native.processingState.name,
    });
    if (events.length > 64) throw StateError('Bounded trace cap');
    final encoded = jsonEncode({
      'sourceSha': const String.fromEnvironment('GIT_SHA'),
      'sourceUriSha256': sha256.convert(utf8.encode(approvedUrl)).toString(),
      'physicalOutputVerified': false,
      'events': events,
    });
    pending = pending.then((_) async {
      await File(
        '$applicationDirPath/live-review-proof.json',
      ).writeAsString(encoded, flush: true);
    });
    await pending;
  }

  @override
  Stream<ReviewSprintAudioState> get stateStream => delegate.stateStream;
  @override
  Future<void> setUrl(String url) async {
    if (url != approvedUrl || ++loads > 4)
      throw StateError('Unapproved source/repeat');
    await record('load-start');
    await delegate.setUrl(url);
    await record('load-ready');
  }

  @override
  Future<void> play() async {
    elapsed = Stopwatch()..start();
    await record('play-start');
    await delegate.play();
    await record('play-return');
  }

  @override
  Future<void> pause() => delegate.pause();
  @override
  Future<void> stop() async {
    await delegate.stop();
    await record('stop');
  }

  @override
  Future<void> seek(Duration position) => delegate.seek(position);
  @override
  Future<void> dispose() => delegate.dispose();
}
