/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/utilities/playlist_utils.dart';

enum SpotifyImportDestinationKind { likedSongs, newPlaylist, existingPlaylist }

class SpotifyImportDestinationSnapshot {
  const SpotifyImportDestinationSnapshot({
    required this.sourceName,
    required this.resolvedSongs,
    required this.resolvedResultCount,
    required this.unresolvedCount,
    required this.customPlaylists,
  });

  final String sourceName;
  final List<Map<String, dynamic>> resolvedSongs;
  final int resolvedResultCount;
  final int unresolvedCount;
  final List<Map<String, dynamic>> customPlaylists;

  int get duplicateMatchCount => resolvedResultCount - resolvedSongs.length;
}

class SpotifyImportRoutePreview {
  const SpotifyImportRoutePreview({
    required this.selectedCount,
    required this.newCount,
    required this.alreadyPresentCount,
    required this.unresolvedCount,
  });

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
  });

  final String destinationTitle;
  final int selectedCount;
  final int addedCount;
  final int alreadyPresentCount;
}

class SpotifyImportDestinationService {
  const SpotifyImportDestinationService();

  Future<SpotifyImportDestinationSnapshot> loadSnapshot() async {
    final box = Hive.box('user');
    final results = _readMaps(box.get('spotifyMatchResults'))
      ..sort((left, right) => _sourceRow(left).compareTo(_sourceRow(right)));
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    final resolved = results.where(_isResolved).toList(growable: false);
    final songs = _uniqueSongs(resolved);
    final customPlaylists = getUserCustomPlaylists()
        .map(Map<String, dynamic>.from)
        .toList(growable: false)
      ..sort(
        (left, right) => (left['title']?.toString() ?? '').toLowerCase().compareTo(
          (right['title']?.toString() ?? '').toLowerCase(),
        ),
      );

    return SpotifyImportDestinationSnapshot(
      sourceName: _sourceName(metadata['fileName']?.toString()),
      resolvedSongs: List.unmodifiable(songs),
      resolvedResultCount: resolved.length,
      unresolvedCount: results
          .where(
            (result) =>
                !_isResolved(result) && result['status'] != 'excluded',
          )
          .length,
      customPlaylists: List.unmodifiable(customPlaylists),
    );
  }

  SpotifyImportRoutePreview preview({
    required SpotifyImportDestinationSnapshot snapshot,
    required int requestedCount,
    required SpotifyImportDestinationKind destinationKind,
    String? existingPlaylistId,
  }) {
    final selected = selectSongs(snapshot, requestedCount);
    final existingIds = _destinationSongIds(
      destinationKind,
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
    );
  }

