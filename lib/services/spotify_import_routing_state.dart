import 'dart:convert';

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
  ResolvedImportRecordings(this.rows, this.reliable);
  final List<Map<String, String>> rows;
  final bool reliable;
  String get fingerprint => jsonEncode(rows);
}

ResolvedImportRecordings resolvedImportRecordings(
  Iterable<Map<String, dynamic>> results,
) {
  final rows = <String, Map<String, String>>{};
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
  return ResolvedImportRecordings(
    List.unmodifiable(
      ordered.map((entry) => Map<String, String>.unmodifiable(entry.value)),
    ),
    reliable,
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
