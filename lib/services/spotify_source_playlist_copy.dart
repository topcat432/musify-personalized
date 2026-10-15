part of 'spotify_import_destination_service.dart';

class SpotifyPlaylistCopyPreview {
  SpotifyPlaylistCopyPreview._(this._snapshot, this.proof, this.title,
      this.songs, this._metadata, this._library, this._presence,
      this.existingCompleted, this.recoveringPending);
  final SpotifyImportDestinationSnapshot _snapshot;
  final SpotifyPlaylistCopyProof proof;
  final String title;
  final List<Map<String, dynamic>> songs;
  final Map<String, dynamic> _metadata;
  final Map<String, List<dynamic>> _library;
  final Map<String, bool> _presence;
  final bool existingCompleted, recoveringPending;
  String get sourceName => _snapshot.sourceName;
  int get slotCount => proof.slotCount;
  int get uniqueRecordingCount => proof.uniqueRecordingCount;
}

class SpotifyPlaylistCopyResult {
  const SpotifyPlaylistCopyResult({required this.destinationId,
    required this.destinationTitle, required this.slotCount,
    required this.uniqueRecordingCount, required this.created,
    required this.trackingRecorded});
  final String destinationId, destinationTitle;
  final int slotCount, uniqueRecordingCount;
  final bool created, trackingRecorded;
}

extension SpotifySourcePlaylistCopies on SpotifyImportDestinationService {
  Future<SpotifyPlaylistCopyPreview> _previewSourcePlaylistCopy(int position,
      {String? title, bool additionalCopy = false}) async {
    if (SpotifyImportDestinationService._routingActive) throw StateError('Another transfer is running. Wait for it to finish.');
    final snapshot = await loadSourcePlaylistSnapshot(position);
    _validateCurrentSnapshot(snapshot, requireWholeSource: true);
    final box = Hive.box('user');
    final metadata = _copyMetadata(box);
    final library = _storedCopyCollections(box);
    if (!_sameCopyValue(library, _liveCopyCollections())) _copyRefuse();
    final sources = SpotifySourcePlaylistCodec.readSaved(metadata[SpotifySourcePlaylistCodec.metadataKey], box.get('spotifyImportTracks'));
    final plan = SpotifySourceOccurrencePlan.preview(sources: sources, position: position,
      tracks: SpotifyImportDestinationService._readMaps(box.get('spotifyImportTracks')), snapshot: snapshot,
      destinationId: 'source-copy-preview', targetExists: false, destination: const []);
    if (!plan.canPropose || !plan.wouldMatchSourceOrder || plan.occurrences.isEmpty) _copyRefuse();
    final byId = {for (final song in snapshot.resolvedSongs) song['ytid'] as String: song};
    final songs = List<Map<String, dynamic>>.unmodifiable([
      for (final occurrence in plan.occurrences) _frozenCopySong(byId[occurrence.recordingId]!),
    ]);
    final ids = songs.map((song) => song['ytid'] as String).toList();
    final fingerprint = SpotifyPlaylistCopyProof.fingerprint(ids);
    final history = _copyHistory(metadata);
    SpotifyPlaylistCopyProof? prior;
    var completed = false;
    final pending = metadata[importRoutingPendingKey];
    if (metadata.containsKey(importRoutingPendingKey)) {
      if (additionalCopy) throw StateError('An earlier copy is still unverified. Review that attempt before creating another copy.');
      prior = _decodeCopyEnvelope(pending, completed: false);
    } else if (!additionalCopy) {
      for (final entry in history.reversed) {
        if (entry['action'] != SpotifyPlaylistCopyProof.action) continue;
        final candidate = _decodeCopyEnvelope(entry, completed: true);
        if (candidate.sessionId == snapshot.importSessionId &&
            candidate.sourceKey == plan.sourceKey && candidate.sourceFingerprint == plan.sourceFingerprint &&
            candidate.recordingFingerprint == fingerprint) {
          prior = candidate; completed = true; break;
        }
      }
    }
    final proof = prior ?? SpotifyPlaylistCopyProof.create(
      operationId: 'copy:${DateTime.now().toUtc().microsecondsSinceEpoch}:${PlaylistUtils.generateCustomPlaylistId()}',
      destinationId: PlaylistUtils.generateCustomPlaylistId(),
      sessionId: snapshot.importSessionId, sourceKey: plan.sourceKey,
      sourceFingerprint: plan.sourceFingerprint, recordingIds: ids);
    final destinations = _copyDestinations(library);
    if (prior != null) {
      final state = _classifyCopy(proof, completed, destinations, snapshot, fingerprint);
      if (state != SpotifyPlaylistCopyRecovery.completedNoOp && state != SpotifyPlaylistCopyRecovery.recoverAuditOnly) _copyRefuse();
    } else if (destinations.length >= 10000 || destinations.any((row) => row['ytid'] == proof.destinationId)) {
      _copyRefuse();
    }
    final name = (title ?? snapshot.sourceName).trim();
    if (name.isEmpty || name.length > 2048 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw StateError('Choose a nonempty destination name of at most2048 characters.');
    }
    return SpotifyPlaylistCopyPreview._(snapshot, proof, name, songs,
      _freezeCopyValue(metadata) as Map<String, dynamic>, _freezeCopyCollections(library),
      Map.unmodifiable({for (final key in library.keys) key: box.containsKey(key)}), completed, prior != null && !completed);
  }

