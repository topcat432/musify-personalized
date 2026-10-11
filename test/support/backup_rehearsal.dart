import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';

// Manual tool: flutter test test/support/backup_rehearsal.dart
// Without an input, creates only synthetic data under ignored build/.
// MUSIFY_BACKUP_FILE inspects an explicitly exported document; optional
// MUSIFY_BACKUP_COMPARE compares its keyed values with a second export.
// No device, live Hive database or source file is modified by this tool.
void main() {
  test(
    'generate synthetic fixture or inspect exported backup semantics',
    () async {
      final temp = await Directory.systemTemp.createTemp('musify-rehearsal-');
      Hive.init(temp.path);
      try {
        final input = Platform.environment['MUSIFY_BACKUP_FILE'];
        if (input == null) {
          final songs = List<Map<String, dynamic>>.generate(
            2,
            (i) => {
              'ytid': 'synthetic-song-${i + 1}',
              'title': 'Synthetic recording ${i + 1}',
              'artist': 'Synthetic artist',
              'image': '',
              'duration': 180,
            },
          );
          final user = await Hive.openBox('fixture_user');
          await user.putAll({
            'likedSongs': songs,
            'playlists': <String>[],
            'customPlaylists': [
              {
                'ytid': 'synthetic-playlist',
                'title': 'Synthetic rehearsal playlist',
                'source': 'user-created',
                'image': '',
                'list': songs.reversed.toList(),
              },
            ],
            'spotifyImportTracks': List.generate(
              5,
              (i) => {'sourceRow': i + 2, 'title': 'Synthetic import $i'},
            ),
            'spotifyMatchResults': [
              {'sourceRow': 2, 'status': 'matched'},
              {'sourceRow': 3, 'status': 'matched'},
              {'sourceRow': 4, 'status': 'needs_review'},
              {'sourceRow': 5, 'status': 'unmatched'},
              {
                'sourceRow': 6,
                'status': 'excluded',
                'reviewDecision': 'excluded_from_import',
              },
            ],
            'rehearsalSentinel': 'synthetic-data-only',
          });
          final settings = await Hive.openBox('fixture_settings');
          await settings.putAll({
            'themeIndex': 2,
            'wrappedEnabled': true,
            'autoCheckForUpdates': false,
            'rehearsalSentinel': 'synthetic-settings-only',
          });
          await user.flush();
          await settings.flush();
          final payloads = {
            'user': Uint8List.fromList(await File(user.path!).readAsBytes()),
            'settings': Uint8List.fromList(
              await File(settings.path!).readAsBytes(),
            ),
          };
          await Hive.close();
          final bytes = await MusifyBackupService.createBundleBytesForTesting(
            payloads,
          );
          final bundle = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          // Deliberately reproduce the known legacy metadata for compatibility
          // rehearsal with the preserved installed APK, without claiming an
          // actual source device or production build supplied this synthetic data.
          (bundle['manifest'] as Map)['app'] = {
            'package': 'com.topcat432.musifypersonalized',
            'channel': 'production',
            'version': 'synthetic-rehearsal',
            'gitSha': 'synthetic-fixture',
          };
          final out = Directory('build/backup-rehearsal');
          await out.create(recursive: true);
          final fixture = File('${out.path}/synthetic-rehearsal.musifybackup');
          await fixture.writeAsString(jsonEncode(bundle), flush: true);
          final proof = await _inspect(fixture, temp, 'fixture');
          expect((proof['summary'] as Map)['importedTracks'], 5);
          expect((proof['summary'] as Map)['excludedItems'], 1);
          expect((proof['summary'] as Map)['favorites'], 2);
          await File(
            '${out.path}/synthetic-proof.json',
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(proof));
          // Only path, counts and hashes are printed; no song/personal values.
          debugPrint(jsonEncode(proof));
        } else {
          final proof = await _inspect(File(input), temp, 'first');
          final comparison = Platform.environment['MUSIFY_BACKUP_COMPARE'];
          if (comparison != null) {
            final second = await _inspect(File(comparison), temp, 'second');
            expect(second['semanticSha256'], proof['semanticSha256']);
            proof['semanticComparisonPassed'] = true;
            proof['comparisonFileSha256'] = second['fileSha256'];
          }
          debugPrint(jsonEncode(proof));
        }
      } finally {
        await Hive.close();
        await temp.delete(recursive: true);
      }
    },
  );
}

Future<Map<String, dynamic>> _inspect(
  File file,
  Directory temp,
  String prefix,
) async {
  final bytes = await file.readAsBytes();
  final backup = await MusifyBackupService.inspectBundleBytes(
    bytes,
    sourceDescription: file.uri.pathSegments.last,
  );
  final values = <String, dynamic>{};
  for (final entry in backup.payloads.entries) {
    final name = '${prefix}_${entry.key}';
    await File('${temp.path}/$name.hive').writeAsBytes(entry.value);
    final box = await Hive.openBox(name, path: temp.path);
    values[entry.key] = {for (final key in box.keys) key: box.get(key)};
    await box.close();
  }
  return {
    'file': file.uri.pathSegments.last,
    'bytes': bytes.length,
    'fileSha256': sha256.convert(bytes).toString(),
    'summary': backup.summary.toJson(),
    'semanticSha256': sha256
        .convert(utf8.encode(jsonEncode(_canonical(values))))
        .toString(),
    'structuralChecksumInventoryValidationPassed': true,
    'deviceOrLiveDataModified': false,
  };
}

dynamic _canonical(dynamic value) {
  if (value is Uint8List) return ['bytes', base64Encode(value)];
  if (value is DateTime) return ['datetime', value.toIso8601String()];
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => [_canonical(entry.key), _canonical(entry.value)])
            .toList()
          ..sort((a, b) => jsonEncode(a[0]).compareTo(jsonEncode(b[0])));
    return ['map', entries];
  }
  if (value is List) return ['list', value.map(_canonical).toList()];
  return [value.runtimeType.toString(), value];
}
