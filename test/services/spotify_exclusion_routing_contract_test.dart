import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'authoritative exclusion index protects a stale matched row without repairing stored decisions',
    () async {
      initPriorityReviewTestPlugins();
      final root = await Directory.systemTemp.createTemp(
        'exclusion-routing-contract-',
      );
      Hive.init(root.path);
      try {
        await initPriorityReviewHive();
        resetPriorityReviewGlobals();
        await Hive.box('user').putAll({
          'likedSongs': [
            {'ytid': 'keep-owner'},
          ],
          'spotifyImportMetadata': {
            'importSessionId': 'owned',
            'fileName': 'owned.csv',
          },
          'spotifyImportTracks': [
            for (var row = 1; row <= 3; row++)
              {'sourceRow': row, 'title': 'Owned $row', 'artist': 'Owned'},
          ],
          'spotifyMatchResults': [
            for (var row = 1; row <= 3; row++)
              {
                'sourceRow': row,
                'status': 'matched',
                'bestCandidate': {'ytid': 'owned-$row', 'title': 'Owned $row'},
              },
          ],
          'spotifyExcludedImportRows': [3],
        });
        final original = Hive.box('user').get('spotifyMatchResults');
        const service = SpotifyImportDestinationService();
        final snapshot = await service.loadSnapshot();
        expect(
          snapshot.resolvedSongs.map((song) => song['ytid']).toList(),
          ['owned-1', 'owned-2'],
          reason: 'Authoritative permanent exclusion must not be routed',
        );
        final result = await service.route(
          snapshot: snapshot,
          requestedCount: 3,
          destinationKind: SpotifyImportDestinationKind.likedSongs,
          selectionKind: SpotifyImportSelectionKind.all,
        );
        expect(result.selectedCount, 2);
        expect(
          (Hive.box('user').get('likedSongs') as List)
              .map((song) => song['ytid'])
              .toList(),
          ['owned-1', 'owned-2', 'keep-owner'],
        );
        expect(Hive.box('user').get('spotifyMatchResults'), original);
        expect(Hive.box('user').get('spotifyExcludedImportRows'), [3]);
        expect(
          (await service.loadSnapshot()).newlyResolvedRecordingIds,
          isEmpty,
        );
      } finally {
        await Hive.close();
        final owned = await root.resolveSymbolicLinks();
        final temporary = await Directory.systemTemp.resolveSymbolicLinks();
        if (!owned.startsWith(
          '$temporary${Platform.pathSeparator}exclusion-routing-contract-',
        ))
          throw StateError('Fixture path escaped ownership');
        await root.delete(recursive: true);
      }
    },
  );
}