  List<Map<String, dynamic>> selectSongs(
    SpotifyImportDestinationSnapshot snapshot,
    int requestedCount,
  ) {
    final count = requestedCount.clamp(0, snapshot.resolvedSongs.length);
    return snapshot.resolvedSongs
        .take(count)
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  Future<SpotifyImportRouteResult> route({
    required SpotifyImportDestinationSnapshot snapshot,
    required int requestedCount,
    required SpotifyImportDestinationKind destinationKind,
    String? newPlaylistName,
    String? existingPlaylistId,
  }) async {
    final selected = selectSongs(snapshot, requestedCount);
    if (selected.isEmpty) {
      throw StateError('Choose at least one resolved song.');
    }

    final result = switch (destinationKind) {
      SpotifyImportDestinationKind.likedSongs => await _routeToLiked(selected),
      SpotifyImportDestinationKind.newPlaylist => await _routeToNewPlaylist(
          selected,
          name: newPlaylistName,
          fallbackName: snapshot.sourceName,
        ),
      SpotifyImportDestinationKind.existingPlaylist =>
        await _routeToExistingPlaylist(
          selected,
          playlistId: existingPlaylistId,
        ),
    };
    await _recordRouting(snapshot.sourceName, destinationKind, result);
    return result;
  }

  Future<SpotifyImportRouteResult> _routeToLiked(
    List<Map<String, dynamic>> selected,
  ) async {
    final existing = List<dynamic>.from(userLikedSongsList.value);
    final existingIds = _songIds(existing);
    final additions = selected
        .where((song) => !existingIds.contains(song['ytid']?.toString()))
        .toList(growable: false);
    final updated = <dynamic>[...additions, ...existing];
    await addOrUpdateData<List>('user', 'likedSongs', updated);
    userLikedSongsList.value = updated;
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
  }) async {
    final normalizedName = name?.trim() ?? '';
    final title = normalizedName.isEmpty ? fallbackName : normalizedName;
    for (final existing in userCustomPlaylists.value) {
      if (existing['source'] == 'user-created' &&
          existing['title']?.toString() == title &&
          existing['importSourceName']?.toString() == fallbackName) {
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
      'list': selected,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    final updated = <Map>[...userCustomPlaylists.value, playlist];
    await addOrUpdateData<List>('user', 'customPlaylists', updated);
    userCustomPlaylists.value = updated;
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

    final root = userCustomPlaylists.value
        .map(Map<String, dynamic>.from)
        .toList(growable: true);
    final rootIndex = root.indexWhere(
      (playlist) => playlist['ytid']?.toString() == id,
    );
    if (rootIndex >= 0) {
      final outcome = _appendSongs(root[rootIndex], selected);
      root[rootIndex] = outcome.playlist;
      await addOrUpdateData<List>('user', 'customPlaylists', root);
      userCustomPlaylists.value = root;
      return outcome.result;
    }

    final folders = userPlaylistFolders.value
        .map(Map<String, dynamic>.from)
        .toList(growable: true);
    for (var folderIndex = 0; folderIndex < folders.length; folderIndex++) {
      final folder = Map<String, dynamic>.from(folders[folderIndex]);
      final playlists = (folder['playlists'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: true);
      final playlistIndex = playlists.indexWhere(
        (playlist) => playlist['ytid']?.toString() == id,
      );
      if (playlistIndex < 0) continue;
      final outcome = _appendSongs(playlists[playlistIndex], selected);
      playlists[playlistIndex] = outcome.playlist;
      folder['playlists'] = playlists;
      folders[folderIndex] = folder;
      await addOrUpdateData<List>('user', 'playlistFolders', folders);
      userPlaylistFolders.value = folders;
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
    String? existingPlaylistId,
  }) {
    if (kind == SpotifyImportDestinationKind.likedSongs) {
      return _songIds(userLikedSongsList.value);
    }
    if (kind == SpotifyImportDestinationKind.newPlaylist) return <String>{};
    final id = existingPlaylistId?.trim() ?? '';
    for (final playlist in getUserCustomPlaylists()) {
      if (playlist['ytid']?.toString() == id) {
        return _songIds(playlist['list'] as List? ?? const []);
      }
    }
    return <String>{};
  }

  Future<void> _recordRouting(
    String sourceName,
    SpotifyImportDestinationKind kind,
    SpotifyImportRouteResult result,
  ) async {
    final box = Hive.box('user');
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    final history = _readMaps(metadata['routingHistory'])
      ..add({
        'sourceName': sourceName,
        'destinationKind': kind.name,
        'destinationTitle': result.destinationTitle,
        'selectedCount': result.selectedCount,
        'addedCount': result.addedCount,
        'alreadyPresentCount': result.alreadyPresentCount,
        'routedAt': DateTime.now().toUtc().toIso8601String(),
      });
    metadata['routingHistory'] = history;
    await addOrUpdateData<Map<String, dynamic>>(
      'user',
      'spotifyImportMetadata',
      metadata,
    );
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

  static String _sourceName(String? fileName) {
    final value = fileName?.trim() ?? '';
    if (value.isEmpty) return 'Imported songs';
    return value.replaceFirst(RegExp(r'\.[^.]+$'), '').trim();
  }

  static Map<String, dynamic> _readMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  static List<Map<String, dynamic>> _readMaps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: true);
  }
}
