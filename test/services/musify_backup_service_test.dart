import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';

void main() {
  late Directory hiveRoot;

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('musify-backup-test-');
    Hive.init(hiveRoot.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) await hiveRoot.delete(recursive: true);
  });

  test('rejects an arbitrary renamed file', () async {
    await expectLater(
      MusifyBackupService.inspectBundleBytes(
        utf8.encode('not a Musify database'),
        sourceDescription: 'random.musifybackup',
      ),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('validates all 2,643 imported tracks and matching decisions', () async {
    final payloads = await _createMatchingPayloads(
      importedTracks: 2643,
      matched: 2128,
      review: 353,
      unmatched: 162,
    );
    final bundle = await MusifyBackupService.createBundleBytesForTesting(
      payloads,
    );

    final validated = await MusifyBackupService.inspectBundleBytes(
      bundle,
      sourceDescription: 'synthetic-2643.musifybackup',
    );

    expect(validated.summary.importedTracks, 2643);
    expect(validated.summary.matchResults, 2643);
    expect(validated.summary.strongMatches, 2128);
    expect(validated.summary.reviewItems, 353);
    expect(validated.summary.unmatchedItems, 162);
    expect(validated.summary.errorItems, 0);
  });

  test('rejects a backup with one required database removed', () async {
    final payloads = await _createMatchingPayloads(
      importedTracks: 2,
      matched: 1,
      review: 1,
      unmatched: 0,
    );
    final bundle = await MusifyBackupService.createBundleBytesForTesting(
      payloads,
    );
    final decoded = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(bundle)) as Map,
    );
    final encodedPayloads = Map<String, dynamic>.from(
      decoded['payloads'] as Map,
    )..remove('settings.hive');
    decoded['payloads'] = encodedPayloads;

    await expectLater(
      MusifyBackupService.inspectBundleBytes(
        utf8.encode(jsonEncode(decoded)),
        sourceDescription: 'partial.musifybackup',
      ),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('rejects checksum tampering before opening live databases', () async {
    final payloads = await _createMatchingPayloads(
      importedTracks: 2,
      matched: 2,
      review: 0,
      unmatched: 0,
    );
    final bundle = await MusifyBackupService.createBundleBytesForTesting(
      payloads,
    );
    final decoded = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(bundle)) as Map,
    );
    final encodedPayloads = Map<String, dynamic>.from(
      decoded['payloads'] as Map,
    );
    final userBytes = base64Decode(encodedPayloads['user.hive'] as String);
    userBytes[userBytes.length ~/ 2] ^= 0x01;
    encodedPayloads['user.hive'] = base64Encode(userBytes);
    decoded['payloads'] = encodedPayloads;

    await expectLater(
      MusifyBackupService.inspectBundleBytes(
        utf8.encode(jsonEncode(decoded)),
        sourceDescription: 'tampered.musifybackup',
      ),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('rejects random bytes renamed as legacy Hive files', () async {
    await expectLater(
      MusifyBackupService.inspectLegacyPayloadsForTesting({
        'user': Uint8List.fromList(utf8.encode('not hive')),
        'settings': Uint8List.fromList(utf8.encode('also not hive')),
      }),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('rolls back both live databases after a mid-restore failure', () async {
    final candidatePayloads = await _createMatchingPayloads(
      importedTracks: 3,
      matched: 2,
      review: 1,
      unmatched: 0,
      namePrefix: 'candidate',
    );
    final bundle = await MusifyBackupService.createBundleBytesForTesting(
      candidatePayloads,
    );
    final candidate = await MusifyBackupService.inspectBundleBytes(
      bundle,
      sourceDescription: 'candidate.musifybackup',
    );

    final liveUser = await Hive.openBox('user');
    await liveUser.put('sentinel', 'original-user-data');
    final liveSettings = await Hive.openBox('settings');
    await liveSettings.put('sentinel', 'original-settings-data');
    await Future.wait([liveUser.flush(), liveSettings.flush()]);

    final result = await MusifyBackupService.restoreValidatedBackup(
      candidate,
      simulateFailureAfterReplacements: 1,
    );

    expect(result.success, isFalse);
    expect(Hive.box('user').get('sentinel'), 'original-user-data');
    expect(Hive.box('settings').get('sentinel'), 'original-settings-data');
    expect(Hive.box('user').get('spotifyImportTracks'), isNull);
  });

  test('startup recovery rolls back an unverified interrupted restore', () async {
    for (final boxName in ['user', 'settings']) {
      await File('${hiveRoot.path}/$boxName.hive').writeAsString('new-$boxName');
      await File(
        '${hiveRoot.path}/$boxName.hive.pre-restore',
      ).writeAsString('old-$boxName');
    }
    await File(
      '${hiveRoot.path}/musify_restore_transaction.json',
    ).writeAsString(jsonEncode({'state': 'replacing'}));

    await MusifyBackupService.recoverInterruptedRestoreInDirectory(hiveRoot);

    expect(await File('${hiveRoot.path}/user.hive').readAsString(), 'old-user');
    expect(
      await File('${hiveRoot.path}/settings.hive').readAsString(),
      'old-settings',
    );
    expect(
      await File(
        '${hiveRoot.path}/musify_restore_transaction.json',
      ).exists(),
      isFalse,
    );
  });

  test('startup recovery commits only a previously verified restore', () async {
    for (final boxName in ['user', 'settings']) {
      await File('${hiveRoot.path}/$boxName.hive').writeAsString('new-$boxName');
      await File(
        '${hiveRoot.path}/$boxName.hive.pre-restore',
      ).writeAsString('old-$boxName');
    }
    await File(
      '${hiveRoot.path}/musify_restore_transaction.json',
    ).writeAsString(jsonEncode({'state': 'verified'}));

    await MusifyBackupService.recoverInterruptedRestoreInDirectory(hiveRoot);

    expect(await File('${hiveRoot.path}/user.hive').readAsString(), 'new-user');
    expect(
      await File('${hiveRoot.path}/settings.hive').readAsString(),
      'new-settings',
    );
    expect(
      await File('${hiveRoot.path}/user.hive.pre-restore').exists(),
      isFalse,
    );
  });
}

Future<Map<String, Uint8List>> _createMatchingPayloads({
  required int importedTracks,
  required int matched,
  required int review,
  required int unmatched,
  String namePrefix = 'source',
}) async {
  if (matched + review + unmatched != importedTracks) {
    throw ArgumentError('Result counts must equal importedTracks.');
  }
  final tracks = List<Map<String, dynamic>>.generate(
    importedTracks,
    (index) => {'sourceRow': index + 2, 'title': 'Track $index'},
  );
  final results = <Map<String, dynamic>>[
    for (var index = 0; index < matched; index++)
      {'sourceRow': index + 2, 'status': 'matched'},
    for (var index = 0; index < review; index++)
      {'sourceRow': matched + index + 2, 'status': 'needs_review'},
    for (var index = 0; index < unmatched; index++)
      {
        'sourceRow': matched + review + index + 2,
        'status': 'unmatched',
      },
  ];

  final userName = '${namePrefix}_user';
  final user = await Hive.openBox(userName);
  await user.put('spotifyImportTracks', tracks);
  await user.put('spotifyMatchResults', results);
  await user.put('likedSongs', <Map<String, dynamic>>[]);
  await user.flush();
  final userPath = user.path!;
  final userBytes = Uint8List.fromList(await File(userPath).readAsBytes());
  await user.close();

  final settingsName = '${namePrefix}_settings';
  final settings = await Hive.openBox(settingsName);
  await settings.put('themeIndex', 2);
  await settings.put('wrappedEnabled', true);
  await settings.flush();
  final settingsPath = settings.path!;
  final settingsBytes = Uint8List.fromList(
    await File(settingsPath).readAsBytes(),
  );
  await settings.close();

  return {'user': userBytes, 'settings': settingsBytes};
}