  Future<SpotifyPlaylistCopyResult> _createSourcePlaylistCopy(SpotifyPlaylistCopyPreview preview) async {
    if (SpotifyImportDestinationService._routingActive) throw StateError('Another transfer is running. Wait for it to finish.');
    SpotifyImportDestinationService._routingActive = true;
    try {
      final box = Hive.box('user');
      _validateCopySource(preview);
      final metadata = _copyMetadata(box);
      final history = _copyHistory(metadata);
      final completed = history.any((entry) => entry['action'] == SpotifyPlaylistCopyProof.action &&
          _decodeCopyEnvelope(entry, completed: true).matches(preview.proof));
      final pending = metadata[importRoutingPendingKey];
      final pendingOwned = pending is Map && pending['action'] == SpotifyPlaylistCopyProof.action &&
          _decodeCopyEnvelope(pending, completed: false).matches(preview.proof);
      final currentLibrary = _storedCopyCollections(box);
      if (!_sameCopyValue(currentLibrary, _liveCopyCollections())) _copyRefuse();
      if (completed) {
        if (metadata.containsKey(importRoutingPendingKey)) _copyRefuse();
        if (_classifyCopy(preview.proof, true, _copyDestinations(currentLibrary), preview._snapshot,
            preview.proof.recordingFingerprint) != SpotifyPlaylistCopyRecovery.completedNoOp) _copyRefuse();
        return _copyResult(preview, _copyTarget(box, preview.proof), created: false, tracked: true);
      }
      if (pendingOwned) {
        if (_classifyCopy(preview.proof, false, _copyDestinations(currentLibrary), preview._snapshot,
            preview.proof.recordingFingerprint) != SpotifyPlaylistCopyRecovery.recoverAuditOnly) _copyRefuse();
        return await _finishCopyAudit(preview, created: false);
      }
      if (metadata.containsKey(importRoutingPendingKey) || !_sameCopyValue(metadata, preview._metadata) ||
          !_copyStoredMatches(box, preview._library, preview._presence) ||
          !_sameCopyValue(_liveCopyCollections(), preview._library)) _copyRefuse();
      if (_copyDestinations(currentLibrary).length >= 10000 ||
          _copyDestinations(currentLibrary).any((row) => row['ytid'] == preview.proof.destinationId)) _copyRefuse();
      final checkpoint = {...metadata, importRoutingPendingKey: _copyEnvelope(preview.proof, completed: false)};
      await _writeCopyOwned('spotifyImportMetadata', checkpoint, () {
        _validateCopySource(preview);
        if (!_copyStoredMatches(box, preview._library, preview._presence) ||
            !_sameCopyValue(_liveCopyCollections(), preview._library)) _copyRefuse();
      }, canCompensate: () => _copyStoredMatches(box, preview._library, preview._presence) &&
          _sameCopyValue(_liveCopyCollections(), preview._library));
      final playlist = <String, dynamic>{'ytid': preview.proof.destinationId,
        'title': preview.title, 'source': 'user-created',
        'list': [for (final song in preview.songs) copyImportRoutingValue(song)],
        'createdAt': DateTime.now().toUtc().millisecondsSinceEpoch,
        SpotifyPlaylistCopyProof.markerKey: preview.proof.encode()};
      final staged = <dynamic>[...preview._library['customPlaylists']!, playlist];
      final expected = {...preview._library, 'customPlaylists': staged};
      final presence = {...preview._presence, 'customPlaylists': true};
      // After any destination attempt, missing target means uncertainty, even
      // when an owned exception compensation restored the earlier collection.
      // Retain the journal; never infer never-saved from absence (saved/deleted).
      await _writeCopyOwned('customPlaylists', staged, () {
        _validateCopySource(preview);
        if (!_sameCopyValue(_copyMetadata(box), checkpoint) ||
            !_copyStoredMatches(box, expected, presence) ||
            !_sameCopyValue(_liveCopyCollections(), preview._library)) _copyRefuse();
      }, canCompensate: () => _sameCopyValue(_liveCopyCollections(), preview._library) &&
          preview._library.keys.where((key) => key != 'customPlaylists').every((key) =>
            box.containsKey(key) == preview._presence[key] &&
            _sameCopyValue(box.get(key, defaultValue: const []), preview._library[key])));
      // Adopt actual stored map owners, preserving rename/one-slot Undo identity.
      userCustomPlaylists.value = List<Map>.from(box.get('customPlaylists'));
      try {
        _validateCopySource(preview);
        if (!_copyStoredMatches(box, expected, presence) ||
            !_sameCopyValue(_liveCopyCollections(), expected)) _copyRefuse();
      } catch (_) {
        return _copyResult(preview, _copyTarget(box, preview.proof), created: true, tracked: false);
      }
      return await _finishCopyAudit(preview, created: true);
    } finally { SpotifyImportDestinationService._routingActive = false; }
  }

