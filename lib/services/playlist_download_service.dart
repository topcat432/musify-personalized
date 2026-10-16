// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/utilities/flutter_toast.dart';

enum OfflinePlaylistCompletionBoundary {
  membersValidated,
  relatedSongsValidated,
  registryCommitted,
}

typedef OfflinePlaylistCompletionProbe =
    Future<void> Function(OfflinePlaylistCompletionBoundary boundary);

class OfflinePlaylistService {
  factory OfflinePlaylistService() => _instance;
  OfflinePlaylistService._internal() {
    offlineAudioChecks.addListener(offlinePlaylists.notifyListeners);
  }
  static final OfflinePlaylistService _instance =
      OfflinePlaylistService._internal();

  // Playlist download state notifiers
  final Map<String, ValueNotifier<DownloadProgress>> downloadProgressNotifiers =
      {};
  final List<String> activeDownloads = [];
  final _playlistOwners = <String, Object>{};
  int _clearGeneration = 0;
  bool _clearing = false;

  // List of playlists that are fully available offline
  final offlinePlaylists = ValueNotifier<List<dynamic>>(
    Hive.box('userNoBackup').get('offlinePlaylists', defaultValue: []),
  );

  ValueNotifier<DownloadProgress> getProgressNotifier(String playlistId) {
    if (!downloadProgressNotifiers.containsKey(playlistId)) {
      downloadProgressNotifiers[playlistId] = ValueNotifier<DownloadProgress>(
        DownloadProgress(total: 0),
      );
    }
    return downloadProgressNotifiers[playlistId]!;
  }

  bool isPlaylistDownloaded(String playlistId) {
    return offlinePlaylists.value.any(
      (playlist) =>
          playlist['ytid'] == playlistId &&
          playlist['list'] is List &&
          isPlaylistFullyOffline(playlist['list']),
    );
  }

  bool isPlaylistDownloading(String playlistId) {
    return activeDownloads.contains(playlistId);
  }

  Future<void> downloadPlaylist(
    BuildContext context,
    Map playlist, {
    OfflineAudioLoader? audioLoader,
    OfflinePlaylistCompletionProbe? completionProbe,
  }) async {
    if (_clearing) return;
    final playlistId = playlist['ytid'] as String? ?? playlist['title'];

    if (playlistId == null || playlistId.isEmpty) {
      showToast(context, context.l10n!.error);
      return;
    }

    // Check if already downloading
    if (isPlaylistDownloading(playlistId)) {
      showToast(context, context.l10n!.alreadyDownloading);
      return;
    }

    // Initialize download state
    final songsList = playlist['list'] as List<dynamic>? ?? [];
    if (songsList.isEmpty) {
      showToast(context, context.l10n!.playlistEmpty);
      return;
    }

    // Set up progress tracking
    final progressNotifier = getProgressNotifier(playlistId)
      ..value = DownloadProgress(total: songsList.length);
    activeDownloads.add(playlistId);
    final owner = Object();
    final generation = _clearGeneration;
    _playlistOwners[playlistId] = owner;
    bool owns() =>
        generation == _clearGeneration &&
        !_clearing &&
        identical(_playlistOwners[playlistId], owner) &&
        identical(downloadProgressNotifiers[playlistId], progressNotifier) &&
        !progressNotifier.value.isCancelled;

    try {
      final songQueue = Queue<dynamic>.from(songsList);
      const maxConcurrent = 3;
      final workerCount = songsList.length < maxConcurrent
          ? songsList.length
          : maxConcurrent;

      await Future.wait([
        for (var i = 0; i < workerCount; i++)
          _processDownloadQueue(
            songQueue,
            progressNotifier,
            audioLoader: audioLoader,
            owns: owns,
          ),
      ]).timeout(
        Duration(minutes: songsList.length * 2),
        onTimeout: () {
          if (!owns()) return <void>[];
          logger.log('Download timeout for playlist $playlistId');
          progressNotifier.value.isCancelled = true;
          progressNotifier.notifyListeners();
          return <void>[];
        },
      );

      if (!owns()) return;
      // Handle completion
      await _handleDownloadCompletion(
        context,
        playlistId,
        playlist,
        progressNotifier,
        completionProbe: completionProbe,
        owns: owns,
      );
    } catch (e, stackTrace) {
      if (owns()) {
        logger.log(
          'Error during playlist download',
          error: e,
          stackTrace: stackTrace,
        );
        if (context.mounted) showToast(context, '${context.l10n!.error}: $e');
      }
    } finally {
      if (identical(_playlistOwners[playlistId], owner)) {
        _playlistOwners.remove(playlistId);
        activeDownloads.remove(playlistId);
        cleanupProgressNotifier(playlistId);
      }
    }
  }

