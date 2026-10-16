// Synthetic Android guard checks, separate from normal and four-mode boxes.
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_routing_state.dart';

Future<Map<String, dynamic>> runOwnedStaleRoutingRehearsal(
  Directory normal,
) async {
  final root = Directory(
    '${normal.path}/i11_guard_${DateTime.now().microsecondsSinceEpoch}',
  );
  if (await root.exists())
    throw StateError('Refusing existing guard directory');
  await root.create();
  final cases = <Map<String, dynamic>>[];
  for (final change in ['excluded', 'alternate', 'prior-pending']) {
    final path = Directory('${root.path}/$change');
    await path.create();
    Hive.init(path.path);
    for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
      await Hive.openBox(name);
    }
    final user = Hive.box('user');
    final prior = {
      'operationId': 'old-incomplete',
      'selectedRecordingIds': ['guard-one'],
    };
    final metadata = <String, dynamic>{
      'importSessionId': 'guard-$change',
      'fileName': 'owned-legacy.csv',
      'routingHistory': [
        {'selectedCount': 1, 'routedAt': 'legacy-audit'},
      ],
      if (change == 'prior-pending') ...{
        importRoutingPendingKey: prior,
        importRoutingBaselineKey: importRoutingBaseline(
          sessionId: 'guard-$change',
          rows: const [
            {'sourceRow': '1', 'recordingId': 'guard-one'},
            {'sourceRow': '2', 'recordingId': 'guard-alternative'},
          ],
          recordedAt: '2026-10-12T00:00:00Z',
          reliable: true,
          reason: 'confirmed_transfer',
        ),
      },
    };
    await user.putAll({
      'likedSongs': [
        {'ytid': 'keep-owned', 'title': 'Keep owned existing'},
      ],
      'spotifyImportMetadata': metadata,
      'spotifyMatchResults': [
        {
          'sourceRow': 1,
          'status': 'matched',
          'bestCandidate': {'ytid': 'guard-one', 'title': 'Owned one'},
        },
        {
          if (change == 'prior-pending') 'sourceRow': 2,
          'status': 'matched',
          'bestCandidate': {
            'ytid': 'guard-alternative',
            'title': 'Owned alternative',
          },
        },
      ],
      'spotifyImportTracks': [
        {'sourceRow': 1},
        {'sourceRow': 2},
      ],
    });
    reloadSongLibraryStateFromStorage();
    reloadPlaylistLibraryStateFromStorage();
    var writes = 0;
    final service = SpotifyImportDestinationService(
      metadataWriter: (box, values) async {
        await box.put('spotifyImportMetadata', values);
        if (++writes == 1) {
          final rows = List<Map>.from(box.get('spotifyMatchResults'));
          final index = change == 'prior-pending' ? 0 : 1;
          rows[index] = Map.from(rows[index]);
          if (change == 'alternate') {
            rows[index]['bestCandidate'] = {
              'ytid': 'changed-guard-alternative',
              'title': 'Changed owned choice',
            };
          } else {
            rows[index]['status'] = 'excluded';
          }
          await box.put('spotifyMatchResults', rows);
        }
      },
    );
    var rejected = false;
    try {
      await service.route(
        snapshot: await service.loadSnapshot(),
        requestedCount: 0,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
        selectionKind: SpotifyImportSelectionKind.individual,
        selectedRecordingIds: {'guard-alternative'},
      );
    } on StateError {
      rejected = true;
    }
    if (!rejected ||
        writes != 2 ||
        userLikedSongsList.value.length != 1 ||
        userLikedSongsList.value.single['ytid'] != 'keep-owned') {
      throw StateError('Guard failed: $change');
    }
    await user.flush();
    await Hive.close();
    Hive.init(path.path);
    for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
      await Hive.openBox(name);
    }
    reloadSongLibraryStateFromStorage();
    reloadPlaylistLibraryStateFromStorage();
    if (userLikedSongsList.value.length != 1 ||
        userLikedSongsList.value.single['ytid'] != 'keep-owned') {
      throw StateError('Destination changed across reopen');
    }
    final saved = Map.from(
      Hive.box('user').get('spotifyImportMetadata') as Map,
    );
    if (jsonEncode(saved['routingHistory']) !=
        jsonEncode(metadata['routingHistory']))
      throw StateError('Legacy history changed');
    if (change == 'prior-pending') {
      if (jsonEncode(saved[importRoutingPendingKey]) != jsonEncode(prior) ||
          (await service.loadSnapshot()).newlyResolvedBaselineKnown) {
        throw StateError('Prior uncertainty lost');
      }
    } else if (saved.containsKey(importRoutingPendingKey)) {
      throw StateError('Rejected fresh attempt left a marker');
    }
    cases.add({
      'case': change,
      'rejectedBeforeDestinationWrite': true,
      'existingLikeExact': true,
      'legacyHistoryExact': true,
      'priorUncertaintyPreserved': true,
      'scratchReopenVerified': true,
    });
    await Hive.close();
  }
  final proof = {
    'sourceSha': const String.fromEnvironment('GIT_SHA'),
    'cases': cases,
    'normalBoxesOpened': false,
    'priorFourModeBoxesOpened': false,
    'providerMediaRequested': false,
    'scratchRoot': root.path,
  };
  await File('${root.path}/proof.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(proof),
    flush: true,
  );
  return proof;
}
