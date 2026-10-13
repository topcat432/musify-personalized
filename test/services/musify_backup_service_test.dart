import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/personalized_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveRoot;

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('musify-backup-test-');
    Hive.init(hiveRoot.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) await hiveRoot.delete(recursive: true);
  });

  Future<ValidatedBackup> candidate() async {
    final payloads = await _createMatchingPayloads(
      importedTracks: 3,
      matched: 2,
      review: 1,
      unmatched: 0,
    );
    return MusifyBackupService.inspectBundleBytes(
      await MusifyBackupService.createBundleBytesForTesting(payloads),
      sourceDescription: 'synthetic.musifybackup',
    );
  }

  test(
    'valid zero-byte boxes round-trip through byte and streamed backups',
    () async {
      final payloads = {'user': Uint8List(0), 'settings': Uint8List(0)};
      final bytes = await MusifyBackupService.createBundleBytesForTesting(
        payloads,
      );
      final inMemory = await MusifyBackupService.inspectBundleBytes(
        bytes,
        sourceDescription: 'empty.musifybackup',
      );
      expect(inMemory.summary.userKeys, 0);
      expect(inMemory.summary.settingsKeys, 0);
      final file = await MusifyBackupService.createStreamedBundleFileForTesting(
        payloads,
        hiveRoot,
      );
      final streamed = await MusifyBackupService.inspectBundleFileForTesting(
        file,
      );
      expect(streamed.summary.importedTracks, 0);
      expect(streamed.summary.favorites, 0);
    },
  );

  for (final populatedSettings in [false, true]) {
    test(
      'restore into empty user and ${populatedSettings ? 'populated' : 'empty'} settings persists without a manufactured key',
      () async {
        final incoming = await candidate();
        final user = await Hive.openBox('user');
        final settings = await Hive.openBox('settings');
        if (populatedSettings) await settings.put('sentinel', true);
        await user.flush();
        expect(await File(user.path!).length(), 0);
        final result = await MusifyBackupService.restoreValidatedBackup(
          incoming,
        );
        expect(result.success, isTrue, reason: result.message);
        await Hive.close();
        expect(
          (await Hive.openBox('user')).get('spotifyImportTracks'),
          hasLength(3),
        );
        expect((await Hive.openBox('settings')).get('wrappedEnabled'), isTrue);
      },
    );
  }

  test(
    'explicit valid empty backup replaces nonempty boxes and reopens',
    () async {
      final incoming = await MusifyBackupService.inspectBundleBytes(
        await MusifyBackupService.createBundleBytesForTesting({
          'user': Uint8List(0),
          'settings': Uint8List(0),
        }),
        sourceDescription: 'declared-empty.musifybackup',
      );
      await (await Hive.openBox('user')).put('sentinel', 'old-user');
      await (await Hive.openBox('settings')).put('sentinel', 'old-settings');
      final result = await MusifyBackupService.restoreValidatedBackup(incoming);
      expect(result.success, isTrue, reason: result.message);
      await Hive.close();
      for (final name in ['user', 'settings']) {
        expect((await Hive.openBox(name)).isEmpty, isTrue);
        expect(await File('${hiveRoot.path}/$name.hive').length(), 0);
      }
    },
  );

  for (final failureAt in [1, 2]) {
    test(
      'failure after $failureAt replacements preserves exact empty rollback and populated settings',
      () async {
        final incoming = await candidate();
        final user = await Hive.openBox('user');
        final settings = await Hive.openBox('settings');
        await settings.put('sentinel', 'original-settings');
        await settings.flush();
        final beforeUser = await File(user.path!).readAsBytes();
        final beforeSettings = await File(settings.path!).readAsBytes();
        expect(beforeUser, isEmpty);
        final result = await MusifyBackupService.restoreValidatedBackup(
          incoming,
          simulateFailureAfterReplacements: failureAt,
        );
        expect(result.success, isFalse);
        expect(await File(user.path!).readAsBytes(), beforeUser);
        expect(await File(settings.path!).readAsBytes(), beforeSettings);
        await Hive.close();
        expect((await Hive.openBox('user')).isEmpty, isTrue);
        expect(
          (await Hive.openBox('settings')).get('sentinel'),
          'original-settings',
        );
      },
    );
  }

  test(
    'truncated declared nonempty payload is never reclassified as valid empty',
    () async {
      final incoming = await candidate();
      final original = await MusifyBackupService.createBundleBytesForTesting(
        incoming.payloads,
      );
      final root = jsonDecode(utf8.decode(original)) as Map;
      (root['payloads'] as Map)['user.hive'] = '';
      await expectLater(
        MusifyBackupService.inspectBundleBytes(
          utf8.encode(jsonEncode(root)),
          sourceDescription: 'truncated.musifybackup',
        ),
        throwsA(isA<BackupValidationException>()),
      );
      final file = File('${hiveRoot.path}/truncated.musifybackup');
      await file.writeAsString(jsonEncode(root));
      await expectLater(
        MusifyBackupService.inspectBundleFileForTesting(file),
        throwsA(isA<BackupValidationException>()),
      );
    },
  );

  test(
    'strict validation rejects malformed and partial nonempty Hive frames',
    () async {
      final incoming = await candidate();
      final user = incoming.payloads['user']!;
      for (final corrupt in [
        Uint8List.fromList([1, 2, 3, 4, 5]),
        Uint8List.sublistView(user, 0, user.length - 1),
      ]) {
        await expectLater(
          MusifyBackupService.createBundleBytesForTesting({
            'user': corrupt,
            'settings': incoming.payloads['settings']!,
          }),
          throwsA(isA<BackupValidationException>()),
        );
        await expectLater(
          MusifyBackupService.createStreamedBundleFileForTesting({
            'user': corrupt,
            'settings': incoming.payloads['settings']!,
          }, hiveRoot),
          throwsA(isA<BackupValidationException>()),
        );
      }
    },
  );

  for (final zeroFile in [false, true]) {
    test(
      'preflight rejects ${zeroFile ? 'zeroed' : 'partial'} rollback file without rewriting or repairing originals',
      () async {
        final incoming = await candidate();
        final user = await Hive.openBox('user');
        final settings = await Hive.openBox('settings');
        await user.put('sentinel', 'original-user');
        await settings.put('sentinel', 'original-settings');
        await user.flush();
        await settings.flush();
        final file = File(user.path!);
        final original = await file.readAsBytes();
        final corrupt = zeroFile
            ? Uint8List(0)
            : Uint8List.sublistView(original, 0, original.length - 1);
        await file.writeAsBytes(corrupt, flush: true);
        final result = await MusifyBackupService.restoreValidatedBackup(
          incoming,
        );
        expect(result.success, isFalse);
        expect(result.message, contains('before replacement'));
        expect(await file.readAsBytes(), corrupt);
        expect(Hive.box('user').get('sentinel'), 'original-user');
        expect(Hive.box('settings').get('sentinel'), 'original-settings');
        expect(
          await File(
            '${hiveRoot.path}/musify_restore_transaction.json',
          ).exists(),
          isFalse,
        );
        await file.writeAsBytes(original, flush: true);
      },
    );
  }

  test(
    'invalid incoming data leaves fresh empty originals open and unchanged',
    () async {
      final valid = await candidate();
      final user = await Hive.openBox('user');
      final settings = await Hive.openBox('settings');
      final bad = ValidatedBackup(
        payloads: {
          'user': Uint8List.fromList([1, 2, 3, 4, 5]),
          'settings': valid.payloads['settings']!,
        },
        summary: valid.summary,
        manifest: valid.manifest,
        sourceDescription: 'invalid-import',
      );
      final result = await MusifyBackupService.restoreValidatedBackup(bad);
      expect(result.success, isFalse);
      expect(Hive.isBoxOpen('user'), isTrue);
      expect(Hive.isBoxOpen('settings'), isTrue);
      expect(await File(user.path!).length(), 0);
      expect(await File(settings.path!).length(), 0);
    },
  );

  test(
    'cold recovery restores zero-byte original with populated partner exactly',
    () async {
      final incoming = await candidate();
      final user = await Hive.openBox('user');
      final settings = await Hive.openBox('settings');
      await settings.put('sentinel', 'original-settings');
      await settings.flush();
      final oldSettings = await File(settings.path!).readAsBytes();
      await Hive.close();
      await File(
        '${hiveRoot.path}/user.hive',
      ).rename('${hiveRoot.path}/user.hive.pre-restore');
      await File(
        '${hiveRoot.path}/user.hive',
      ).writeAsBytes(incoming.payloads['user']!, flush: true);
      await File(
        '${hiveRoot.path}/settings.hive.restore-candidate',
      ).writeAsBytes(incoming.payloads['settings']!, flush: true);
      await File(
        '${hiveRoot.path}/musify_restore_transaction.json',
      ).writeAsString(jsonEncode({'state': 'replacing'}), flush: true);
      await MusifyBackupService.recoverInterruptedRestoreInDirectory(hiveRoot);
      expect(await File('${hiveRoot.path}/user.hive').length(), 0);
      expect(
        await File('${hiveRoot.path}/settings.hive').readAsBytes(),
        oldSettings,
      );
      expect((await Hive.openBox('user')).isEmpty, isTrue);
      expect(
        (await Hive.openBox('settings')).get('sentinel'),
        'original-settings',
      );
    },
  );

  test('rejects an arbitrary renamed file', () async {
    await expectLater(
      MusifyBackupService.inspectBundleBytes(
        utf8.encode('not a Musify database'),
        sourceDescription: 'random.musifybackup',
      ),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('does not reopen Android SAF save destinations as File paths', () {
    expect(
      MusifyBackupService.shouldVerifyPickerSavePathForTesting(
        TargetPlatform.android,
      ),
      isFalse,
    );
    expect(
      MusifyBackupService.shouldVerifyPickerSavePathForTesting(
        TargetPlatform.linux,
      ),
      isTrue,
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

  test('streamed creation remains readable without Base64 copies', () async {
    final payloads = await _createMatchingPayloads(
      importedTracks: 2643,
      matched: 2619,
      review: 0,
      unmatched: 24,
      namePrefix: 'streamed',
    );
    final bundleFile =
        await MusifyBackupService.createStreamedBundleFileForTesting(
          payloads,
          hiveRoot,
        );

    final validated = await MusifyBackupService.inspectBundleFileForTesting(
      bundleFile,
      sourceDescription: 'streamed-2643.musifybackup',
    );

    expect(validated.summary.importedTracks, 2643);
    expect(validated.summary.matchResults, 2643);
    expect(validated.summary.strongMatches, 2619);
    expect(validated.summary.unmatchedItems, 24);
  });

  test(
    'picked streamed backup survives validation before staging cleanup',
    () async {
      final payloads = await _createMatchingPayloads(
        importedTracks: 3,
        matched: 1,
        review: 1,
        unmatched: 1,
        namePrefix: 'picker',
      );
      final source =
          await MusifyBackupService.createStreamedBundleFileForTesting(
            payloads,
            hiveRoot,
          );
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'custom');
        return [
          {
            'path': source.path,
            'name': 'streamed.musifybackup',
            'size': await source.length(),
          },
        ];
      });
      try {
        final backup = await MusifyBackupService.pickAndInspectBundle();
        expect(backup, isNotNull);
        expect(backup!.summary.importedTracks, 3);
        expect(backup.summary.matchResults, 3);
        expect(backup.summary.strongMatches, 1);
        expect(backup.summary.reviewItems, 1);
        expect(backup.summary.unmatchedItems, 1);
        expect(backup.payloads['user'], orderedEquals(payloads['user']!));
        expect(
          backup.payloads['settings'],
          orderedEquals(payloads['settings']!),
        );
        expect(await source.exists(), isTrue);
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );

  test('preserves excluded import decisions in verified backups', () async {
    final payloads = await _createMatchingPayloads(
      importedTracks: 3,
      matched: 1,
      review: 0,
      unmatched: 1,
      excluded: 1,
      namePrefix: 'excluded',
    );
    final bundle = await MusifyBackupService.createBundleBytesForTesting(
      payloads,
    );

    final validated = await MusifyBackupService.inspectBundleBytes(
      bundle,
      sourceDescription: 'excluded.musifybackup',
    );

    expect(validated.summary.excludedItems, 1);
    expect(validated.summary.matchResults, 3);
  });

  test(
    'stable identity and historical origins preserve synthetic backup data',
    () async {
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
      final manifest = Map<String, dynamic>.from(decoded['manifest'] as Map);
      for (final origin in [
        ['com.topcat432.musifypersonalized.preview', 'stable'],
        ['com.topcat432.musifypersonalized.preview.debug', 'debug'],
        ['com.topcat432.musifypersonalized', 'production'],
        ['com.topcat432.musifypersonalized.debug', 'debug'],
        ['com.gokadzev.musify.fdroid', 'stable'],
        ['com.gokadzev.musify.fdroid.debug', 'debug'],
      ]) {
        manifest['app'] = {
          'package': origin[0],
          'channel': origin[1],
          'version': 'synthetic',
        };
        decoded['manifest'] = manifest;
        final validated = await MusifyBackupService.inspectBundleBytes(
          utf8.encode(jsonEncode(decoded)),
          sourceDescription: 'synthetic-identity.musifybackup',
        );
        expect(validated.summary.importedTracks, 2);
        expect(validated.summary.reviewItems, 1);
      }
      manifest['app'] = {'package': 'another.app', 'channel': 'stable'};
      decoded['manifest'] = manifest;
      await expectLater(
        MusifyBackupService.inspectBundleBytes(
          utf8.encode(jsonEncode(decoded)),
          sourceDescription: 'synthetic-unknown.musifybackup',
        ),
        throwsA(isA<BackupValidationException>()),
      );
    },
  );

  test(
    'serialized backup records actual Android version and retained identity',
    () async {
      final payloads = await _createMatchingPayloads(
        importedTracks: 2,
        matched: 1,
        review: 1,
        unmatched: 0,
      );
      final bundle = await MusifyBackupService.createBundleBytesForTesting(
        payloads,
        identity: const InstalledAppIdentity(
          packageName: 'com.topcat432.musifypersonalized.preview',
          versionName: '0.1.300000002',
          versionCode: 300000002,
          signerSha256: 'synthetic',
        ),
      );
      final validated = await MusifyBackupService.inspectBundleBytes(
        bundle,
        sourceDescription: 'synthetic-version.musifybackup',
      );
      final app = validated.manifest['app'] as Map;
      expect(app['package'], 'com.topcat432.musifypersonalized.preview');
      expect(app['channel'], 'stable');
      expect(app['version'], '0.1.300000002');
      expect(app['versionCode'], 300000002);
      expect(validated.summary.importedTracks, 2);
    },
  );

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

  test(
    'reopens and verifies the exact file written by the save picker',
    () async {
      final payloads = await _createMatchingPayloads(
        importedTracks: 3,
        matched: 2,
        review: 1,
        unmatched: 0,
      );
      final bundle = await MusifyBackupService.createBundleBytesForTesting(
        payloads,
      );
      final saved = File('${hiveRoot.path}/verified.musifybackup');
      await saved.writeAsBytes(bundle, flush: true);

      final validated =
          await MusifyBackupService.verifySavedBackupFileForTesting(
            saved,
            bundle,
          );

      expect(validated.summary.importedTracks, 3);
      expect(validated.summary.matchResults, 3);
    },
  );

  test(
    'rejects a save-picker file whose bytes changed after validation',
    () async {
      final payloads = await _createMatchingPayloads(
        importedTracks: 2,
        matched: 2,
        review: 0,
        unmatched: 0,
      );
      final bundle = await MusifyBackupService.createBundleBytesForTesting(
        payloads,
      );
      final saved = File('${hiveRoot.path}/changed.musifybackup');
      final changed = Uint8List.fromList(bundle);
      changed[bundle.length ~/ 2] ^= 0x01;
      await saved.writeAsBytes(changed, flush: true);

      await expectLater(
        MusifyBackupService.verifySavedBackupFileForTesting(saved, bundle),
        throwsA(isA<BackupValidationException>()),
      );
    },
  );

  test('rejects a valid bundle saved without the required extension', () async {
    final payloads = await _createMatchingPayloads(
      importedTracks: 1,
      matched: 1,
      review: 0,
      unmatched: 0,
    );
    final bundle = await MusifyBackupService.createBundleBytesForTesting(
      payloads,
    );
    final saved = File('${hiveRoot.path}/wrong-extension.txt');
    await saved.writeAsBytes(bundle, flush: true);

    await expectLater(
      MusifyBackupService.verifySavedBackupFileForTesting(saved, bundle),
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

  test(
    'startup recovery rolls back an unverified interrupted restore',
    () async {
      for (final boxName in ['user', 'settings']) {
        await File(
          '${hiveRoot.path}/$boxName.hive',
        ).writeAsString('new-$boxName');
        await File(
          '${hiveRoot.path}/$boxName.hive.pre-restore',
        ).writeAsString('old-$boxName');
      }
      await File(
        '${hiveRoot.path}/musify_restore_transaction.json',
      ).writeAsString(jsonEncode({'state': 'replacing'}));

      await MusifyBackupService.recoverInterruptedRestoreInDirectory(hiveRoot);

      expect(
        await File('${hiveRoot.path}/user.hive').readAsString(),
        'old-user',
      );
      expect(
        await File('${hiveRoot.path}/settings.hive').readAsString(),
        'old-settings',
      );
      expect(
        await File('${hiveRoot.path}/musify_restore_transaction.json').exists(),
        isFalse,
      );
    },
  );

  test('startup recovery commits only a previously verified restore', () async {
    for (final boxName in ['user', 'settings']) {
      await File(
        '${hiveRoot.path}/$boxName.hive',
      ).writeAsString('new-$boxName');
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
  int excluded = 0,
  String namePrefix = 'source',
}) async {
  if (matched + review + unmatched + excluded != importedTracks) {
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
      {'sourceRow': matched + review + index + 2, 'status': 'unmatched'},
    for (var index = 0; index < excluded; index++)
      {
        'sourceRow': matched + review + unmatched + index + 2,
        'status': 'excluded',
        'reviewDecision': 'excluded_from_import',
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
