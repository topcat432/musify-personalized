// Isolated synthetic metadata; controlled lookups never contact any provider.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_track_matching_service.dart';

import 'acceptance_mini_shell_native.dart';

const _idA = 'AbCdEfGhIjKlMnOpQrStUv';
const _idB = 'ZbCdEfGhIjKlMnOpQrStUv';

Future<void> main() async {
  await runOwnedShellRehearsal(
    namespace: 'acceptance_spotify_identity_v1',
    bootstrapQueue: false,
  );
  final box = Hive.box('user');
  final stage = box.get('nativeProvenanceStage', defaultValue: 0) as int;
  final queries = <String>[];
  final service = SpotifyTrackMatchingService(
    musicLookup: (query) async {
      queries.add(query);
      final index = query.contains('One')
          ? 1
          : query.contains('Two')
          ? 2
          : 3;
      return [
        {
          'ytid': 'owned-provenance-$index',
          'title': index == 1
              ? 'Owned One'
              : index == 2
              ? 'Owned Two'
              : 'Owned Legacy',
          'artist': 'Synthetic Artist',
          'album': 'Synthetic Album',
          'duration': 120,
          'isrc': 'ZZAAA260000$index',
          'sourceType': 'youtube_music_song',
        },
      ];
    },
    videoLookup: (_) async => [],
  );
  if (stage == 0) {
    final preview = SpotifyCsvImporter.parseBytes(
      Uint8List.fromList(
        utf8.encode(
          'Track URI,Spotify Track ID,title,artist,album,isrc,duration_ms\n'
          'spotify:track:$_idA,$_idA,Owned One,Synthetic Artist,Synthetic Album,ZZAAA2600001,120000\n'
          'https://open.spotify.com/track/$_idB?si=synthetic,$_idB,Owned Two,Synthetic Artist,Synthetic Album,ZZAAA2600002,120000\n'
          ',,Owned Legacy,Synthetic Artist,Synthetic Album,ZZAAA2600003,120000\n',
        ),
      ),
      fileName: 'owned-provenance.csv',
    );
    await const SpotifyImportSessionService().saveNewImport(preview);
    await service.matchNextBatch(
      batchSize: 3,
      shouldPause: () => queries.isNotEmpty,
    );
    final before = jsonEncode(box.toMap());
    var rolledBack = false;
    try {
      await SpotifyImportSessionService(
        sessionWriter: (target, values) async {
          await target.put(
            'spotifyImportTracks',
            values['spotifyImportTracks'],
          );
          throw StateError('Owned partial replacement');
        },
      ).saveNewImport(preview);
    } catch (_) {
      rolledBack = jsonEncode(box.toMap()) == before;
    }
    if (!rolledBack)
      throw StateError('Owned session rollback changed stored values');
  } else if (stage == 1) {
    final first = jsonEncode((box.get('spotifyMatchResults') as List).first);
    await service.matchNextBatch(batchSize: 3);
    if (jsonEncode((box.get('spotifyMatchResults') as List).first) != first) {
      throw StateError('Resume rewrote completed selected recording');
    }
  }
  final tracks = box.get('spotifyImportTracks') as List;
  final results = box.get('spotifyMatchResults') as List;
  final expectedCount = stage == 0 ? 1 : 3;
  if (tracks.length != 3 ||
      results.length != expectedCount ||
      (results.first as Map)['spotifyTrackId'] != _idA ||
      (results.first as Map)['bestCandidate']['ytid'] != 'owned-provenance-1' ||
      (tracks[2] as Map).containsKey('spotifyTrackUri') ||
      (tracks[2] as Map).containsKey('spotifyTrackId')) {
    throw StateError('Native optional/legacy checkpoint mismatch');
  }
  if (stage > 0 &&
      ((results[1] as Map)['spotifyTrackId'] != _idB ||
          (results[2] as Map).containsKey('spotifyTrackUri') ||
          (results[2] as Map).containsKey('spotifyTrackId'))) {
    throw StateError('Native resume lost metadata or backfilled legacy row');
  }
  await box.put('nativeProvenanceStage', stage + 1);
  for (final name in ['settings', 'user', 'userNoBackup', 'cache'])
    await Hive.box(name).flush();
  await File('$applicationDirPath/provenance-stage-$stage.json').writeAsString(
    jsonEncode({
      'sourceSha': const String.fromEnvironment('GIT_SHA'),
      'stage': stage,
      'tracks': tracks,
      'results': results,
      'controlledLookupCount': queries.length,
      'matchingStatus':
          (box.get('spotifyImportMetadata') as Map)['matchingStatus'],
      'nextTrackIndex':
          (box.get('spotifyImportMetadata') as Map)['nextTrackIndex'],
      'providerRequests': 0,
      'playbackPerformed': false,
      'normalDataIsolated': true,
      'firstStageRollbackExact': stage == 0,
    }),
    flush: true,
  );
}