  void _validateCopySource(SpotifyPlaylistCopyPreview preview) {
    _validateCurrentSnapshot(preview._snapshot, requireWholeSource: true);
    final effective = SpotifyImportDestinationService._effectiveResults(Hive.box('user'));
    final live = {for (final song in SpotifyImportDestinationService._uniqueSongs(effective.where(SpotifyImportDestinationService._isResolved).toList()))
      song['ytid'] as String: _frozenCopySong(song)};
    for (final song in preview.songs) {
      if (!_sameCopyValue(song, live[song['ytid']])) _copyRefuse();
    }
  }

  Future<SpotifyPlaylistCopyResult> _finishCopyAudit(SpotifyPlaylistCopyPreview preview, {required bool created}) async {
    final box = Hive.box('user'); var tracked = true;
    try {
      _validateCopySource(preview);
      final metadata = _copyMetadata(box); final history = _copyHistory(metadata);
      if (!_decodeCopyEnvelope(metadata[importRoutingPendingKey], completed: false).matches(preview.proof)) _copyRefuse();
      final target = _copyTarget(box, preview.proof);
      if (_classifyCopy(preview.proof, false, _copyDestinations(_storedCopyCollections(box)), preview._snapshot,
          preview.proof.recordingFingerprint) != SpotifyPlaylistCopyRecovery.recoverAuditOnly) _copyRefuse();
      final staged = {...metadata, 'routingHistory': [...history,
        {..._copyEnvelope(preview.proof, completed: true), 'destinationTitle': target['title'],
          'copiedSlotCount': preview.slotCount, 'uniqueRecordingCount': preview.uniqueRecordingCount,
          'routedAt': DateTime.now().toUtc().toIso8601String()}]}..remove(importRoutingPendingKey);
      await _writeCopyOwned('spotifyImportMetadata', staged, () {
        _validateCopySource(preview);
        if (_classifyCopy(preview.proof, true, _copyDestinations(_storedCopyCollections(box)), preview._snapshot,
            preview.proof.recordingFingerprint) != SpotifyPlaylistCopyRecovery.completedNoOp) _copyRefuse();
      });
    } catch (_) { tracked = false; }
    return _copyResult(preview, _copyTarget(box, preview.proof), created: created, tracked: tracked);
  }

