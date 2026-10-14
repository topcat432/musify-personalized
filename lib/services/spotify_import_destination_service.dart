/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import 'package:musify/services/spotify_source_playlist_projection.dart';
import 'package:musify/services/spotify_whole_source_readiness.dart';
import 'package:musify/utilities/playlist_utils.dart';

enum SpotifyImportSelectionKind { all, firstCount, individual, newlyResolved }

typedef SpotifyRoutingMetadataWriter =
    Future<void> Function(Box<dynamic> box, Map<String, dynamic> metadata);

typedef SpotifyDestinationWriter =
    Future<void> Function(Box<dynamic> box, String key, List<dynamic> value);

enum SpotifyImportDestinationKind { likedSongs, newPlaylist, existingPlaylist }

class SpotifyImportDestinationSnapshot {
  const SpotifyImportDestinationSnapshot({
    required this.importSessionId,
    required this.sourceName,
    required this.resolvedSongs,
    required this.resolvedResultCount,
    required this.unresolvedCount,
    required this.customPlaylists,
    this.resolvedRecordings = const [],
    this.recordingIdentitiesReliable = false,
    this.sourceRowsReliable = false,
    this.newlyResolvedBaselineKnown = false,
    this.newlyResolvedRecordingIds = const {},
    this.resolutionFingerprint,
    this.wholeSourceReadiness,
    this.sourcePlaylistPosition,
    this.sourcePlaylistKey,
    this.sourcePlaylistFingerprint,
    this.sourceUnsupportedMembers = 0,
    this.sourceRepeatedMembers = 0,
  });

  final String importSessionId;
  final String sourceName;
  final List<Map<String, dynamic>> resolvedSongs;
  final int resolvedResultCount;
  final int unresolvedCount;
  final List<Map<String, dynamic>> customPlaylists;
  final List<Map<String, String>> resolvedRecordings;
  final bool recordingIdentitiesReliable;
  final bool sourceRowsReliable;
  final bool newlyResolvedBaselineKnown;
  final Set<String> newlyResolvedRecordingIds;
  final String? resolutionFingerprint;
  final SpotifyWholeSourceReadiness? wholeSourceReadiness;
  final int? sourcePlaylistPosition;
  final String? sourcePlaylistKey, sourcePlaylistFingerprint;
  final int sourceUnsupportedMembers, sourceRepeatedMembers;

  int get duplicateMatchCount => resolvedResultCount - resolvedSongs.length;
}

class SpotifyImportRoutePreview {
  const SpotifyImportRoutePreview({
    required this.selectedCount,
    required this.newCount,
    required this.alreadyPresentCount,
    required this.unresolvedCount,
    this.selectedSongs = const [],
  });

  final List<Map<String, dynamic>> selectedSongs;
  final int selectedCount;
  final int newCount;
  final int alreadyPresentCount;
  final int unresolvedCount;
}

class SpotifyImportRouteResult {
  const SpotifyImportRouteResult({
    required this.destinationTitle,
    required this.selectedCount,
    required this.addedCount,
    required this.alreadyPresentCount,
    this.trackingRecorded = true,
  });

  final bool trackingRecorded;
  final String destinationTitle;
  final int selectedCount;
  final int addedCount;
  final int alreadyPresentCount;
}

class SpotifyEmptySourcePlaylistResult {
  const SpotifyEmptySourcePlaylistResult({
    required this.destinationId,
    required this.destinationTitle,
    required this.created,
    this.trackingRecorded = true,
  });
  final String destinationId, destinationTitle;
  final bool created, trackingRecorded;
}
class SpotifyImportDestinationService {
  const SpotifyImportDestinationService({
    this.metadataWriter,
    this.destinationWriter,
  });
  final SpotifyRoutingMetadataWriter? metadataWriter;
  final SpotifyDestinationWriter? destinationWriter;
  static bool _routingActive = false;