  Future<void> _handleDownloadCompletion(
    BuildContext context,
    String playlistId,
    Map playlist,
    ValueNotifier<DownloadProgress> progressNotifier, {
    required bool Function() owns,
    OfflinePlaylistCompletionProbe? completionProbe,
  }) async {
    if (!owns()) return;
    final songsList = playlist['list'] as List<dynamic>;
    var membersValid = true;
    for (final song in songsList) {
      if (song is! Map ||
          !await validateRegisteredOfflineSong(song['ytid']?.toString() ?? ''))
        membersValid = false;
      if (!owns()) return;
    }
    if (completionProbe != null)
      await completionProbe(OfflinePlaylistCompletionBoundary.membersValidated);
    if (!owns()) return;
    if (!membersValid ||
        progressNotifier.value.failed != 0 ||
        progressNotifier.value.completed != songsList.length) {
      if (context.mounted)
        showToast(
          context,
          '${context.l10n!.downloadFailed}: ${progressNotifier.value.failed}/${songsList.length}',
        );
      return;
    }
    final offlineSongIds = <String>{};
    for (final row in List<dynamic>.from(
      userOfflineSongs.value,
    ).whereType<Map>()) {
      final id = row['ytid']?.toString() ?? '';
      if (await validateRegisteredOfflineSong(id)) offlineSongIds.add(id);
      if (!owns()) return;
    }
    if (completionProbe != null)
      await completionProbe(
        OfflinePlaylistCompletionBoundary.relatedSongsValidated,
      );
    if (!owns()) return;
    final published = await serializeOfflineRegistryMutation(() async {
      if (!owns()) return false;
      final box = Hive.box('userNoBackup');
      final current = box.get('offlinePlaylists', defaultValue: <dynamic>[]);
      if (current is! List)
        throw StateError('Offline playlist registry is not a list');
      final updated = List<dynamic>.from(current);
      final offlinePlaylist = {
        ...playlist,
        'ytid': playlistId,
        'list': songsList,
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
      };
      final index = updated.indexWhere(
        (row) => row is Map && row['ytid'] == playlistId,
      );
      if (index == -1) {
        updated.add(offlinePlaylist);
      } else {
        updated[index] = offlinePlaylist;
      }
      for (final p in playlists) {
        final list = p['list'] as List?;
        if (list == null ||
            list.isEmpty ||
            p['ytid'] == playlistId ||
            updated.any((row) => row is Map && row['ytid'] == p['ytid']))
          continue;
        if (list.every(
          (row) => row is Map && offlineSongIds.contains(row['ytid']),
        )) {
          updated.add({
            ...p,
            'list': list,
            'downloadedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
      if (!owns()) return false;
      await box.put('offlinePlaylists', updated);
      await box.flush();
      // A clear requested during the write is ordered behind us, and owns the
      // final empty state; this completion cannot update UI or announce success.
      if (!owns()) return false;
      offlinePlaylists.value = List<dynamic>.from(box.get('offlinePlaylists'));
      return true;
    });
    if (!published || !owns()) return;
    if (completionProbe != null)
      await completionProbe(
        OfflinePlaylistCompletionBoundary.registryCommitted,
      );
    if (!owns()) return;
    if (context.mounted)
      showToast(
        context,
        '${context.l10n!.playlistDownloaded}: ${progressNotifier.value.completed}/${songsList.length}',
      );
  }

  Future<void> cancelDownload(BuildContext context, String playlistId) async {
    if (!isPlaylistDownloading(playlistId)) return;

    try {
      final progressNotifier = getProgressNotifier(playlistId);
      progressNotifier.value.isCancelled = true;
      progressNotifier.notifyListeners();

      // Immediate visual feedback
      showToast(context, context.l10n!.cancellingDownload);

      const maxWaitTime = Duration(seconds: 30);
      final startTime = DateTime.now();

      // Wait for the ongoing tasks to complete with timeout
      while (activeDownloads.contains(playlistId)) {
        await Future.delayed(const Duration(milliseconds: 100));

        if (DateTime.now().difference(startTime) > maxWaitTime) {
          logger.log('Timeout waiting for download cancellation');
          activeDownloads.remove(playlistId);
          cleanupProgressNotifier(playlistId);
          break;
        }
      }

      showToast(context, context.l10n!.downloadCancelled);
    } catch (e, stackTrace) {
      logger.log('Error cancelling download', error: e, stackTrace: stackTrace);
      // Force remove from active downloads and cleanup on error
      activeDownloads.remove(playlistId);
      cleanupProgressNotifier(playlistId);
    }
  }

  Future<void> removeOfflinePlaylist(String playlistId) async {
    try {
      final normalizedPlaylistId = playlistId.trim();
      if (normalizedPlaylistId.isEmpty) {
        logger.log('Invalid playlistId for removal');
        return;
      }

      // Find the playlist
      final playlistIndex = offlinePlaylists.value.indexWhere(
        (playlist) =>
            playlist is Map &&
            playlist['ytid']?.toString() == normalizedPlaylistId,
      );

      if (playlistIndex == -1) {
        logger.log('Playlist not found for removal: $normalizedPlaylistId');
        return;
      }

      final playlist = offlinePlaylists.value[playlistIndex] as Map;

      // Get songs that are only in this playlist
      final songsInPlaylist = playlist['list'] as List<dynamic>? ?? [];
      for (final song in songsInPlaylist) {
        try {
          final songId = song['ytid'] as String?;

          if (songId == null || songId.isEmpty) {
            continue;
          }

          // Check if this song is used in other offline playlists
          final isUsedInOtherPlaylists = offlinePlaylists.value
              .where(
                (p) =>
                    p is Map && p['ytid']?.toString() != normalizedPlaylistId,
              ) // Exclude current playlist
              .any((p) {
                final playlistSongs = p['list'] as List<dynamic>? ?? [];
                return playlistSongs.any((s) => s['ytid'] == songId);
              });

          // Also check if song is in user's liked songs or OTHER custom playlists
          final isInLikedSongs = userLikedSongsList.value.any(
            (s) => s['ytid'] == songId,
          );
          final isInOtherCustomPlaylists = getUserCustomPlaylists()
              .where((p) => p['ytid']?.toString() != normalizedPlaylistId)
              .any((p) {
                final customPlaylistSongs = p['list'] as List<dynamic>? ?? [];
                return customPlaylistSongs.any((s) => s['ytid'] == songId);
              });

          // Only remove if not used elsewhere
          if (!isUsedInOtherPlaylists &&
              !isInLikedSongs &&
              !isInOtherCustomPlaylists) {
            await removeSongFromOffline(songId);
          }
        } catch (e, stackTrace) {
          logger.log(
            'Error removing song from offline',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      // Remove playlist from offline playlists
      final updatedPlaylists = List<dynamic>.from(offlinePlaylists.value)
        ..removeWhere(
          (p) => p is Map && p['ytid']?.toString() == normalizedPlaylistId,
        );
      offlinePlaylists.value = updatedPlaylists;
      unawaited(
        addOrUpdateData<List>(
          'userNoBackup',
          'offlinePlaylists',
          offlinePlaylists.value,
        ),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error removing offline playlist',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> deleteAllDownloads() async {
    final generation = ++_clearGeneration;
    _clearing = true;
    _playlistOwners.clear();
    for (final notifier in downloadProgressNotifiers.values) {
      notifier.value.isCancelled = true;
      notifier.notifyListeners();
    }
    // Logical owners are invalid immediately; a stalled scan need not finish
    // before clear, and can never publish after it eventually resumes.
    activeDownloads.clear();
    try {
      await cancelOfflineSongDownloads();
      await serializeOfflineRegistryMutation(() async {
        final tracksDir = Directory(
          '$applicationDirPath/${FilePaths.tracksDir}',
        );
        final artworksDir = Directory(
          '$applicationDirPath/${FilePaths.artworksDir}',
        );
        if (await tracksDir.exists()) await tracksDir.delete(recursive: true);
        if (await artworksDir.exists())
          await artworksDir.delete(recursive: true);
        await FilePaths.ensureDirectoriesExist();
        final box = Hive.box('userNoBackup');
        await box.put('offlineSongs', <dynamic>[]);
        await box.put('offlinePlaylists', <dynamic>[]);
        await box.flush();
        userOfflineSongs.value = [];
        offlinePlaylists.value = [];
        for (final notifier in downloadProgressNotifiers.values) {
          notifier.dispose();
        }
        downloadProgressNotifiers.clear();
        logger.log('All downloads deleted successfully');
      });
    } finally {
      if (generation == _clearGeneration) _clearing = false;
    }
  }

  void cleanupProgressNotifier(String playlistId) {
    try {
      if (downloadProgressNotifiers.containsKey(playlistId)) {
        final notifier = downloadProgressNotifiers[playlistId];
        notifier?.value = DownloadProgress(total: 0);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error cleaning up progress notifier',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _processDownloadQueue(
    Queue<dynamic> songQueue,
    ValueNotifier<DownloadProgress> progressNotifier, {
    OfflineAudioLoader? audioLoader,
    required bool Function() owns,
  }) async {
    while (songQueue.isNotEmpty && owns()) {
      final song = songQueue.removeFirst();

      try {
        if (song == null ||
            song['ytid'] == null ||
            song['ytid'].toString().isEmpty) {
          logger.log('Invalid song data in playlist download');
          progressNotifier.value.failed++;
          progressNotifier.notifyListeners();
          continue;
        }

        // Skip if already offline
        final valid = await validateRegisteredOfflineSong(
          song['ytid'].toString(),
        );
        if (!owns()) return;
        if (valid) {
          // Find the existing offline song to get the correct audioPath
          final offlineSong = getOfflineSongByYtid(song['ytid']);
          if (offlineSong.isNotEmpty) {
            // Update the song in the playlist with the correct offline properties
            song['audioPath'] =
                offlineSong['audioPath'] ??
                FilePaths.getAudioPath(song['ytid']);
            final artworkPath = offlineSong['artworkPath'];
            if (artworkPath is String) {
              song['artworkPath'] = artworkPath;
            } else {
              // Typed string rows and older offline records may have no art.
              song.remove('artworkPath');
            }
          }
          // Update progress
          progressNotifier.value.completed++;
          progressNotifier.notifyListeners();
        } else {
          final success = await makeSongOffline(
            song,
            audioLoader: audioLoader,
            shouldCancel: () => !owns(),
          );
          if (!owns()) return;
          if (success) {
            progressNotifier.value.completed++;
          } else {
            progressNotifier.value.failed++;
          }
          progressNotifier.notifyListeners();
        }
      } catch (e, stackTrace) {
        if (!owns()) return;
        logger.log(
          'Failed to download song: ${song?['title']}',
          error: e,
          stackTrace: stackTrace,
        );
        progressNotifier.value.failed++;
        progressNotifier.notifyListeners();
      }
    }
  }
}

class DownloadProgress {
  DownloadProgress({
    required this.total,
    this.completed = 0,
    this.failed = 0,
    this.isCancelled = false,
  });

  final int total;
  int completed;
  int failed;
  bool isCancelled;

  double get progress {
    if (total <= 0) return 0;
    final totalProcessed = completed + failed;
    return totalProcessed > total ? 1.0 : totalProcessed / total;
  }

  @override
  String toString() {
    final percentage = (progress * 100).toStringAsFixed(1);
    return '$percentage% ($completed/$total)';
  }
}

// Global instance for easy access
final offlinePlaylistService = OfflinePlaylistService();
