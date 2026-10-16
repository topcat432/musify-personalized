import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

enum OfflineAudioState {
  ready,
  missing,
  empty,
  invalidProof,
  wrongLength,
  wrongChecksum,
  unreadable,
}

String _pathKey(String value) =>
    Platform.isWindows ? value.replaceAll('\\', '/').toLowerCase() : value;

class OfflineAudioCheck {
  const OfflineAudioCheck(this.state, this.path, {this.hasProof = false});
  final OfflineAudioState state;
  final String? path;
  final bool hasProof;
  bool get playable => state == OfflineAudioState.ready;
}

/// Read-only compatibility check. Legacy positive files have unknown integrity;
/// a supplied length/checksum pair or retained matching marker must be honored.
/// No bad row, payload or marker is deleted, rewritten, adopted or downloaded.
Future<OfflineAudioCheck> checkOfflineAudio(
  Map row, {
  String? fallbackPath,
  bool verifyChecksum = true,
}) async {
  final path = row['audioPath'] is String
      ? row['audioPath'] as String
      : fallbackPath;
  if (path == null || path.isEmpty)
    return OfflineAudioCheck(OfflineAudioState.missing, path);
  try {
    final file = File(path);
    if (!await file.exists())
      return OfflineAudioCheck(OfflineAudioState.missing, path);
    final actual = await file.length();
    if (actual == 0) return OfflineAudioCheck(OfflineAudioState.empty, path);
    dynamic bytes = row['offlineAudioBytes'];
    dynamic digest = row['offlineAudioSha256'];
    var proof =
        row.containsKey('offlineAudioBytes') ||
        row.containsKey('offlineAudioSha256');
    if (!proof) {
      final prefix = '${_pathKey(file.path)}.download-';
      await for (final entry in file.parent.list(followLinks: false)) {
        if (entry is! File ||
            !_pathKey(entry.path).startsWith(prefix) ||
            !entry.path.endsWith('.part.owner.json'))
          continue;
        if (await entry.length() > 16384) continue;
        Map? marker;
        try {
          final decoded = jsonDecode(await entry.readAsString());
          if (decoded is Map) marker = decoded;
        } catch (_) {
          continue;
        }
        if (marker == null ||
            marker['schema'] != 1 ||
            marker['ytid'] != row['ytid'] ||
            marker['audioPath'] is! String ||
            _pathKey(marker['audioPath']) != _pathKey(path) ||
            _pathKey('${marker['partialPath']}.owner.json') !=
                _pathKey(entry.path))
          continue;
        final partial = marker['partialPath'];
        if (partial is! String ||
            !_pathKey(partial).startsWith(prefix) ||
            !partial.endsWith('.part') ||
            !RegExp(r'^\d+$').hasMatch(
              _pathKey(partial).substring(prefix.length, partial.length - 5),
            ))
          continue;
        if (proof &&
            (bytes != marker['expectedBytes'] || digest != marker['sha256']))
          return OfflineAudioCheck(
            OfflineAudioState.invalidProof,
            path,
            hasProof: true,
          );
        proof = true;
        bytes = marker['expectedBytes'];
        digest = marker['sha256'];
      }
    }
    if (!proof) return OfflineAudioCheck(OfflineAudioState.ready, path);
    if (bytes is! int ||
        bytes <= 0 ||
        bytes > 2147483648 ||
        digest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest))
      return OfflineAudioCheck(
        OfflineAudioState.invalidProof,
        path,
        hasProof: true,
      );
    if (actual != bytes)
      return OfflineAudioCheck(
        OfflineAudioState.wrongLength,
        path,
        hasProof: true,
      );
    if (verifyChecksum &&
        (await sha256.bind(file.openRead()).first).toString() != digest)
      return OfflineAudioCheck(
        OfflineAudioState.wrongChecksum,
        path,
        hasProof: true,
      );
    return OfflineAudioCheck(OfflineAudioState.ready, path, hasProof: true);
  } catch (_) {
    return OfflineAudioCheck(OfflineAudioState.unreadable, path);
  }
}

/// append opens without truncating; RandomAccessFile.flush requests a file-level
/// OS flush. This does not promise directory-entry or whole-device power safety.
Future<void> flushOfflineFile(File file) async {
  final handle = await file.open(mode: FileMode.append);
  try {
    await handle.flush();
  } finally {
    await handle.close();
  }
}
