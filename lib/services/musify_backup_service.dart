/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:musify/constants/version.dart';
import 'package:path_provider/path_provider.dart';

const String musifyBackupExtension = 'musifybackup';
const String musifyBackupFormat = 'musify-personalized-backup';
const int musifyBackupSchemaVersion = 1;
const List<String> _requiredBoxNames = ['user', 'settings'];
const String _releasePackage = 'com.topcat432.musifypersonalized';
const String _debugPackage = 'com.topcat432.musifypersonalized.debug';
const String _gitSha = String.fromEnvironment(
  'GIT_SHA',
  defaultValue: 'unknown',
);
const String _restoreJournalName = 'musify_restore_transaction.json';

class BackupOperationResult {
  const BackupOperationResult({
    required this.success,
    required this.message,
    this.summary,
  });

  final bool success;
  final String message;
  final BackupSummary? summary;
}

class BackupSummary {
  const BackupSummary({
    required this.importedTracks,
    required this.matchResults,
    required this.strongMatches,
    required this.reviewItems,
    required this.unmatchedItems,
    required this.errorItems,
    required this.favorites,
    required this.playlists,
    required this.userKeys,
    required this.settingsKeys,
  });

  factory BackupSummary.fromJson(Map<String, dynamic> json) {
    int count(String key) => _readNonNegativeInt(json[key], key);

    return BackupSummary(
      importedTracks: count('importedTracks'),
      matchResults: count('matchResults'),
      strongMatches: count('strongMatches'),
      reviewItems: count('reviewItems'),
      unmatchedItems: count('unmatchedItems'),
      errorItems: count('errorItems'),
      favorites: count('favorites'),
      playlists: count('playlists'),
      userKeys: count('userKeys'),
      settingsKeys: count('settingsKeys'),
    );
  }

  final int importedTracks;
  final int matchResults;
  final int strongMatches;
  final int reviewItems;
  final int unmatchedItems;
  final int errorItems;
  final int favorites;
  final int playlists;
  final int userKeys;
  final int settingsKeys;

  Map<String, dynamic> toJson() => {
    'importedTracks': importedTracks,
    'matchResults': matchResults,
    'strongMatches': strongMatches,
    'reviewItems': reviewItems,
    'unmatchedItems': unmatchedItems,
    'errorItems': errorItems,
    'favorites': favorites,
    'playlists': playlists,
    'userKeys': userKeys,
    'settingsKeys': settingsKeys,
  };

  String get compactDescription =>
      '$importedTracks imported tracks, $matchResults match results, '
      '$favorites Favorites, $playlists playlists';
}

class ValidatedBackup {
  const ValidatedBackup({
    required this.payloads,
    required this.summary,
    required this.sourceDescription,
    required this.manifest,
  });