  Future<void> _writeCopyOwned(String key, Object stagedValue, void Function() verify,
      {bool Function()? canCompensate}) async {
    final box = Hive.box('user'); final had = box.containsKey(key);
    final original = box.get(key);
    final before = copyImportRoutingValue(original);
    final staged = _freezeCopyValue(stagedValue);
    try {
      if (key == 'spotifyImportMetadata') {
        await _writeRoutingMetadata(box, Map<String, dynamic>.from(copyImportRoutingValue(staged) as Map));
      } else if (destinationWriter != null) {
        await destinationWriter!(box, key, List<dynamic>.from(copyImportRoutingValue(staged) as List));
      } else {
        await box.put(key, copyImportRoutingValue(staged));
      }
      if (!box.containsKey(key) || !_sameCopyValue(box.get(key), staged)) _copyRefuse();
      verify();
    } catch (error, stack) {
      try {
        if (box.isOpen && box.containsKey(key) && _sameCopyValue(box.get(key), staged) &&
            _sameCopyValue(original, before) && (canCompensate?.call() ?? true)) {
          // Restoring detached clones would invalidate still-live playlist
          // owners used by selected-slot rename/Undo. Original references are
          // safe only while both their values and the live owner remain exact.
          if (had) { await box.put(key, original); } else { await box.delete(key); }
        }
      } catch (_) { /* Uncertain evidence/current owners remain for review. */ }
      Error.throwWithStackTrace(error, stack);
    }
  }
}

Never _copyRefuse() => throw StateError('The source copy could not be verified. Existing playlists and the earlier attempt were kept for review. Reload the Library; missing copies will not be recreated automatically.');
Map<String, dynamic> _copyMetadata(Box box) {
  final value = box.get('spotifyImportMetadata');
  if (value is! Map || value.keys.any((key) => key is! String)) _copyRefuse();
  return Map<String, dynamic>.from(value);
}
List<Map<String, dynamic>> _copyHistory(Map<String, dynamic> metadata) {
  final raw = metadata['routingHistory'];
  if (metadata.containsKey('routingHistory') && (raw is! List || raw.length > 10000 || raw.any((entry) => entry is! Map))) _copyRefuse();
  final entries = <Map<String, dynamic>>[for (final entry in raw as List? ?? []) Map<String, dynamic>.from(entry as Map)];
  final operations = <String>{}; final targets = <String>{};
  for (final entry in entries.where((entry) => entry['action'] == SpotifyPlaylistCopyProof.action)) {
    final proof = _decodeCopyEnvelope(entry, completed: true);
    if (!operations.add(proof.operationId) || !targets.add(proof.destinationId)) _copyRefuse();
  }
  return entries;
}
SpotifyPlaylistCopyProof _decodeCopyEnvelope(Object? raw, {required bool completed}) {
  if (raw is! Map || raw['action'] != SpotifyPlaylistCopyProof.action ||
      raw['status'] != (completed ? 'completed' : 'pending') ||
      raw['recordingTransferBaselineAdvanced'] != false) _copyRefuse();
  try {
    final proof = SpotifyPlaylistCopyProof.decode(raw[SpotifyPlaylistCopyProof.journalKey]);
    if (raw['operationId'] != proof.operationId) _copyRefuse();
    return proof;
  } on FormatException { _copyRefuse(); }
}
Map<String, dynamic> _copyEnvelope(SpotifyPlaylistCopyProof proof, {required bool completed}) => {
  'action': SpotifyPlaylistCopyProof.action, 'operationId': proof.operationId,
  'status': completed ? 'completed' : 'pending', SpotifyPlaylistCopyProof.journalKey: proof.encode(),
  'recordingTransferBaselineAdvanced': false,
};
SpotifyPlaylistCopyRecovery _classifyCopy(SpotifyPlaylistCopyProof proof, bool completed,
    List<Map> destinations, SpotifyImportDestinationSnapshot snapshot, String recordingFingerprint) =>
  classifySpotifyPlaylistCopy(proof: proof, completed: completed, destinations: destinations,
    sessionId: snapshot.importSessionId, sourceKey: snapshot.sourcePlaylistKey!,
    sourceFingerprint: snapshot.sourcePlaylistFingerprint!, recordingFingerprint: recordingFingerprint);
