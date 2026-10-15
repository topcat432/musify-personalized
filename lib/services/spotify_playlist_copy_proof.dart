import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Additive facts for an explicitly created copy, never legacy ownership or
/// per-song synchronization tags. Callers retain malformed/unknown raw evidence.
class SpotifyPlaylistCopyProof {
  const SpotifyPlaylistCopyProof._(this.operationId, this.destinationId,
      this.sessionId, this.sourceKey, this.sourceFingerprint,
      this.recordingFingerprint, this.slotCount, this.uniqueRecordingCount);

  static const markerKey = 'importSourceCopyProof';
  static const journalKey = 'copyProof';
  static const action = 'create_source_playlist_copy';
  final String operationId, destinationId, sessionId, sourceKey;
  final String sourceFingerprint, recordingFingerprint;
  final int slotCount, uniqueRecordingCount;

  factory SpotifyPlaylistCopyProof.create({
    required String operationId, required String destinationId,
    required String sessionId, required String sourceKey,
    required String sourceFingerprint, required List<String> recordingIds,
  }) => SpotifyPlaylistCopyProof.decode({
    'version': 1, 'operationId': operationId, 'destinationId': destinationId,
    'sessionId': sessionId, 'sourceKey': sourceKey,
    'sourceFingerprint': sourceFingerprint,
    'recordingFingerprint': fingerprint(recordingIds),
    'slotCount': recordingIds.length,
    'uniqueRecordingCount': recordingIds.toSet().length,
  });

  static Never _fail() => throw const FormatException(
    'Source-copy ownership is unverified. Existing data and proof were retained.',
  );
  static bool _id(Object? value, [int bound = 2048]) => value is String &&
      value.isNotEmpty && value.length <= bound && value.trim() == value &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);
  static bool _hash(Object? value) => value is String &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
  static String fingerprint(List<String> recordings) {
    if (recordings.isEmpty || recordings.length > 10000 ||
        recordings.any((id) => !_id(id))) _fail();
    return sha256.convert(utf8.encode(jsonEncode(recordings))).toString();
  }

  static SpotifyPlaylistCopyProof decode(Object? raw) {
    const keys = {'version', 'operationId', 'destinationId', 'sessionId',
      'sourceKey', 'sourceFingerprint', 'recordingFingerprint', 'slotCount',
      'uniqueRecordingCount'};
    if (raw is! Map || raw.length != keys.length ||
        raw.keys.any((key) => !keys.contains(key)) ||
        raw['version'] is! int || raw['version'] != 1 ||
        !_id(raw['operationId']) || !_id(raw['destinationId']) ||
        !_id(raw['sessionId']) || !_id(raw['sourceKey'], 4096) ||
        !_hash(raw['sourceFingerprint']) || !_hash(raw['recordingFingerprint']) ||
        raw['slotCount'] is! int || raw['slotCount'] < 1 || raw['slotCount'] > 10000 ||
        raw['uniqueRecordingCount'] is! int || raw['uniqueRecordingCount'] < 1 ||
        raw['uniqueRecordingCount'] > raw['slotCount']) _fail();
    return SpotifyPlaylistCopyProof._(raw['operationId'] as String,
      raw['destinationId'] as String, raw['sessionId'] as String,
      raw['sourceKey'] as String, raw['sourceFingerprint'] as String,
      raw['recordingFingerprint'] as String, raw['slotCount'] as int,
      raw['uniqueRecordingCount'] as int);
  }

  Map<String, dynamic> encode() => {
    'version': 1, 'operationId': operationId, 'destinationId': destinationId,
    'sessionId': sessionId, 'sourceKey': sourceKey,
    'sourceFingerprint': sourceFingerprint,
    'recordingFingerprint': recordingFingerprint, 'slotCount': slotCount,
    'uniqueRecordingCount': uniqueRecordingCount,
  };
  bool matches(SpotifyPlaylistCopyProof other) =>
      jsonEncode(encode()) == jsonEncode(other.encode());
}

enum SpotifyPlaylistCopyRecovery {
  targetMissing, unknownOwnership, invalidProof, ambiguousOwnership,
  sourceChanged, editedPendingDestination, recoverAuditOnly, completedNoOp,
}

/// Pure classification only. A marker alone, equal name/count/recording IDs or
/// missing destination can never authorize adoption, list writes or recreation.
SpotifyPlaylistCopyRecovery classifySpotifyPlaylistCopy({
  required SpotifyPlaylistCopyProof proof, required bool completed,
  required List<Map> destinations, required String sessionId,
  required String sourceKey, required String sourceFingerprint,
  required String recordingFingerprint,
}) {
  if (destinations.length > 10000) return SpotifyPlaylistCopyRecovery.invalidProof;
  final targets = <Map>[];
  var relatedMarkers = 0;
  for (final destination in destinations) {
    final raw = destination[SpotifyPlaylistCopyProof.markerKey];
    final target = destination['ytid'] == proof.destinationId;
    final related = raw is Map && (raw['operationId'] == proof.operationId ||
        raw['destinationId'] == proof.destinationId);
    if (target) targets.add(destination);
    if (!related && !target) continue;
    if (!destination.containsKey(SpotifyPlaylistCopyProof.markerKey)) {
      if (target) return SpotifyPlaylistCopyRecovery.unknownOwnership;
      continue;
    }
    SpotifyPlaylistCopyProof marker;
    try { marker = SpotifyPlaylistCopyProof.decode(raw); }
    on FormatException { return SpotifyPlaylistCopyRecovery.invalidProof; }
    if (related) relatedMarkers++;
    if (!marker.matches(proof) || destination['ytid'] != proof.destinationId ||
        destination['source'] != 'user-created') {
      return SpotifyPlaylistCopyRecovery.ambiguousOwnership;
    }
  }
  if (targets.length > 1 || relatedMarkers > 1)
    return SpotifyPlaylistCopyRecovery.ambiguousOwnership;
  if (targets.isEmpty) return SpotifyPlaylistCopyRecovery.targetMissing;
  if (relatedMarkers != 1) return SpotifyPlaylistCopyRecovery.unknownOwnership;
  if (proof.sessionId != sessionId || proof.sourceKey != sourceKey ||
      proof.sourceFingerprint != sourceFingerprint ||
      proof.recordingFingerprint != recordingFingerprint) {
    return SpotifyPlaylistCopyRecovery.sourceChanged;
  }
  final songs = targets.single['list'];
  if (songs is! List || songs.length > 10000 || songs.any((song) =>
      song is! Map || !SpotifyPlaylistCopyProof._id(song['ytid']))) {
    return SpotifyPlaylistCopyRecovery.invalidProof;
  }
  // Later edits belong to the owner. Completed retries never inspect/rewrite
  // their content against the old snapshot. Empty/manual/reordered lists survive.
  if (completed) return SpotifyPlaylistCopyRecovery.completedNoOp;
  final ids = songs.map((song) => (song as Map)['ytid'] as String).toList();
  if (ids.isEmpty || ids.length != proof.slotCount ||
      ids.toSet().length != proof.uniqueRecordingCount ||
      SpotifyPlaylistCopyProof.fingerprint(ids) != proof.recordingFingerprint) {
    return SpotifyPlaylistCopyRecovery.editedPendingDestination;
  }
  return SpotifyPlaylistCopyRecovery.recoverAuditOnly;
}