  Future<SpotifyImportDestinationSnapshot> loadSnapshot() async {
    final box = Hive.box('user');
    final results = _effectiveResults(box);
    final storedIdentities = resolvedImportRecordings(results);
    // Preserve stored order when historical source-row positions are incomplete.
    if (storedIdentities.reliable) {
      results.sort(
        (left, right) => _sourceRow(left).compareTo(_sourceRow(right)),
      );
    }
    final tracks = _readMaps(box.get('spotifyImportTracks'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    final resolved = results.where(_isResolved).toList(growable: false);
    final songs = _uniqueSongs(resolved);
    final identities = resolvedImportRecordings(results);
    final identityReliable =
        identities.reliable &&
        hasStableImportSessionIdentity(metadata) &&
        _exclusionsKnown(box);
    final baseline = readImportRoutingBaseline(metadata, _sessionId(metadata));
    final newlyResolved = baseline != null && identityReliable
        ? identities.rows
              .where((row) => !baseline.contains(importRecordingIdentity(row)))
              .map((row) => row['recordingId']!)
              .toSet()
        : <String>{};
    final customPlaylists =
        _currentCustomPlaylists()
            .map(Map<String, dynamic>.from)
            .toList(growable: false)
          ..sort(
            (left, right) => (left['title']?.toString() ?? '')
                .toLowerCase()
                .compareTo((right['title']?.toString() ?? '').toLowerCase()),
          );
    final unresolvedCount = countUnresolvedTracks(tracks, results);

    return SpotifyImportDestinationSnapshot(
      importSessionId: _sessionId(metadata),
      sourceName: _sourceName(metadata['fileName']?.toString()),
      resolvedSongs: List.unmodifiable(songs),
      resolvedResultCount: resolved.length,
      unresolvedCount: unresolvedCount,
      customPlaylists: List.unmodifiable(customPlaylists),
      resolvedRecordings: identities.rows,
      recordingIdentitiesReliable: identityReliable,
      sourceRowsReliable: identities.reliable,
      newlyResolvedBaselineKnown: baseline != null && identityReliable,
      newlyResolvedRecordingIds: Set.unmodifiable(newlyResolved),
      resolutionFingerprint: identities.fingerprint,
      wholeSourceReadiness: SpotifyWholeSourceReadiness.inspect(
        rawTracks: box.get('spotifyImportTracks'),
        rawResults: box.get('spotifyMatchResults'),
        rawExcludedRows: box.get('spotifyExcludedImportRows'),
        metadata: metadata,
      ),
    );
  }

  SpotifySourcePlaylistProjection _sourceProjection(
    SpotifyImportDestinationSnapshot snapshot,
    int position,
  ) {
    final box = Hive.box('user');
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    return SpotifySourcePlaylistProjection.project(
      sources: SpotifySourcePlaylistCodec.readSaved(
        metadata[SpotifySourcePlaylistCodec.metadataKey],
        box.get('spotifyImportTracks'),
      ),
      position: position,
      tracks: _readMaps(box.get('spotifyImportTracks')),
      snapshot: snapshot,
    );
  }

  Future<SpotifyImportDestinationSnapshot> loadSourcePlaylistSnapshot(
    int position,
  ) async {
    final base = await loadSnapshot();
    final source = _sourceProjection(base, position);
    return SpotifyImportDestinationSnapshot(
      importSessionId: base.importSessionId,
      sourceName: source.source.name,
      resolvedSongs: source.songs,
      resolvedResultCount: source.songs.length + source.repeatedResolvedMembers,
      unresolvedCount: source.pendingMembers,
      customPlaylists: base.customPlaylists,
      resolvedRecordings: base.resolvedRecordings,
      recordingIdentitiesReliable: base.recordingIdentitiesReliable,
      sourceRowsReliable: base.sourceRowsReliable,
      newlyResolvedBaselineKnown: base.newlyResolvedBaselineKnown,
      newlyResolvedRecordingIds: base.newlyResolvedRecordingIds,
      resolutionFingerprint: base.resolutionFingerprint,
      wholeSourceReadiness: SpotifyWholeSourceReadiness.inspect(
        rawTracks: Hive.box('user').get('spotifyImportTracks'),
        rawResults: Hive.box('user').get('spotifyMatchResults'),
        rawExcludedRows: Hive.box('user').get('spotifyExcludedImportRows'),
        metadata: _readMap(Hive.box('user').get('spotifyImportMetadata')),
        sourcePlaylistPosition: position,
      ),
      sourcePlaylistPosition: position,
      sourcePlaylistKey: source.scopeKey,
      sourcePlaylistFingerprint: source.fingerprint,
      sourceUnsupportedMembers: source.unsupportedMembers,
      sourceRepeatedMembers: source.repeatedResolvedMembers,
    );
  }

  SpotifyImportRoutePreview preview({
    required SpotifyImportDestinationSnapshot snapshot,
    required int requestedCount,
    required SpotifyImportDestinationKind destinationKind,
    String? newPlaylistName,
    String? existingPlaylistId,
    SpotifyImportSelectionKind selectionKind =
        SpotifyImportSelectionKind.firstCount,
    Set<String> selectedRecordingIds = const {},
    bool requireWholeSource = false,
  }) {
    if (requireWholeSource)
      _validateCurrentSnapshot(snapshot, requireWholeSource: true);
    final selected = selectSongs(
      snapshot,
      requestedCount,
      selectionKind: selectionKind,
      selectedRecordingIds: selectedRecordingIds,
      requireWholeSource: requireWholeSource,
    );
    final existingIds = _destinationSongIds(
      destinationKind,
      snapshot: snapshot,
      newPlaylistName: newPlaylistName,
      existingPlaylistId: existingPlaylistId,
    );
    final alreadyPresent = selected
        .where((song) => existingIds.contains(song['ytid']?.toString()))
        .length;
    return SpotifyImportRoutePreview(
      selectedCount: selected.length,
      newCount: selected.length - alreadyPresent,
      alreadyPresentCount: alreadyPresent,
      unresolvedCount: snapshot.unresolvedCount,
      selectedSongs: List.unmodifiable(selected),
    );
  }

  List<Map<String, dynamic>> selectSongs(
    SpotifyImportDestinationSnapshot snapshot,
    int requestedCount, {
    SpotifyImportSelectionKind selectionKind =
        SpotifyImportSelectionKind.firstCount,
    Set<String> selectedRecordingIds = const {},
    bool requireWholeSource = false,
  }) {
    if (requireWholeSource &&
        (selectionKind != SpotifyImportSelectionKind.all ||
            snapshot.wholeSourceReadiness?.ready != true)) {
      throw StateError(
        'The whole source is not ready. Review every unresolved, excluded, unsupported or unverified row, or choose an explicit partial transfer.',
      );
    }
    Iterable<Map<String, dynamic>> selected;
    switch (selectionKind) {
      case SpotifyImportSelectionKind.all:
        selected = snapshot.resolvedSongs;
      case SpotifyImportSelectionKind.firstCount:
        selected = snapshot.resolvedSongs.take(
          requestedCount.clamp(0, snapshot.resolvedSongs.length),
        );
      case SpotifyImportSelectionKind.individual:
        final available = _songIds(snapshot.resolvedSongs);
        if (selectedRecordingIds.difference(available).isNotEmpty) {
          throw StateError(
            'The selected recordings changed. Reload the import before transferring.',
          );
        }
        selected = snapshot.resolvedSongs.where(
          (song) =>
              selectedRecordingIds.contains(song['ytid']?.toString().trim()),
        );
      case SpotifyImportSelectionKind.newlyResolved:
        if (!snapshot.newlyResolvedBaselineKnown) {
          throw StateError(
            'Newly resolved tracking is unavailable for this import. Choose songs explicitly.',
          );
        }
        selected = snapshot.resolvedSongs.where(
          (song) => snapshot.newlyResolvedRecordingIds.contains(
            song['ytid']?.toString().trim(),
          ),
        );
    }
    return selected.map(Map<String, dynamic>.from).toList(growable: false);
  }

  static int countUnresolvedTracks(
    List<Map<String, dynamic>> tracks,
    List<Map<String, dynamic>> results,
  ) {
    final processedRows = results
        .map(_sourceRowKey)
        .where((row) => row.isNotEmpty)
        .toSet();
    final unprocessedCount = tracks
        .map(_sourceRowKey)
        .where((row) => row.isNotEmpty && !processedRows.contains(row))
        .length;
    final unresolvedResultCount = results
        .where(
          (result) => !_isResolved(result) && result['status'] != 'excluded',
        )
        .length;
    return unresolvedResultCount + unprocessedCount;
  }

  static String _sessionId(Map<String, dynamic> metadata) =>
      importSessionIdentity(metadata);

  void _validateEmptySource(SpotifyImportDestinationSnapshot snapshot) {
    _validateCurrentSnapshot(snapshot);
    final box = Hive.box('user');
    final live = SpotifyWholeSourceReadiness.inspect(
      rawTracks: box.get('spotifyImportTracks'),
      rawResults: box.get('spotifyMatchResults'),
      rawExcludedRows: box.get('spotifyExcludedImportRows'),
      metadata: _readMap(box.get('spotifyImportMetadata')),
      sourcePlaylistPosition: snapshot.sourcePlaylistPosition,
    );
    if (snapshot.sourcePlaylistPosition == null ||
        snapshot.sourcePlaylistKey == null ||
        snapshot.wholeSourceReadiness?.verifiedEmpty != true ||
        !live.verifiedEmpty ||
        live.fingerprint != snapshot.wholeSourceReadiness?.fingerprint) {
      throw StateError('The source is not verifiably empty. Reload its membership; no playlist was changed.');
    }
  }

  // Empty creation is a separate zero-song action. It never certifies a song
  // transfer or advances the last-successful resolved-recording baseline.
  Future<SpotifyEmptySourcePlaylistResult> createEmptySourcePlaylist({
    required SpotifyImportDestinationSnapshot snapshot,
  }) async {
    if (_routingActive) throw StateError('Another transfer is already running. Wait for it to finish.');
    _routingActive = true;
    try {
      _validateEmptySource(snapshot);
      final box = Hive.box('user');
      final metadata = _readMap(box.get('spotifyImportMetadata'));
      final priorPending = metadata[importRoutingPendingKey];
      final sourceKey = snapshot.sourcePlaylistKey!;
      if (metadata.containsKey(importRoutingPendingKey) && (priorPending is! Map ||
          priorPending['action'] != 'create_empty_source_playlist' ||
          priorPending['selectedCount'] is! int || priorPending['selectedCount'] != 0 ||
          priorPending['sourceItemCount'] is! int || priorPending['sourceItemCount'] != 0 ||
          priorPending['operationId'] is! String || (priorPending['operationId'] as String).isEmpty ||
          priorPending['sourcePlaylistKey'] != sourceKey ||
          priorPending['importSessionId'] != snapshot.importSessionId)) {
        throw StateError('An earlier transfer needs review before creating an empty source destination.');
      }
      if (priorPending is Map && (priorPending['destinationId'] is! String || (priorPending['destinationId'] as String).isEmpty)) {
        throw StateError('The previous empty-source attempt is unverified. Review it before continuing.');
      }
      final rawHistory = metadata['routingHistory'];
      if (metadata.containsKey('routingHistory') && (rawHistory is! List || rawHistory.any((row) => row is! Map))) {
        throw StateError('Saved routing history is unverified. The original values were retained.');
      }
      final history = _readMaps(rawHistory);
      final priorActions = history.where((row) =>
          row['action'] == 'create_empty_source_playlist' && row['sourcePlaylistKey'] == sourceKey).toList();
      if (priorActions.any((row) => row['destinationId'] is! String || (row['destinationId'] as String).isEmpty)) {
        throw StateError('The previous empty-source audit is unverified. Existing data was retained.');
      }
      final linked = _currentCustomPlaylists().where((playlist) =>
          playlist['importSourcePlaylistKey'] == sourceKey).toList();
      if (linked.length > 1) throw StateError('More than one destination belongs to this source. Review them in the library before continuing.');
      final existing = linked.isEmpty ? null : linked.single;
      final priorId = priorPending is Map ? priorPending['destinationId'] :
          priorActions.isEmpty ? null : priorActions.last['destinationId'];
      if (priorId != null && (existing == null || existing['ytid'] != priorId)) {
        throw StateError('The previously recorded destination was removed or changed. It will not be recreated automatically.');
      }
      final id = existing == null ? PlaylistUtils.generateCustomPlaylistId() : existing['ytid'];
      if (id is! String || id.trim().isEmpty || (existing != null && existing['list'] is! List)) {
        throw StateError('The saved destination is unverified. Existing values were retained.');
      }
      final operationId = '${DateTime.now().toUtc().microsecondsSinceEpoch}:empty:$sourceKey';
      final pending = <String, dynamic>{
        'operationId': operationId,
        'action': 'create_empty_source_playlist',
        'importSessionId': snapshot.importSessionId,
        'sourcePlaylistKey': sourceKey,
        'sourcePlaylistFingerprint': snapshot.sourcePlaylistFingerprint,
        'destinationId': id,
        'selectedCount': 0,
        'sourceItemCount': 0,
        'confirmedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await _writeEmptyMetadata(box, {...metadata, importRoutingPendingKey: pending});
      var destinationWritten = false;
      final hadPlaylists = box.containsKey('customPlaylists');
      final beforePlaylists = copyImportRoutingValue(box.get('customPlaylists'));
      try {
        _validateEmptySource(snapshot);
        final checkpoint = _readMap(box.get('spotifyImportMetadata'))[importRoutingPendingKey];
        if (checkpoint is! Map || checkpoint['operationId'] != operationId) {
          throw StateError('The empty-source checkpoint was not saved. No destination was created.');
        }
        final currentLinked = _currentCustomPlaylists().where((playlist) =>
            playlist['importSourcePlaylistKey'] == sourceKey).toList();
        if ((existing == null && currentLinked.isNotEmpty) ||
            (existing != null && (currentLinked.length != 1 || currentLinked.single['ytid'] != id))) {
          throw StateError('The source destination changed during confirmation. Reload before continuing.');
        }
        if (existing == null) {
          final playlist = <String, dynamic>{
            'ytid': id, 'title': snapshot.sourceName, 'source': 'user-created',
            'importSourceName': snapshot.sourceName,
            'importSourcePlaylistKey': sourceKey,
            'list': <dynamic>[], 'createdAt': DateTime.now().millisecondsSinceEpoch,
          };
          await _writeDestination('customPlaylists', <Map>[..._storedPlaylists('customPlaylists'), playlist]);
          destinationWritten = true;
          userCustomPlaylists.value = _storedPlaylists('customPlaylists');
        }
        _validateEmptySource(snapshot);
      } catch (_) {
        final restored = box.containsKey('customPlaylists') == hadPlaylists &&
            jsonEncode(box.get('customPlaylists')) == jsonEncode(beforePlaylists);
        if (!destinationWritten && restored) {
          await _removeEmptyPending(box, snapshot, operationId, priorPending);
        }
        rethrow;
      }
      final actual = _currentCustomPlaylists().where((playlist) =>
          playlist['ytid'] == id && playlist['importSourcePlaylistKey'] == sourceKey).toList();
      if (actual.length != 1) throw StateError('The destination changed during creation. The saved library was retained; review its pending audit before retrying.');
      final title = actual.single['title']?.toString() ?? snapshot.sourceName;
      var trackingRecorded = true;
      try {
        final current = _readMap(box.get('spotifyImportMetadata'));
        final owned = current[importRoutingPendingKey];
        if (_sessionId(current) != snapshot.importSessionId || owned is! Map || owned['operationId'] != operationId) {
          throw StateError('The empty-source audit checkpoint changed.');
        }
        final currentHistory = current['routingHistory'];
        if (current.containsKey('routingHistory') && (currentHistory is! List || currentHistory.any((row) => row is! Map))) {
          throw StateError('The routing history changed.');
        }
        final completed = Map<String, dynamic>.from(current)
          ..['routingHistory'] = [
            ..._readMaps(currentHistory),
            {...pending, 'destinationTitle': title, 'createdPlaylist': existing == null,
              'addedCount': 0, 'alreadyPresentCount': 0, 'songTransfer': false,
              'status': 'completed', 'routedAt': DateTime.now().toUtc().toIso8601String()},
          ]
          ..remove(importRoutingPendingKey);
        await _writeEmptyMetadata(box, completed);
        _validateEmptySource(snapshot);
        final saved = _readMap(box.get('spotifyImportMetadata'));
        final savedHistory = _readMaps(saved['routingHistory']);
        if (saved.containsKey(importRoutingPendingKey) || !savedHistory.any((row) =>
            row['operationId'] == operationId && row['action'] == 'create_empty_source_playlist' &&
            row['songTransfer'] == false && row['selectedCount'] == 0 && row['addedCount'] == 0)) {
          throw StateError('The completed empty-source audit was not saved.');
        }
      } catch (_) {
        trackingRecorded = false;
        final current = _readMap(box.get('spotifyImportMetadata'));
        final owned = current[importRoutingPendingKey];
        if (_sessionId(current) == snapshot.importSessionId &&
            (owned == null || (owned is Map && owned['operationId'] == operationId))) {
          try {await _writeEmptyMetadata(box, {...current, importRoutingPendingKey: pending});} catch (_) {}
        }
      }
      final finalDestination = _currentCustomPlaylists().where((playlist) =>
          playlist['ytid'] == id && playlist['importSourcePlaylistKey'] == sourceKey).toList();
      if (finalDestination.length != 1) {
        final current = _readMap(box.get('spotifyImportMetadata'));
        final owned = current[importRoutingPendingKey];
        if (_sessionId(current) == snapshot.importSessionId &&
            (owned == null || (owned is Map && owned['operationId'] == operationId))) {
          try {await _writeEmptyMetadata(box, {...current, importRoutingPendingKey: pending});} catch (_) {}
        }
        throw StateError('The destination was removed during confirmation. It will not be recreated automatically; its audit needs review.');
      }
      userCustomPlaylists.value = _storedPlaylists('customPlaylists');
      userPlaylistFolders.value = _storedPlaylists('playlistFolders');
      return SpotifyEmptySourcePlaylistResult(destinationId: id,
          destinationTitle: finalDestination.single['title']?.toString() ?? title,
          created: existing == null, trackingRecorded: trackingRecorded,);
    } finally {_routingActive = false;}
  }

  Future<void> _writeEmptyMetadata(Box<dynamic> box, Map<String, dynamic> values) async {
    final had = box.containsKey('spotifyImportMetadata');
    final before = copyImportRoutingValue(box.get('spotifyImportMetadata'));
    try {await _writeRoutingMetadata(box, values);} catch (_) {
      if (jsonEncode(box.get('spotifyImportMetadata')) == jsonEncode(values)) {
        if (had) {await box.put('spotifyImportMetadata', before);}
        else {await box.delete('spotifyImportMetadata');}
      }
      rethrow;
    }
  }

  Future<void> _removeEmptyPending(Box<dynamic> box, SpotifyImportDestinationSnapshot snapshot,
      String operationId, Object? priorPending,) async {
    final current = _readMap(box.get('spotifyImportMetadata'));
    final owned = current[importRoutingPendingKey];
    if (_sessionId(current) != snapshot.importSessionId || owned is! Map || owned['operationId'] != operationId) return;
    if (priorPending == null) {current.remove(importRoutingPendingKey);}
    else {current[importRoutingPendingKey] = copyImportRoutingValue(priorPending);}
    try {await _writeEmptyMetadata(box, current);} catch (_) {}
  }
  Future<SpotifyImportRouteResult> route({
    required SpotifyImportDestinationSnapshot snapshot,
    required int requestedCount,
    required SpotifyImportDestinationKind destinationKind,
    String? newPlaylistName,
    String? existingPlaylistId,
    SpotifyImportSelectionKind selectionKind =
        SpotifyImportSelectionKind.firstCount,
    Set<String> selectedRecordingIds = const {},
    bool requireWholeSource = false,
  }) async {
    if (_routingActive)
      throw StateError(
        'Another transfer is already running. Wait for it to finish.',
      );
    _routingActive = true;
    try {
      return await _routeLocked(
        snapshot: snapshot,
        requestedCount: requestedCount,
        destinationKind: destinationKind,
        newPlaylistName: newPlaylistName,
        existingPlaylistId: existingPlaylistId,
        selectionKind: selectionKind,
        selectedRecordingIds: Set.unmodifiable(selectedRecordingIds),
        requireWholeSource: requireWholeSource,
      );
    } finally {
      _routingActive = false;
    }
  }

  Future<SpotifyImportRouteResult> _routeLocked({
    required SpotifyImportDestinationSnapshot snapshot,
    required int requestedCount,
    required SpotifyImportDestinationKind destinationKind,
    String? newPlaylistName,
    String? existingPlaylistId,
    SpotifyImportSelectionKind selectionKind =
        SpotifyImportSelectionKind.firstCount,
    Set<String> selectedRecordingIds = const {},
    bool requireWholeSource = false,
  }) async {
    _validateCurrentSnapshot(snapshot, requireWholeSource: requireWholeSource);
    final confirmedSnapshot = snapshot.sourcePlaylistPosition == null
        ? await loadSnapshot()
        : await loadSourcePlaylistSnapshot(snapshot.sourcePlaylistPosition!);
    if (confirmedSnapshot.importSessionId != snapshot.importSessionId ||
        snapshot.resolvedSongs
                .map((song) => song['ytid']?.toString().trim())
                .join('\u0000') !=
            confirmedSnapshot.resolvedSongs
                .map((song) => song['ytid']?.toString().trim())
                .join('\u0000')) {
      throw StateError(
        'The resolved recordings changed. Reload the import before transferring.',
      );
    }
    _validateCurrentSnapshot(
      confirmedSnapshot,
      requireWholeSource: requireWholeSource,
    );
    if (selectionKind == SpotifyImportSelectionKind.newlyResolved &&
        (!snapshot.newlyResolvedBaselineKnown ||
            !confirmedSnapshot.newlyResolvedBaselineKnown ||
            snapshot.newlyResolvedRecordingIds
                .difference(confirmedSnapshot.newlyResolvedRecordingIds)
                .isNotEmpty ||
            confirmedSnapshot.newlyResolvedRecordingIds
                .difference(snapshot.newlyResolvedRecordingIds)
                .isNotEmpty)) {
      throw StateError(
        'Newly resolved tracking changed. Reload and review the transfer again.',
      );
    }
    final selected = selectSongs(
      confirmedSnapshot,
      requestedCount,
      selectionKind: selectionKind,
      selectedRecordingIds: Set.unmodifiable(selectedRecordingIds),
      requireWholeSource: requireWholeSource,
    );
    if (selected.isEmpty) {
      throw StateError('Choose at least one resolved song.');
    }

    if (destinationKind == SpotifyImportDestinationKind.existingPlaylist) {
      final id = existingPlaylistId?.trim() ?? '';
      if (id.isEmpty ||
          !_currentCustomPlaylists().any(
            (playlist) => playlist['ytid']?.toString() == id,
          )) {
        throw StateError('The selected playlist no longer exists.');
      }
    }
    final operationId = DateTime.now().microsecondsSinceEpoch.toString();
    final box = Hive.box('user');
    final pending = <String, dynamic>{
      'version': importRoutingStateVersion,
      'operationId': operationId,
      'importSessionId': snapshot.importSessionId,
      'selectionKind': selectionKind.name,
      if (snapshot.sourcePlaylistKey != null)
        'sourcePlaylistKey': snapshot.sourcePlaylistKey,
      if (snapshot.sourcePlaylistFingerprint != null)
        'sourcePlaylistFingerprint': snapshot.sourcePlaylistFingerprint,
      'selectedRecordingIds': selected
          .map((song) => song['ytid']?.toString().trim())
          .toList(),
      'confirmedResolvedRecordings': confirmedSnapshot.resolvedRecordings
          .map(Map<String, String>.from)
          .toList(),
      'confirmedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    final hadPriorPending = metadata.containsKey(importRoutingPendingKey);
    final priorPending = copyImportRoutingValue(
      metadata[importRoutingPendingKey],
    );
    if (hadPriorPending) {
      final prior = copyImportRoutingValue(metadata[importRoutingPendingKey]);
      final unknown = _readMaps(metadata[importRoutingUnverifiedHistoryKey]);
      final priorId = prior is Map ? prior['operationId'] : null;
      if (priorId == null ||
          !unknown.any(
            (entry) =>
                entry['attempt'] is Map &&
                (entry['attempt'] as Map)['operationId'] == priorId,
          )) {
        unknown.add({
          'status': 'unverified',
          'attempt': prior,
          'observedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
      metadata[importRoutingUnverifiedHistoryKey] = unknown;
    }
    metadata[importRoutingPendingKey] = pending;
    // Durable uncertainty marker precedes any destination write. If final audit
    // fails or the process stops, legacy/newly-resolved state is never guessed.
    await _writeRoutingMetadata(box, metadata);
    try {
      _validateCurrentSnapshot(
        confirmedSnapshot,
        requireWholeSource: requireWholeSource,
      );
    } catch (_) {
      final current = _readMap(box.get('spotifyImportMetadata'));
      if (_sessionId(current) == snapshot.importSessionId &&
          (current[importRoutingPendingKey] as Map?)?['operationId'] ==
              operationId) {
        if (hadPriorPending) {
          current[importRoutingPendingKey] = priorPending;
        } else {
          current.remove(importRoutingPendingKey);
        }
        await _writeRoutingMetadata(box, current);
      }
      rethrow;
    }
    final result = switch (destinationKind) {
      SpotifyImportDestinationKind.likedSongs => await _routeToLiked(selected),
      SpotifyImportDestinationKind.newPlaylist => await _routeToNewPlaylist(
        selected,
        name: newPlaylistName,
        fallbackName: snapshot.sourceName,
        sourcePlaylistKey: snapshot.sourcePlaylistKey,
      ),
      SpotifyImportDestinationKind.existingPlaylist =>
        await _routeToExistingPlaylist(
          selected,
          playlistId: existingPlaylistId,
        ),
    };
    try {
      await _recordRouting(
        confirmedSnapshot,
        destinationKind,
        result,
        selectionKind,
        selected,
        operationId,
        requireWholeSource: requireWholeSource,
      );
    } catch (_) {
      // The destination is already durable. Retain/restore the uncertainty
      // marker rather than reporting failure and inviting a duplicate retry.
      final current = _readMap(box.get('spotifyImportMetadata'));
      if (_sessionId(current) == snapshot.importSessionId) {
        current[importRoutingPendingKey] = pending;
        try {
          await _writeRoutingMetadata(box, current);
        } catch (_) {}
      }
      return SpotifyImportRouteResult(
        destinationTitle: result.destinationTitle,
        selectedCount: result.selectedCount,
        addedCount: result.addedCount,
        alreadyPresentCount: result.alreadyPresentCount,
        trackingRecorded: false,
      );
    }
    if (!confirmedSnapshot.recordingIdentitiesReliable) {
      return SpotifyImportRouteResult(
        destinationTitle: result.destinationTitle,
        selectedCount: result.selectedCount,
        addedCount: result.addedCount,
        alreadyPresentCount: result.alreadyPresentCount,
        trackingRecorded: false,
      );
    }
    return result;
  }

  Future<void> _writeRoutingMetadata(
    Box<dynamic> box,
    Map<String, dynamic> metadata,
  ) =>
      (metadataWriter ??
      (target, values) =>
          target.put('spotifyImportMetadata', values))(box, metadata);

  void _validateCurrentSnapshot(
    SpotifyImportDestinationSnapshot snapshot, {
    bool requireWholeSource = false,
  }) {
    if (!_exclusionsKnown(Hive.box('user'))) {
      throw StateError(
        'Saved exclusion decisions could not be verified. The import was retained; review or recover it before transferring.',
      );
    }
    if (requireWholeSource) {
      final box = Hive.box('user');
      final live = SpotifyWholeSourceReadiness.inspect(
        rawTracks: box.get('spotifyImportTracks'),
        rawResults: box.get('spotifyMatchResults'),
        rawExcludedRows: box.get('spotifyExcludedImportRows'),
        metadata: _readMap(box.get('spotifyImportMetadata')),
        sourcePlaylistPosition: snapshot.sourcePlaylistPosition,
      );
      if (snapshot.wholeSourceReadiness?.ready != true ||
          !live.ready ||
          live.fingerprint != snapshot.wholeSourceReadiness?.fingerprint) {
        throw StateError(
          'Whole-source readiness changed. Reload and review the source before transferring.',
        );
      }
    }
    if (snapshot.sourcePlaylistPosition == null &&
        (snapshot.sourcePlaylistKey != null ||
            snapshot.sourcePlaylistFingerprint != null))
      throw StateError('Reload the source playlist before transferring.');
    if (snapshot.sourcePlaylistPosition != null) {
      final projected = _sourceProjection(
        snapshot,
        snapshot.sourcePlaylistPosition!,
      );
      if (projected.scopeKey != snapshot.sourcePlaylistKey ||
          projected.fingerprint != snapshot.sourcePlaylistFingerprint) {
        throw StateError(
          'Source playlist membership changed. Reload before transferring; no source data was removed.',
        );
      }
    }
    final currentSessionId = _sessionId(
      _readMap(Hive.box('user').get('spotifyImportMetadata')),
    );
    if (snapshot.importSessionId.isEmpty ||
        snapshot.importSessionId != currentSessionId) {
      throw StateError(
        'This destination view belongs to an older import. Reload it before transferring songs.',
      );
    }
    if (snapshot.resolutionFingerprint != null &&
        snapshot.resolutionFingerprint !=
            resolvedImportRecordings(
              _effectiveResults(Hive.box('user')),
            ).fingerprint) {
      throw StateError(
        'The resolved recordings changed. Reload the import before transferring.',
      );
    }
  }

  Future<void> _writeDestination(String key, List<dynamic> value) async {
    final box = Hive.box('user');
    final had = box.containsKey(key);
    final before = copyImportRoutingValue(box.get(key));
    try {
      if (destinationWriter == null) {
        await addOrUpdateData<List>('user', key, value);
      } else {
        await destinationWriter!(box, key, value);
      }
    } catch (error, stack) {
      // Restore only this writer's exact staged value; never overwrite a newer
      // independent library edit. The pending audit retains uncertainty.
      if (jsonEncode(box.get(key)) == jsonEncode(value)) {
        if (had) {
          await box.put(key, before);
        } else {
          await box.delete(key);
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  List<Map<String, dynamic>> _storedPlaylists(String key) {
    final box = Hive.box('user');
    final raw = box.containsKey(key) ? box.get(key) : const [];
    if (raw is! List || raw.any((item) => item is! Map)) {
      throw StateError(
        'Saved playlist data could not be verified. Existing library data was retained.',
      );
    }
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: true);
  }

  List<Map<String, dynamic>> _folderPlaylists(Map<String, dynamic> folder) {
    final raw = folder['playlists'] ?? const [];
    if (raw is! List || raw.any((item) => item is! Map)) {
      throw StateError(
        'Saved folder membership could not be verified. Existing library data was retained.',
      );
    }
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: true);
  }

  List<Map<String, dynamic>> _currentCustomPlaylists() => [
    ..._storedPlaylists(
      'customPlaylists',
    ).where((playlist) => playlist['source'] == 'user-created'),
    for (final folder in _storedPlaylists('playlistFolders'))
      ..._folderPlaylists(
        folder,
      ).where((playlist) => playlist['source'] == 'user-created'),
  ];
  List<dynamic> _currentLikedSongs() {
    final box = Hive.box('user');
    if (!box.containsKey('likedSongs')) return <dynamic>[];
    final raw = box.get('likedSongs');
    if (raw is! List)
      throw StateError(
        'Saved Liked Songs could not be verified. Existing library data was retained.',
      );
    return List<dynamic>.from(raw);
  }

  Future<SpotifyImportRouteResult> _routeToLiked(
    List<Map<String, dynamic>> selected,
  ) async {
    final existing = _currentLikedSongs();
    final existingIds = _songIds(existing);
    final additions = selected
        .where((song) => !existingIds.contains(song['ytid']?.toString()))
        .toList(growable: false);
    final updated = <dynamic>[...additions, ...existing];
    await _writeDestination('likedSongs', updated);
    userLikedSongsList.value = _currentLikedSongs();
    return SpotifyImportRouteResult(
      destinationTitle: 'Liked Songs',
      selectedCount: selected.length,
      addedCount: additions.length,
      alreadyPresentCount: selected.length - additions.length,
    );
  }

  Future<SpotifyImportRouteResult> _routeToNewPlaylist(
    List<Map<String, dynamic>> selected, {
    String? name,
    required String fallbackName,
    String? sourcePlaylistKey,
  }) async {
    final normalizedName = name?.trim() ?? '';
    final title = normalizedName.isEmpty ? fallbackName : normalizedName;
    for (final existing in _currentCustomPlaylists()) {
      if (existing['source'] == 'user-created' &&
          existing['title']?.toString() == title &&
          (sourcePlaylistKey == null
              ? existing['importSourcePlaylistKey'] == null &&
                    existing['importSourceName']?.toString() == fallbackName
              : existing['importSourcePlaylistKey'] == sourcePlaylistKey)) {
        return _routeToExistingPlaylist(
          selected,
          playlistId: existing['ytid']?.toString(),
        );
      }
    }
    final playlist = <String, dynamic>{
      'ytid': PlaylistUtils.generateCustomPlaylistId(),
      'title': title,
      'source': 'user-created',
      'importSourceName': fallbackName,
      if (sourcePlaylistKey != null)
        'importSourcePlaylistKey': sourcePlaylistKey,
      'list': selected,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    final updated = <Map>[..._storedPlaylists('customPlaylists'), playlist];
    await _writeDestination('customPlaylists', updated);
    userCustomPlaylists.value = _storedPlaylists('customPlaylists');
    return SpotifyImportRouteResult(
      destinationTitle: title,
      selectedCount: selected.length,
      addedCount: selected.length,
      alreadyPresentCount: 0,
    );
  }

  Future<SpotifyImportRouteResult> _routeToExistingPlaylist(
    List<Map<String, dynamic>> selected, {
    String? playlistId,
  }) async {
    final id = playlistId?.trim() ?? '';
    if (id.isEmpty) throw StateError('Choose a destination playlist.');

    final root = _storedPlaylists(
      'customPlaylists',
    ).map(Map<String, dynamic>.from).toList(growable: true);
    final rootIndex = root.indexWhere(
      (playlist) => playlist['ytid']?.toString() == id,
    );
    if (rootIndex >= 0) {
      final outcome = _appendSongs(root[rootIndex], selected);
      root[rootIndex] = outcome.playlist;
      await _writeDestination('customPlaylists', root);
      userCustomPlaylists.value = _storedPlaylists('customPlaylists');
      return outcome.result;
    }

    final folders = _storedPlaylists(
      'playlistFolders',
    ).map(Map<String, dynamic>.from).toList(growable: true);
    for (var folderIndex = 0; folderIndex < folders.length; folderIndex++) {
      final folder = Map<String, dynamic>.from(folders[folderIndex]);
      final playlists = _folderPlaylists(folder);
      final playlistIndex = playlists.indexWhere(
        (playlist) => playlist['ytid']?.toString() == id,
      );
      if (playlistIndex < 0) continue;
      final outcome = _appendSongs(playlists[playlistIndex], selected);
      playlists[playlistIndex] = outcome.playlist;
      folder['playlists'] = playlists;
      folders[folderIndex] = folder;
      await _writeDestination('playlistFolders', folders);
      userPlaylistFolders.value = _storedPlaylists('playlistFolders');
      return outcome.result;
    }
    throw StateError('The selected playlist no longer exists.');
  }

  ({Map<String, dynamic> playlist, SpotifyImportRouteResult result})
  _appendSongs(
    Map<String, dynamic> playlist,
    List<Map<String, dynamic>> selected,
  ) {
    final existing = List<dynamic>.from(playlist['list'] as List? ?? const []);
    final existingIds = _songIds(existing);
    final additions = selected
        .where((song) => !existingIds.contains(song['ytid']?.toString()))
        .toList(growable: false);
    final updated = Map<String, dynamic>.from(playlist)
      ..['list'] = <dynamic>[...existing, ...additions];
    return (
      playlist: updated,
      result: SpotifyImportRouteResult(
        destinationTitle: playlist['title']?.toString() ?? 'Playlist',
        selectedCount: selected.length,
        addedCount: additions.length,
        alreadyPresentCount: selected.length - additions.length,
      ),
    );
  }

  Set<String> _destinationSongIds(
    SpotifyImportDestinationKind kind, {
    required SpotifyImportDestinationSnapshot snapshot,
    String? newPlaylistName,
    String? existingPlaylistId,
  }) {
    if (kind == SpotifyImportDestinationKind.likedSongs) {
      return _songIds(_currentLikedSongs());
    }
    if (kind == SpotifyImportDestinationKind.newPlaylist) {
      final requestedName = newPlaylistName?.trim() ?? '';
      final title = requestedName.isEmpty ? snapshot.sourceName : requestedName;
      for (final playlist in snapshot.customPlaylists) {
        if (playlist['source'] == 'user-created' &&
            playlist['title']?.toString() == title &&
            (snapshot.sourcePlaylistKey == null
                ? playlist['importSourcePlaylistKey'] == null &&
                      playlist['importSourceName']?.toString() ==
                          snapshot.sourceName
                : playlist['importSourcePlaylistKey'] ==
                      snapshot.sourcePlaylistKey)) {
          return _songIds(playlist['list'] as List? ?? const []);
        }
      }
      return <String>{};
    }
    final id = existingPlaylistId?.trim() ?? '';
    for (final playlist in snapshot.customPlaylists) {
      if (playlist['ytid']?.toString() == id) {
        return _songIds(playlist['list'] as List? ?? const []);
      }
    }
    return <String>{};
  }

  Future<void> _recordRouting(
    SpotifyImportDestinationSnapshot snapshot,
    SpotifyImportDestinationKind kind,
    SpotifyImportRouteResult result,
    SpotifyImportSelectionKind selectionKind,
    List<Map<String, dynamic>> selected,
    String operationId, {
    bool requireWholeSource = false,
  }) async {
    _validateCurrentSnapshot(snapshot, requireWholeSource: requireWholeSource);
    final box = Hive.box('user');
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    final pending = metadata[importRoutingPendingKey];
    if (_sessionId(metadata) != snapshot.importSessionId ||
        pending is! Map ||
        pending['operationId'] != operationId) {
      throw StateError('The transfer tracking checkpoint changed.');
    }
    final at = DateTime.now().toUtc().toIso8601String();
    final history = _readMaps(metadata['routingHistory'])
      ..add({
        'sourceName': snapshot.sourceName,
        'destinationKind': kind.name,
        'destinationTitle': result.destinationTitle,
        'selectedCount': result.selectedCount,
        'addedCount': result.addedCount,
        'alreadyPresentCount': result.alreadyPresentCount,
        'routedAt': at,
        'selectionKind': selectionKind.name,
        if (snapshot.sourcePlaylistKey != null)
          'sourcePlaylistKey': snapshot.sourcePlaylistKey,
        if (snapshot.sourcePlaylistFingerprint != null)
          'sourcePlaylistFingerprint': snapshot.sourcePlaylistFingerprint,
        'selectedRecordingIds': selected
            .map((song) => song['ytid']?.toString().trim())
            .toList(),
        'resolvedRecordings': snapshot.resolvedRecordings
            .map(Map<String, String>.from)
            .toList(),
        'resolutionSnapshotVersion': importRoutingStateVersion,
      });
    metadata['routingHistory'] = history;
    metadata[importRoutingBaselineKey] = importRoutingBaseline(
      sessionId: snapshot.importSessionId,
      rows: snapshot.resolvedRecordings,
      recordedAt: pending['confirmedAt']?.toString() ?? at,
      reliable: snapshot.recordingIdentitiesReliable,
      reason: 'confirmed_transfer',
    );
    metadata.remove(importRoutingPendingKey);
    await _writeRoutingMetadata(box, metadata);
    _validateCurrentSnapshot(snapshot, requireWholeSource: requireWholeSource);
  }

  static List<Map<String, dynamic>> _uniqueSongs(
    List<Map<String, dynamic>> results,
  ) {
    final ids = <String>{};
    final songs = <Map<String, dynamic>>[];
    for (final result in results) {
      final candidate = result['bestCandidate'];
      if (candidate is! Map) continue;
      final song = Map<String, dynamic>.from(candidate);
      final id = song['ytid']?.toString().trim() ?? '';
      if (id.isEmpty || !ids.add(id)) continue;
      song
        ..['importSourceRow'] = result['sourceRow']
        ..['importSourceTitle'] = result['sourceTitle']
        ..['importSourceArtist'] = result['sourceArtist'];
      songs.add(song);
    }
    return songs;
  }

  static bool _exclusionsKnown(Box<dynamic> box) {
    final raw = box.get('spotifyExcludedImportRows');
    return raw == null ||
        (raw is List && raw.every((row) => importRecordingRow(row) != null));
  }

  static List<Map<String, dynamic>> _effectiveResults(Box<dynamic> box) {
    final raw = box.get('spotifyExcludedImportRows');
    final excluded = raw is List
        ? raw.map(importRecordingRow).whereType<String>().toSet()
        : <String>{};
    return _readMaps(box.get('spotifyMatchResults'))
        .map((result) {
          // Read-only projection honors an exclusion even if interruption left its
          // prior matched outcome. Never repair or erase the owner's stored state.
          if (excluded.contains(importRecordingRow(result['sourceRow']))) {
            return Map<String, dynamic>.from(result)..['status'] = 'excluded';
          }
          return result;
        })
        .toList(growable: false);
  }

  static Set<String> _songIds(Iterable<dynamic> songs) => songs
      .whereType<Map>()
      .map((song) => song['ytid']?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();

  static bool _isResolved(Map<String, dynamic> result) {
    final status = result['status'];
    return (status == 'matched' || status == 'manually_matched') &&
        result['bestCandidate'] is Map;
  }

  static int _sourceRow(Map<String, dynamic> value) {
    final raw = value['sourceRow'];
    if (raw is num) return raw.round();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String _sourceRowKey(Map<String, dynamic> value) =>
      value['sourceRow']?.toString().trim() ?? '';

  static String _sourceName(String? fileName) {
    final value = fileName?.trim() ?? '';
    if (value.isEmpty) return 'Imported songs';
    return value.replaceFirst(RegExp(r'\.[^.]+$'), '').trim();
  }

  static Map<String, dynamic> _readMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _readMaps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: true);
  }
}
