import 'dart:convert';
import 'dart:typed_data';

const importRoutingBaselineKey = 'routingResolutionBaseline';
const importRoutingPendingKey = 'routingInProgress';
const importRoutingUnverifiedHistoryKey = 'routingUnverifiedHistory';
const importRoutingStateVersion = 1;

String importSessionIdentity(Map<String, dynamic> metadata) {
  for (final key in ['importSessionId', 'importedAt', 'fileName']) {
    final value = metadata[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

bool hasStableImportSessionIdentity(Map<String, dynamic> metadata) =>
    (metadata['importSessionId']?.toString().trim().isNotEmpty ?? false) ||
    DateTime.tryParse(metadata['importedAt']?.toString() ?? '') != null;

Object? copyImportRoutingValue(dynamic value) {
  if (value is Uint8List) return Uint8List.fromList(value);
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key: copyImportRoutingValue(entry.value),
    };
  }
  if (value is List) return value.map(copyImportRoutingValue).toList();
  return value;
}

/// Matching/review checkpoints must not resurrect an older routing snapshot.
void preserveCurrentImportRoutingState(
  Map<String, dynamic> updated,
  Map<String, dynamic> current,
) {
  if (importSessionIdentity(updated) != importSessionIdentity(current)) {
    throw StateError('The import changed before this checkpoint was saved.');
  }
  for (final key in [
    'routingHistory',
    importRoutingBaselineKey,
    importRoutingPendingKey,
    importRoutingUnverifiedHistoryKey,
  ]) {
    if (current.containsKey(key)) {
      updated[key] = copyImportRoutingValue(current[key]);
    } else {
      updated.remove(key);
    }
  }
}

String? importRecordingRow(dynamic raw) {
  if (raw is num && raw.isFinite && raw > 0 && raw == raw.toInt()) {
    return raw.toInt().toString();
  }
  if (raw is String) {
    final row = int.tryParse(raw.trim());
    if (row != null && row > 0) return row.toString();
  }
  return null;
}

String importRecordingIdentity(Map<String, String> row) =>
    jsonEncode([row['sourceRow'], row['recordingId']]);

class ResolvedImportRecordings {
  ResolvedImportRecordings(this.rows, this.reliable, {String? liveFingerprint})
    : fingerprint = liveFingerprint ?? jsonEncode(rows);
  final List<Map<String, String>> rows;
  final bool reliable;
  final String fingerprint;
}

ResolvedImportRecordings resolvedImportRecordings(
  Iterable<Map<String, dynamic>> results,
) {
  final rows = <String, Map<String, String>>{};
  final liveRows = <Map<String, String?>>[];
  final sourceChoices = <String, String>{};
  var reliable = true;
  for (final result in results) {
    if (result['status'] != 'matched' && result['status'] != 'manually_matched')
      continue;
    final candidate = result['bestCandidate'];
    final row = importRecordingRow(result['sourceRow']);
    final recording = candidate is Map && candidate['ytid'] is String
        ? (candidate['ytid'] as String).trim()
        : '';
    // Unknown historical row positions remain unsuitable for a durable
    // identity baseline, but must still participate in live stale checks.
    // Otherwise exclusion or a changed choice during the pending write could
    // route an obsolete legacy recording.
    liveRows.add({
      'sourceRow': row,
      'status': result['status']?.toString(),
      'recordingId': candidate is Map
          ? candidate['ytid']?.toString().trim()
          : null,
    });
    if (row == null || recording.isEmpty) {
      reliable = false;
      continue;
    }
    if (sourceChoices.containsKey(row) && sourceChoices[row] != recording)
      reliable = false;
    sourceChoices[row] = recording;
    final value = {'sourceRow': row, 'recordingId': recording};
    rows[importRecordingIdentity(value)] = value;
  }
  final ordered = rows.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  if (reliable) {
    liveRows.sort((left, right) {
      final byRow = int.parse(
        left['sourceRow']!,
      ).compareTo(int.parse(right['sourceRow']!));
      if (byRow != 0) return byRow;
      return jsonEncode(left).compareTo(jsonEncode(right));
    });
  }
  return ResolvedImportRecordings(
    List.unmodifiable(
      ordered.map((entry) => Map<String, String>.unmodifiable(entry.value)),
    ),
    reliable,
    liveFingerprint: jsonEncode(liveRows),
  );
}

Map<String, dynamic> importRoutingBaseline({
  required String sessionId,
  required Iterable<Map<String, String>> rows,
  required String recordedAt,
  required bool reliable,
  required String reason,
}) => {
  'version': importRoutingStateVersion,
  'importSessionId': sessionId,
  'recordedAt': recordedAt,
  'reason': reason,
  'reliable': reliable,
  'resolvedRecordings': rows.map(Map<String, String>.from).toList(),
};

Set<String>? readImportRoutingBaseline(
  Map<String, dynamic> metadata,
  String sessionId,
) {
  if (metadata.containsKey(importRoutingPendingKey)) return null;
  final value = metadata[importRoutingBaselineKey];
  if (value is! Map ||
      value['version'] != importRoutingStateVersion ||
      value['importSessionId'] != sessionId ||
      value['reliable'] != true ||
      !hasStableImportSessionIdentity(metadata) ||
      value['resolvedRecordings'] is! List)
    return null;
  final identities = <String>{};
  final choices = <String, String>{};
  for (final raw in value['resolvedRecordings'] as List) {
    if (raw is! Map ||
        raw['sourceRow'] is! String ||
        raw['recordingId'] is! String)
      return null;
    final row = importRecordingRow(raw['sourceRow']);
    final recording = (raw['recordingId'] as String).trim();
    if (row == null ||
        recording.isEmpty ||
        (choices.containsKey(row) && choices[row] != recording))
      return null;
    choices[row] = recording;
    identities.add(
      importRecordingIdentity({'sourceRow': row, 'recordingId': recording}),
    );
  }
  return identities;
}
