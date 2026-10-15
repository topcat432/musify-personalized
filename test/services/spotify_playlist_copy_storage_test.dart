import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import 'package:musify/services/spotify_playlist_copy_proof.dart';

import '../../tool/visual_review_harness.dart';
import '../support/spotify_empty_source_fixture.dart';

// Encoding/restore feasibility only; this fixture does not authorize a writer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('source-copy-proof-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    await SpotifyEmptySourceFixture.seed();
    await Hive.box('user').put('typedOwnerSentinel', {
      'bytes': Uint8List.fromList([3, 1, 2]),
      'at': DateTime.utc(2026, 10, 15),
    });
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  Future<void> reopen(String path) async {
    await Hive.close();
    Hive.init(path);
    await initPriorityReviewHive();
  }

  SpotifyPlaylistCopyProof proof() => SpotifyPlaylistCopyProof.create(
    operationId: 'synthetic-copy-operation',
    destinationId: 'customId-copy-proof',
    sessionId: 'synthetic-session',
    sourceKey: 'synthetic-source',
    sourceFingerprint: 'a' * 64,
    recordingIds: [
      'selected-alternative',
      'selected-B',
      'selected-alternative',
    ],
  );
  Future<void> seed(Object? marker, {String status = 'pending'}) async {
    final box = Hive.box('user');
    await box.put('customPlaylists', [
      ...box.get('customPlaylists') as List,
      {
        'ytid': proof().destinationId,
        'source': 'user-created',
        'title': 'Synthetic source copy',
        SpotifyPlaylistCopyProof.markerKey: marker,
        'legacyUnknown': {'retained': true},
        'list': [
          for (final id in [
            'selected-alternative',
            'selected-B',
            'selected-alternative',
          ])
            {'ytid': id, 'title': 'Synthetic chosen recording'},
        ],
      },
    ]);
    final metadata = Map<String, dynamic>.from(
      box.get('spotifyImportMetadata'),
    );
    await box.put('spotifyImportMetadata', {
      ...metadata,
      'routingHistory': [
        {'legacyCountOnly': true, 'addedCount': 2},
      ],
      importRoutingPendingKey: {
        'action': SpotifyPlaylistCopyProof.action,
        'status': status,
        SpotifyPlaylistCopyProof.journalKey: marker,
        'recordingTransferBaselineAdvanced': false,
      },
    });
  }

  Map copyDestination() =>
      (Hive.box('user').get('customPlaylists') as List).last as Map;
  SpotifyPlaylistCopyRecovery classify() => classifySpotifyPlaylistCopy(
    proof: proof(),
    completed: false,
    destinations: [copyDestination()],
    sessionId: proof().sessionId,
    sourceKey: proof().sourceKey,
    sourceFingerprint: proof().sourceFingerprint,
    recordingFingerprint: proof().recordingFingerprint,
  );

  test(
    'ordinary Hive map/list encoding retains new proof/repeats and all legacy fields on reopen',
    () async {
      await seed(proof().encode());
      final before = copyImportRoutingValue(Hive.box('user').toMap());
      await reopen(root.path);
      expect(Hive.box('user').toMap(), before);
      expect(classify(), SpotifyPlaylistCopyRecovery.recoverAuditOnly);
      expect((copyDestination()['list'] as List).map((song) => song['ytid']), [
        'selected-alternative',
        'selected-B',
        'selected-alternative',
      ]);
      expect(
        (Hive.box('user').get('typedOwnerSentinel') as Map)['at'].isUtc,
        isTrue,
      );
    },
  );
  test(
    'saved-file checksums, independent restore and restart preserve exact optional proof inventory',
    () async {
      await seed(proof().encode());
      final before = copyImportRoutingValue(Hive.box('user').toMap());
      await Hive.box('user').flush();
      await Hive.box('settings').flush();
      final bundle = await MusifyBackupService.createBundleBytesForTesting({
        'user': await File('${root.path}/user.hive').readAsBytes(),
        'settings': await File('${root.path}/settings.hive').readAsBytes(),
      });
      final saved = File('${root.path}/synthetic-copy-proof.musifybackup');
      await saved.writeAsBytes(bundle, flush: true);
      expect(sha256.convert(await saved.readAsBytes()), sha256.convert(bundle));
      final inspected = await MusifyBackupService.inspectBundleFileForTesting(
        saved,
      );
      final independent = await Directory('${root.path}/independent').create();
      await reopen(independent.path);
      await Hive.box('user').put('wrongInventory', true);
      expect(
        (await MusifyBackupService.restoreValidatedBackup(inspected)).success,
        isTrue,
      );
      await reopen(independent.path);
      expect(Hive.box('user').toMap(), before);
      expect(classify(), SpotifyPlaylistCopyRecovery.recoverAuditOnly);
    },
  );
  for (final raw in [
    null,
    <String, dynamic>{'legacyCount': 3},
    <String, dynamic>{'version': 2, 'opaqueFutureProof': true},
  ]) {
    test(
      'null/legacy/future proof survives restart without adoption: $raw',
      () async {
        await seed(raw);
        final before = copyImportRoutingValue(Hive.box('user').toMap());
        await reopen(root.path);
        expect(Hive.box('user').toMap(), before);
        expect(classify(), SpotifyPlaylistCopyRecovery.invalidProof);
        expect(
          jsonEncode(copyDestination()[SpotifyPlaylistCopyProof.markerKey]),
          jsonEncode(raw),
        );
      },
    );
  }
}