  final Map<String, Uint8List> payloads;
  final BackupSummary summary;
  final String sourceDescription;
  final Map<String, dynamic> manifest;
}

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MusifyBackupService {
  MusifyBackupService._();

  static bool _operationInProgress = false;

  static Future<BackupOperationResult> createVerifiedBackup() async {
    if (_operationInProgress) {
      return const BackupOperationResult(
        success: false,
        message: 'Another backup or restore operation is already running.',
      );
    }
    _operationInProgress = true;
    Directory? stagingDirectory;
    try {
      final payloads = <String, Uint8List>{};
      for (final boxName in _requiredBoxNames) {
        final box = await _openRequiredBox(boxName);
        await box.flush();
        final path = box.path;
        if (path == null) {
          throw BackupValidationException(
            'The $boxName database has no readable file path.',
          );
        }
        final source = File(path);
        if (!await source.exists()) {
          throw BackupValidationException(
            'The required $boxName database file does not exist.',
          );
        }
        final bytes = await source.readAsBytes();
        if (bytes.isEmpty) {
          throw BackupValidationException(
            'The required $boxName database file is empty.',
          );
        }
        payloads[boxName] = Uint8List.fromList(bytes);
      }

      stagingDirectory = await _newTemporaryDirectory('backup-create');
      final snapshots = await _validatePayloadSet(payloads, stagingDirectory);
      final summary = _summaryFromSnapshots(snapshots);
      final manifest = _buildManifest(payloads, snapshots, summary);
      final bundleBytes = _encodeBundle(manifest, payloads);

      // Validate the exact serialized bytes before writing them outside the app.
      await inspectBundleBytes(
        bundleBytes,
        sourceDescription: 'newly created backup',
      );

      final timestamp = _fileTimestamp(DateTime.now().toUtc());
      final fileName =
          'Musify-Personalized-Backup-$timestamp.$musifyBackupExtension';
      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save verified Musify backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const [musifyBackupExtension],
        bytes: bundleBytes,
      );
      if (outputPath == null) {
        return const BackupOperationResult(
          success: false,
          message: 'Backup canceled. No verified backup was created.',
        );
      }

      // Android's save-as picker writes through the Storage Access Framework.
      // Treat the picker return as untrusted until the actual saved file is
      // reopened and proven byte-for-byte identical to the validated bundle.
      final finalFile = File(outputPath);
      final finalVerification = await _verifySavedBackupFile(
        finalFile,
        expectedBytes: bundleBytes,
      );
      return BackupOperationResult(
        success: true,
        message:
            'Verified backup saved to ${finalFile.path} '
            '(${finalFile.lengthSync()} bytes; '
            '${finalVerification.summary.compactDescription}).',
        summary: finalVerification.summary,
      );
    } on BackupValidationException catch (error, stackTrace) {
      _logError(
        'Verified backup rejected',
        error: error,
        stackTrace: stackTrace,
      );
      return BackupOperationResult(success: false, message: error.message);
    } catch (error, stackTrace) {
      _logError(
        'Verified backup failed',
        error: error,
        stackTrace: stackTrace,
      );
      return BackupOperationResult(
        success: false,
        message: 'Backup failed before verification: $error',
      );
    } finally {
      _operationInProgress = false;
      await _deleteDirectoryQuietly(stagingDirectory);
    }
  }

  @visibleForTesting
  static Future<ValidatedBackup> verifySavedBackupFileForTesting(
    File file,
    Uint8List expectedBytes,
  ) {
    return _verifySavedBackupFile(file, expectedBytes: expectedBytes);
  }

  static Future<ValidatedBackup> _verifySavedBackupFile(
    File file, {
    required Uint8List expectedBytes,
  }) async {
    final fileName = file.uri.pathSegments.isEmpty
        ? file.path
        : file.uri.pathSegments.last;
    if (!fileName.toLowerCase().endsWith('.$musifyBackupExtension')) {
      throw const BackupValidationException(
        'The saved file must keep the .musifybackup extension.',
      );
    }
    if (!await file.exists()) {
      throw const BackupValidationException(
        'The selected backup destination did not produce a readable file.',
      );
    }
    final savedBytes = await file.readAsBytes();
    if (savedBytes.isEmpty) {
      throw const BackupValidationException('The saved backup file is empty.');
    }
    if (savedBytes.length != expectedBytes.length ||
        sha256.convert(savedBytes) != sha256.convert(expectedBytes)) {
      throw const BackupValidationException(
        'The saved backup does not exactly match the verified source data.',
      );
    }
    return inspectBundleBytes(savedBytes, sourceDescription: file.path);
  }

  static Future<ValidatedBackup?> pickAndInspectBundle() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [musifyBackupExtension],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final selected = result.files.single;
    if (!selected.name.toLowerCase().endsWith('.$musifyBackupExtension')) {
      throw const BackupValidationException(
        'Select a .musifybackup file created by Musify Personalized.',
      );
    }
    final bytes = await _platformFileBytes(selected);
    return inspectBundleBytes(bytes, sourceDescription: selected.name);
  }

  static Future<ValidatedBackup?> pickAndInspectLegacyPair() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['hive'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    if (result.files.length != 2) {
      throw const BackupValidationException(
        'Legacy recovery requires exactly two files: user.hive and settings.hive.',
      );
    }

    PlatformFile? userFile;
    PlatformFile? settingsFile;
    for (final file in result.files) {
      final lowerName = file.name.toLowerCase();
      if (_legacyNameMatches(lowerName, 'user')) {
        if (userFile != null) {
          throw const BackupValidationException(
            'More than one legacy user database was selected.',
          );
        }
        userFile = file;
      } else if (_legacyNameMatches(lowerName, 'settings')) {
        if (settingsFile != null) {
          throw const BackupValidationException(
            'More than one legacy settings database was selected.',
          );
        }
        settingsFile = file;
      } else {
        throw BackupValidationException(
          '${file.name} is not a recognized legacy Musify database.',
        );
      }
    }
    if (userFile == null || settingsFile == null) {
      throw const BackupValidationException(
        'Both user.hive and settings.hive are required.',
      );
    }

    final payloads = <String, Uint8List>{
      'user': await _platformFileBytes(userFile),
      'settings': await _platformFileBytes(settingsFile),
    };
    return _inspectLegacyPayloads(
      payloads,
      sourceDescription: '${userFile.name} + ${settingsFile.name}',
    );
  }

  @visibleForTesting
  static Future<ValidatedBackup> inspectLegacyPayloadsForTesting(
    Map<String, Uint8List> payloads,
  ) {
    return _inspectLegacyPayloads(
      payloads,
      sourceDescription: 'legacy test payloads',
    );
  }

  static Future<ValidatedBackup> _inspectLegacyPayloads(
    Map<String, Uint8List> payloads, {
    required String sourceDescription,
  }) async {
    final staging = await _newTemporaryDirectory('legacy-inspect');
    try {
      final snapshots = await _validatePayloadSet(payloads, staging);
      final summary = _summaryFromSnapshots(snapshots);
      if (summary.importedTracks == 0 || summary.matchResults == 0) {
        throw const BackupValidationException(
          'The legacy files contain no saved Spotify matching dataset.',
        );
      }
      if (summary.matchResults != summary.importedTracks) {
        throw BackupValidationException(
          'Legacy data is incomplete: ${summary.importedTracks} imported tracks '
          'but ${summary.matchResults} match results.',
        );
      }
      final manifest = _buildManifest(payloads, snapshots, summary)
        ..['legacyImport'] = true;
      return ValidatedBackup(
        payloads: payloads,
        summary: summary,
        sourceDescription: sourceDescription,
        manifest: manifest,
      );
    } finally {
      await _deleteDirectoryQuietly(staging);
    }
  }

  @visibleForTesting
  static Future<Uint8List> createBundleBytesForTesting(
    Map<String, Uint8List> payloads,
  ) async {
    final staging = await _newTemporaryDirectory('bundle-test-create');
    try {
      final snapshots = await _validatePayloadSet(payloads, staging);
      final summary = _summaryFromSnapshots(snapshots);
      return _encodeBundle(
        _buildManifest(payloads, snapshots, summary),
        payloads,
      );
    } finally {
      await _deleteDirectoryQuietly(staging);
    }
  }

  @visibleForTesting
  static Future<ValidatedBackup> inspectBundleBytes(
    List<int> input, {
    required String sourceDescription,
  }) async {
    if (input.isEmpty) {
      throw const BackupValidationException('The selected backup is empty.');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(input, allowMalformed: false));
    } catch (_) {
      throw const BackupValidationException(
        'The selected file is not a readable Musify backup.',
      );
    }
    if (decoded is! Map) {
      throw const BackupValidationException('The backup root is invalid.');
    }
    final root = Map<String, dynamic>.from(decoded);
    final rawManifest = root['manifest'];
    final rawPayloads = root['payloads'];
    if (rawManifest is! Map || rawPayloads is! Map) {
      throw const BackupValidationException(
        'The backup is missing its manifest or payloads.',
      );
    }
    final manifest = Map<String, dynamic>.from(rawManifest);
    if (manifest['format'] != musifyBackupFormat) {
      throw const BackupValidationException(
        'This file is not a Musify Personalized backup.',
      );
    }
    if (manifest['schemaVersion'] != musifyBackupSchemaVersion) {
      throw BackupValidationException(
        'Unsupported backup schema ${manifest['schemaVersion']}.',
      );
    }
    final rawApp = manifest['app'];
    if (rawApp is! Map) {
      throw const BackupValidationException(
        'The backup manifest has no application identity.',
      );
    }
    final app = Map<String, dynamic>.from(rawApp);
    final sourcePackage = app['package'];
    final sourceChannel = app['channel'];
    final recognizedIdentity =
        (sourcePackage == _releasePackage && sourceChannel == 'production') ||
        (sourcePackage == _debugPackage && sourceChannel == 'debug');
    if (!recognizedIdentity) {
      throw BackupValidationException(
        'Unrecognized backup origin: $sourcePackage / $sourceChannel.',
      );
    }
    final manifestPayloads = manifest['payloads'];
    if (manifestPayloads is! Map) {
      throw const BackupValidationException(
        'The backup manifest has no payload inventory.',
      );
    }

    final payloads = <String, Uint8List>{};
    for (final boxName in _requiredBoxNames) {
      final payloadRecord = manifestPayloads[boxName];
      final encoded = rawPayloads['$boxName.hive'];
      if (payloadRecord is! Map || encoded is! String) {
        throw BackupValidationException(
          'The required $boxName database is missing.',
        );
      }
      Uint8List bytes;
      try {
        bytes = base64Decode(encoded);
      } catch (_) {
        throw BackupValidationException(
          'The $boxName database payload is not valid Base64.',
        );
      }
      if (bytes.isEmpty) {
        throw BackupValidationException('The $boxName database is empty.');
      }
      final record = Map<String, dynamic>.from(payloadRecord);
      final expectedLength = _readNonNegativeInt(
        record['byteLength'],
        '$boxName.byteLength',
      );
      if (bytes.length != expectedLength) {
        throw BackupValidationException(
          'The $boxName database size does not match its manifest.',
        );
      }
      final expectedChecksum = record['sha256'];
      if (expectedChecksum is! String ||
          sha256.convert(bytes).toString() != expectedChecksum) {
        throw BackupValidationException(
          'The $boxName database checksum failed.',
        );
      }
      payloads[boxName] = bytes;
    }

    final staging = await _newTemporaryDirectory('bundle-inspect');
    try {
      final snapshots = await _validatePayloadSet(payloads, staging);
      final actualSummary = _summaryFromSnapshots(snapshots);
      final manifestSummaryRaw = manifest['summary'];
      if (manifestSummaryRaw is! Map) {
        throw const BackupValidationException(
          'The backup manifest has no semantic summary.',
        );
      }
      final expectedSummary = BackupSummary.fromJson(
        Map<String, dynamic>.from(manifestSummaryRaw),
      );
      _requireMatchingSummary(expectedSummary, actualSummary);
      _requireMatchingBoxInventories(manifestPayloads, snapshots);
      return ValidatedBackup(
        payloads: payloads,
        summary: actualSummary,
        sourceDescription: sourceDescription,
        manifest: manifest,
      );
    } finally {
      await _deleteDirectoryQuietly(staging);
    }
  }

  static Future<BackupOperationResult> restoreValidatedBackup(
    ValidatedBackup backup, {
    @visibleForTesting int? simulateFailureAfterReplacements,
  }) async {
    if (_operationInProgress) {
      return const BackupOperationResult(
        success: false,
        message: 'Another backup or restore operation is already running.',
      );
    }
    _operationInProgress = true;
    Directory? staging;
    final targetPaths = <String, String>{};
    final rollbackBytes = <String, Uint8List>{};
    final preRestoreFiles = <String, File>{};
    File? journalFile;
    try {
      staging = await _newTemporaryDirectory('restore-transaction');
      final candidateSnapshots = await _validatePayloadSet(
        backup.payloads,
        staging,
      );
      _requireMatchingSummary(
        backup.summary,
        _summaryFromSnapshots(candidateSnapshots),
      );

      for (final boxName in _requiredBoxNames) {
        final box = await _openRequiredBox(boxName);
        await box.flush();
        final path = box.path;
        if (path == null) {
          throw BackupValidationException(
            'The active $boxName database has no file path.',
          );
        }
        targetPaths[boxName] = path;
        final currentFile = File(path);
        if (!await currentFile.exists()) {
          throw BackupValidationException(
            'The active $boxName database file is missing.',
          );
        }
        rollbackBytes[boxName] = Uint8List.fromList(
          await currentFile.readAsBytes(),
        );
      }

      // A rollback copy must itself be readable before live data is touched.
      final rollbackCheck = await _newTemporaryDirectory(
        'restore-rollback-check',
      );
      try {
        await _validatePayloadSet(rollbackBytes, rollbackCheck);
      } finally {
        await _deleteDirectoryQuietly(rollbackCheck);
      }

      final targetParents = targetPaths.values
          .map((path) => File(path).parent.path)
          .toSet();
      if (targetParents.length != 1) {
        throw const BackupValidationException(
          'The active databases are not stored in one recoverable location.',
        );
      }
      journalFile = File('${targetParents.single}/$_restoreJournalName');
      if (await journalFile.exists()) {
        throw const BackupValidationException(
          'An earlier restore journal still exists. Restart Musify before retrying.',
        );
      }
      await _writeRestoreJournal(journalFile, state: 'replacing');

      var replacements = 0;
      for (final boxName in _requiredBoxNames) {
        await Hive.box(boxName).close();
      }

      for (final boxName in _requiredBoxNames) {
        final target = File(targetPaths[boxName]!);
        final candidate = File('${target.path}.restore-candidate');
        final preRestore = File('${target.path}.pre-restore');
        if (await candidate.exists()) await candidate.delete();
        if (await preRestore.exists()) await preRestore.delete();
        await candidate.writeAsBytes(backup.payloads[boxName]!, flush: true);
        await target.rename(preRestore.path);
        preRestoreFiles[boxName] = preRestore;
        await candidate.rename(target.path);
        replacements++;
        if (simulateFailureAfterReplacements == replacements) {
          throw StateError('Simulated restore interruption.');
        }
      }

      final restoredSnapshots = <String, _BoxSnapshot>{};
      for (final boxName in _requiredBoxNames) {
        final box = await Hive.openBox(boxName);
        restoredSnapshots[boxName] = _snapshotOpenBox(boxName, box);
      }
      final restoredSummary = _summaryFromSnapshots(restoredSnapshots);
      _requireMatchingSummary(backup.summary, restoredSummary);
      _requireMatchingBoxInventories(
        backup.manifest['payloads'] as Map,
        restoredSnapshots,
      );

      await _writeRestoreJournal(journalFile, state: 'verified');
      for (final file in preRestoreFiles.values) {
        if (await file.exists()) await file.delete();
      }
      if (await journalFile.exists()) await journalFile.delete();
      return BackupOperationResult(
        success: true,
        message:
            'Restore verified from ${backup.sourceDescription}: '
            '${restoredSummary.compactDescription}.',
        summary: restoredSummary,
      );
    } catch (error, stackTrace) {
      _logError(
        'Restore failed; rolling back',
        error: error,
        stackTrace: stackTrace,
      );
      final rollbackError = await _rollBackRestore(
        targetPaths: targetPaths,
        rollbackBytes: rollbackBytes,
        journalFile: journalFile,
      );
      final reason = error is BackupValidationException
          ? error.message
          : error.toString();
      return BackupOperationResult(
        success: false,
        message: rollbackError == null
            ? 'Restore rejected; original data was restored. $reason'
            : 'Restore failed and automatic rollback also failed: '
                  '$reason; rollback: $rollbackError',
      );
    } finally {
      _operationInProgress = false;
      await _deleteDirectoryQuietly(staging);
    }
  }

  static Future<Box> _openRequiredBox(String name) async {
    return Hive.isBoxOpen(name) ? Hive.box(name) : Hive.openBox(name);
  }

  /// Repairs an interrupted two-box restore before Hive opens either box.
  ///
  /// A transaction without a `verified` journal is rolled back. A verified
  /// transaction is committed by deleting its preserved pre-restore files.
  static Future<void> recoverInterruptedRestoreIfNeeded() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    await recoverInterruptedRestoreInDirectory(appDirectory);
  }

  @visibleForTesting
  static Future<void> recoverInterruptedRestoreInDirectory(
    Directory directory,
  ) async {
    final journal = File('${directory.path}/$_restoreJournalName');
    var state = 'replacing';
    if (await journal.exists()) {
      try {
        final decoded = jsonDecode(await journal.readAsString());
        if (decoded is Map && decoded['state'] == 'verified') {
          state = 'verified';
        }
      } catch (_) {
        // A corrupt journal is unverified, so the only safe action is rollback.
      }
    }

    final preRestoreFiles = <String, File>{
      for (final boxName in _requiredBoxNames)
        boxName: File('${directory.path}/$boxName.hive.pre-restore'),
    };
    final hasInterruptedFiles = await Future.wait(
      preRestoreFiles.values.map((file) => file.exists()),
    ).then((values) => values.any((exists) => exists));
    if (!await journal.exists() && !hasInterruptedFiles) return;

    if (state == 'verified') {
      for (final boxName in _requiredBoxNames) {
        final preRestore = preRestoreFiles[boxName]!;
        final candidate = File(
          '${directory.path}/$boxName.hive.restore-candidate',
        );
        if (await preRestore.exists()) await preRestore.delete();
        if (await candidate.exists()) await candidate.delete();
      }
    } else {
      for (final boxName in _requiredBoxNames) {
        final target = File('${directory.path}/$boxName.hive');
        final preRestore = preRestoreFiles[boxName]!;
        final candidate = File(
          '${directory.path}/$boxName.hive.restore-candidate',
        );
        if (await preRestore.exists()) {
          if (await target.exists()) await target.delete();
          await preRestore.rename(target.path);
        }
        if (await candidate.exists()) await candidate.delete();
      }
    }
    if (await journal.exists()) await journal.delete();
  }

  static Future<Uint8List> _platformFileBytes(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return Uint8List.fromList(bytes);
    final path = file.path;
    if (path == null) {
      throw BackupValidationException('${file.name} could not be read.');
    }
    final source = File(path);
    if (!await source.exists()) {
      throw BackupValidationException('${file.name} no longer exists.');
    }
    return Uint8List.fromList(await source.readAsBytes());
  }

  static Map<String, dynamic> _buildManifest(
    Map<String, Uint8List> payloads,
    Map<String, _BoxSnapshot> snapshots,
    BackupSummary summary,
  ) {
    final payloadManifest = <String, dynamic>{};
    for (final boxName in _requiredBoxNames) {
      final bytes = payloads[boxName]!;
      final snapshot = snapshots[boxName]!;
      payloadManifest[boxName] = {
        'fileName': '$boxName.hive',
        'byteLength': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
        'keys': snapshot.keys,
        'keyTypes': snapshot.keyTypes,
      };
    }
    return {
      'format': musifyBackupFormat,
      'schemaVersion': musifyBackupSchemaVersion,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'app': {
        'package': kDebugMode ? _debugPackage : _releasePackage,
        'channel': kDebugMode ? 'debug' : 'production',
        'version': appVersion,
        'gitSha': _gitSha,
      },
      'payloads': payloadManifest,
      'summary': summary.toJson(),
    };
  }

  static Uint8List _encodeBundle(
    Map<String, dynamic> manifest,
    Map<String, Uint8List> payloads,
  ) {
    final root = {
      'manifest': manifest,
      'payloads': {
        for (final boxName in _requiredBoxNames)
          '$boxName.hive': base64Encode(payloads[boxName]!),
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(root)));
  }

  static Future<Map<String, _BoxSnapshot>> _validatePayloadSet(
    Map<String, Uint8List> payloads,
    Directory directory,
  ) async {
    if (payloads.length != _requiredBoxNames.length ||
        !_requiredBoxNames.every(payloads.containsKey)) {
      throw const BackupValidationException(
        'Both user and settings databases are required.',
      );
    }
    final snapshots = <String, _BoxSnapshot>{};
    for (final boxName in _requiredBoxNames) {
      final bytes = payloads[boxName]!;
      if (bytes.isEmpty) {
        throw BackupValidationException('The $boxName database is empty.');
      }
      final uniqueName =
          'verify_${boxName}_${DateTime.now().microsecondsSinceEpoch}';
      final file = File('${directory.path}/$uniqueName.hive');
      await file.writeAsBytes(bytes, flush: true);
      Box? box;
      try {
        box = await Hive.openBox(uniqueName, path: directory.path);
        snapshots[boxName] = _snapshotOpenBox(boxName, box);
      } catch (error) {
        throw BackupValidationException(
          'The $boxName database cannot be opened as a Hive database: $error',
        );
      } finally {
        await box?.close();
        try {
          await Hive.deleteBoxFromDisk(uniqueName, path: directory.path);
        } catch (_) {
          if (await file.exists()) await file.delete();
        }
      }
    }
    return snapshots;
  }

  static _BoxSnapshot _snapshotOpenBox(String logicalName, Box box) {
    final keys = box.keys.map((key) => key.toString()).toList()..sort();
    final keyTypes = <String, String>{};
    for (final key in box.keys) {
      keyTypes[key.toString()] = _stableValueType(box.get(key));
    }
    final counts = <String, int>{};
    if (logicalName == 'user') {
      final imported = _asList(box.get('spotifyImportTracks'));
      final matches = _asList(box.get('spotifyMatchResults'));
      counts['importedTracks'] = imported.length;
      counts['matchResults'] = matches.length;
      counts['favorites'] = _asList(box.get('likedSongs')).length;
      counts['playlists'] =
          _asList(box.get('playlists')).length +
          _asList(box.get('customPlaylists')).length;
      var strong = 0;
      var review = 0;
      var unmatched = 0;
      var errors = 0;
      for (final item in matches) {
        if (item is! Map) continue;
        switch (item['status']?.toString()) {
          case 'matched':
          case 'manually_matched':
            strong++;
            break;
          case 'needs_review':
            review++;
            break;
          case 'unmatched':
          case 'manual_unmatched':
            unmatched++;
            break;
          case 'error':
            errors++;
            break;
        }
      }
      if (strong + review + unmatched + errors != matches.length) {
        throw const BackupValidationException(
          'The matching database contains an unrecognized or malformed result.',
        );
      }
      counts['strongMatches'] = strong;
      counts['reviewItems'] = review;
      counts['unmatchedItems'] = unmatched;
      counts['errorItems'] = errors;
    }
    return _BoxSnapshot(keys: keys, keyTypes: keyTypes, counts: counts);
  }

  static BackupSummary _summaryFromSnapshots(
    Map<String, _BoxSnapshot> snapshots,
  ) {
    final user = snapshots['user'];
    final settings = snapshots['settings'];
    if (user == null || settings == null) {
      throw const BackupValidationException(
        'The validated backup is missing required database summaries.',
      );
    }
    int count(String key) => user.counts[key] ?? 0;
    return BackupSummary(
      importedTracks: count('importedTracks'),
      matchResults: count('matchResults'),
      strongMatches: count('strongMatches'),
      reviewItems: count('reviewItems'),
      unmatchedItems: count('unmatchedItems'),
      errorItems: count('errorItems'),
      favorites: count('favorites'),
      playlists: count('playlists'),
      userKeys: user.keys.length,
      settingsKeys: settings.keys.length,
    );
  }

  static void _requireMatchingSummary(
    BackupSummary expected,
    BackupSummary actual,
  ) {
    final expectedJson = expected.toJson();
    final actualJson = actual.toJson();
    for (final entry in expectedJson.entries) {
      if (actualJson[entry.key] != entry.value) {
        throw BackupValidationException(
          'Backup count mismatch for ${entry.key}: expected ${entry.value}, '
          'found ${actualJson[entry.key]}.',
        );
      }
    }
  }

  static void _requireMatchingBoxInventories(
    Map manifestPayloads,
    Map<String, _BoxSnapshot> snapshots,
  ) {
    for (final boxName in _requiredBoxNames) {
      final rawRecord = manifestPayloads[boxName];
      if (rawRecord is! Map) {
        throw BackupValidationException(
          'The manifest is missing the $boxName inventory.',
        );
      }
      final record = Map<String, dynamic>.from(rawRecord);
      final rawKeys = record['keys'];
      final rawTypes = record['keyTypes'];
      if (rawKeys is! List || rawTypes is! Map) {
        throw BackupValidationException(
          'The $boxName key inventory is invalid.',
        );
      }
      final expectedKeys = rawKeys.map((key) => key.toString()).toList()..sort();
      final actual = snapshots[boxName]!;
      if (!listEquals(expectedKeys, actual.keys)) {
        throw BackupValidationException(
          'The $boxName database keys do not match the manifest.',
        );
      }
      for (final key in expectedKeys) {
        if (rawTypes[key]?.toString() != actual.keyTypes[key]) {
          throw BackupValidationException(
            'The $boxName database type for $key does not match the manifest.',
          );
        }
      }
    }
  }

  static Future<String?> _rollBackRestore({
    required Map<String, String> targetPaths,
    required Map<String, Uint8List> rollbackBytes,
    required File? journalFile,
  }) async {
    try {
      for (final boxName in _requiredBoxNames) {
        if (Hive.isBoxOpen(boxName)) await Hive.box(boxName).close();
      }
      for (final boxName in _requiredBoxNames) {
        final path = targetPaths[boxName];
        final bytes = rollbackBytes[boxName];
        if (path == null || bytes == null) continue;
        final target = File(path);
        final candidate = File('$path.restore-candidate');
        final preRestore = File('$path.pre-restore');
        if (await target.exists()) await target.delete();
        await target.writeAsBytes(bytes, flush: true);
        if (await candidate.exists()) await candidate.delete();
        if (await preRestore.exists()) await preRestore.delete();
      }
      for (final boxName in _requiredBoxNames) {
        await Hive.openBox(boxName);
      }
      if (journalFile != null && await journalFile.exists()) {
        await journalFile.delete();
      }
      return null;
    } catch (error, stackTrace) {
      _logError(
        'Automatic restore rollback failed',
        error: error,
        stackTrace: stackTrace,
      );
      return error.toString();
    }
  }

  static Future<Directory> _newTemporaryDirectory(String purpose) async {
    return Directory.systemTemp.createTemp('musify-$purpose-');
  }

  static Future<void> _deleteDirectoryQuietly(Directory? directory) async {
    if (directory == null) return;
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (error, stackTrace) {
      _logError(
        'Failed to delete temporary backup directory',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static bool _legacyNameMatches(String name, String boxName) {
    return RegExp('^$boxName(?:_[0-9]+)?[.]hive\$').hasMatch(name);
  }

  static String _fileTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }

  static List _asList(dynamic value) => value is List ? value : const [];
}

String _stableValueType(dynamic value) {
  if (value == null) return 'null';
  if (value is bool) return 'bool';
  if (value is int) return 'int';
  if (value is double) return 'double';
  if (value is String) return 'string';
  if (value is DateTime) return 'datetime';
  if (value is Uint8List) return 'bytes';
  if (value is List) return 'list';
  if (value is Map) return 'map';
  return 'unsupported:${value.runtimeType}';
}

Future<void> _writeRestoreJournal(File file, {required String state}) async {
  await file.writeAsString(
    jsonEncode({
      'format': 'musify-restore-transaction',
      'version': 1,
      'state': state,
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    }),
    flush: true,
  );
}

void _logError(
  String location, {
  required Object error,
  required StackTrace stackTrace,
}) {
  debugPrint('$location: $error\n$stackTrace');
}

class _BoxSnapshot {
  const _BoxSnapshot({
    required this.keys,
    required this.keyTypes,
    required this.counts,
  });

  final List<String> keys;
  final Map<String, String> keyTypes;
  final Map<String, int> counts;
}

int _readNonNegativeInt(dynamic value, String field) {
  if (value is! int || value < 0) {
    throw BackupValidationException('Invalid non-negative count for $field.');
  }
  return value;
}