SpotifyPlaylistCopyResult _copyResult(SpotifyPlaylistCopyPreview preview, Map target,
    {required bool created, required bool tracked}) => SpotifyPlaylistCopyResult(
      destinationId: preview.proof.destinationId, destinationTitle: target['title']?.toString() ?? preview.title,
      slotCount: preview.slotCount, uniqueRecordingCount: preview.uniqueRecordingCount,
      created: created, trackingRecorded: tracked);
Map _copyTarget(Box box, SpotifyPlaylistCopyProof proof) {
  final all = _copyDestinations(_storedCopyCollections(box));
  final targets = all.where((row) => row['ytid'] == proof.destinationId).toList();
  if (targets.length != 1) _copyRefuse();
  try { if (!SpotifyPlaylistCopyProof.decode(targets.single[SpotifyPlaylistCopyProof.markerKey]).matches(proof)) _copyRefuse(); }
  on FormatException { _copyRefuse(); }
  return targets.single;
}
Map<String, List<dynamic>> _liveCopyCollections() => {'customPlaylists': userCustomPlaylists.value,
  'playlistFolders': userPlaylistFolders.value, 'playlists': userPlaylists.value};
Map<String, List<dynamic>> _storedCopyCollections(Box box) {
  final result = <String, List<dynamic>>{};
  for (final key in ['customPlaylists', 'playlistFolders', 'playlists']) {
    final value = box.get(key, defaultValue: const []);
    if (value is! List || value.length > 10000 ||
        (key != 'playlists' && value.any((item) => item is! Map))) _copyRefuse();
    result[key] = List<dynamic>.from(value);
  }
  _copyDestinations(result); return result;
}
List<Map> _copyDestinations(Map<String, List<dynamic>> values) {
  final all = <Map>[...values['customPlaylists']!.cast<Map>()];
  for (final folder in values['playlistFolders']!) {
    final children = (folder as Map)['playlists'] ?? const [];
    if (children is! List || children.length > 10000 || children.any((row) => row is! Map)) _copyRefuse();
    all.addAll(children.cast<Map>()); if (all.length > 10000) _copyRefuse();
  }
  for (final item in values['playlists']!) {
    if (item is! Map && item is! String) _copyRefuse();
    all.add(item is Map ? item : {'ytid': item, 'source': 'youtube'});
    if (all.length > 10000) _copyRefuse();
  }
  return all;
}
bool _copyStoredMatches(Box box, Map<String, List<dynamic>> values, Map<String, bool> presence) =>
  values.keys.every((key) => box.containsKey(key) == presence[key] &&
    _sameCopyValue(box.get(key, defaultValue: const []), values[key]));
Map<String, List<dynamic>> _freezeCopyCollections(Map<String, List<dynamic>> values) => Map.unmodifiable({
  for (final entry in values.entries) entry.key: List<dynamic>.unmodifiable(entry.value.map(_freezeCopyValue)),
});
Map<String, dynamic> _frozenCopySong(Map<String, dynamic> value) {
  final song = Map<String, dynamic>.from(value)..remove('queueEntryId');
  return _freezeCopyValue(song) as Map<String, dynamic>;
}
Object? _freezeCopyValue(Object? value) {
  if (value is Uint8List) return Uint8List.fromList(value).asUnmodifiableView();
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freezeCopyValue));
  if (value is Map<String, dynamic>) return Map<String, dynamic>.unmodifiable(value.map((key, item) => MapEntry(key, _freezeCopyValue(item))));
  if (value is Map) return Map.unmodifiable(value.map((key, item) => MapEntry(key, _freezeCopyValue(item))));
  return value;
}
bool _sameCopyValue(dynamic a, dynamic b) {
  if (a is DateTime || b is DateTime) return a is DateTime && b is DateTime && a == b && a.isUtc == b.isUtc;
  if ((a is Uint8List) != (b is Uint8List)) return false;
  if (a is List && b is List) return a.length == b.length &&
      Iterable<int>.generate(a.length).every((index) => _sameCopyValue(a[index], b[index]));
  if (a is Map && b is Map) return a.length == b.length &&
      a.keys.every((key) => b.containsKey(key) && _sameCopyValue(a[key], b[key]));
  return a == b;
}
