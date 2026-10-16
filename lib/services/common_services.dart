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
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:musify/main.dart' show logger;
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/lyrics_manager.dart';
import 'package:musify/services/offline_audio_integrity.dart';
import 'package:musify/services/offline_file_publication.dart';
import 'package:musify/services/online_audio_source.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/proxy_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/shared_song_metadata.dart';
import 'package:musify/services/stream_request_context.dart';
import 'package:musify/services/stream_url_validation.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/formatter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

List globalSongs = [];

ValueNotifier<List> userLikedSongsList = ValueNotifier<List>(
  Hive.box('user').get('likedSongs', defaultValue: []),
);

ValueNotifier<List> userRecentlyPlayed = ValueNotifier<List>(
  Hive.box('user').get('recentlyPlayedSongs', defaultValue: []),
);
ValueNotifier<List> userOfflineSongs = ValueNotifier<List>(
  Hive.box('userNoBackup').get('offlineSongs', defaultValue: []),
);

final offlineAudioChecks = ValueNotifier<Map<String, OfflineAudioCheck>>({});
int _offlineCheckGeneration = 0;
bool _offlineChecksStarted = false;
final _offlineCheckedRows = <String, String>{};
String _offlineRowKey(Map row) => jsonEncode([
  row['ytid'],
  row['audioPath'],
  row['offlineAudioBytes'],
  row['offlineAudioSha256'],
]);

void startOfflineAudioValidation() {
  if (!_offlineChecksStarted) {
    _offlineChecksStarted = true;
    userOfflineSongs.addListener(
      () => unawaited(refreshOfflineAudioAvailability()),
    );
  }
  unawaited(refreshOfflineAudioAvailability());
}

Future<void> refreshOfflineAudioAvailability() async {
  final generation = ++_offlineCheckGeneration;
  final rows = List<dynamic>.from(userOfflineSongs.value);
  _offlineCheckedRows.clear();
  offlineAudioChecks.value = {};
  final checks = <String, OfflineAudioCheck>{};
  for (final row in rows.whereType<Map>()) {
    final id = row['ytid']?.toString();
    if (id == null || id.isEmpty) continue;
    checks[id] = await checkOfflineAudio(
      row,
      fallbackPath: FilePaths.getAudioPath(id),
    );
    if (generation != _offlineCheckGeneration) return;
    _offlineCheckedRows[id] = _offlineRowKey(row);
  }
  if (generation == _offlineCheckGeneration) offlineAudioChecks.value = checks;
}

bool isOfflineSongPlayable(Map row) {
  final check = offlineAudioChecks.value[row['ytid']?.toString()];
  if (check?.playable != true ||
      _offlineCheckedRows[row['ytid']?.toString()] != _offlineRowKey(row))
    return false;
  return check?.path ==
      (row['audioPath'] ?? FilePaths.getAudioPath(row['ytid'].toString()));
}

Future<bool> validateRegisteredOfflineSong(String id) async {
  Map? currentRow() {
    final rows = Hive.box('userNoBackup').get('offlineSongs', defaultValue: []);
    if (rows is! List) return null;
    return rows.whereType<Map>().where((row) => row['ytid'] == id).firstOrNull;
  }

  final row = currentRow();
  if (row == null) return false;
  final key = _offlineRowKey(row);
  final check = await checkOfflineAudio(
    row,
    fallbackPath: FilePaths.getAudioPath(id),
  );
  final latest = currentRow();
  if (latest == null || _offlineRowKey(latest) != key) return false;
  _offlineCheckedRows[id] = key;
  offlineAudioChecks.value = {...offlineAudioChecks.value, id: check};
  return check.playable;
}

dynamic nextRecommendedSong;

var _songLikeUpdateToken = 0;
final _latestSongLikeUpdateTokens = <String, int>{};

final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;
typedef SongLyricsLoader =
    Future<String?> Function(String artist, String title);
int _lyricsRequestGeneration = 0;
_LyricsRequest? _pendingLyrics;

class _LyricsRequest {
  _LyricsRequest(this.key);
  final String key;
  late final Future<String?> future;
}

void reloadSongLibraryStateFromStorage() {
  final userBox = Hive.box('user');
  userLikedSongsList.value = List.from(
    userBox.get('likedSongs', defaultValue: []),
  );
  userRecentlyPlayed.value = List.from(
    userBox.get('recentlyPlayedSongs', defaultValue: []),
  );
  userOfflineSongs.value = List.from(
    Hive.box('userNoBackup').get('offlineSongs', defaultValue: []),
  );
}

// Timeouts and durations used across manifest fetching and cache validation.
const Duration _manifestTimeout = Duration(seconds: 30);
const Duration _cacheValidationDuration = Duration(hours: 1);

/// Fetches a stream manifest for a song, honoring proxy settings.
Future<StreamManifest?> _fetchStreamManifest(
  String songId, {
  bool preferMuxed = true,
}) async {
  if (useProxy.value) {
    return ProxyManager().getSongManifest(songId).timeout(_manifestTimeout);
  }

  return ytClient.videos.streams
      .getManifestWithSelectedLength(
        songId,
        ytClients: [YoutubeApiClient.androidSdkless],
        streamForValidation: (streams) => selectPlaybackStreamForQuality(
          StreamManifest(streams),
          songId,
          preferMuxed: preferMuxed,
        ),
      )
      .timeout(_manifestTimeout);
}

/// Returns a cached song URL if present and still valid.
Future<String?> _getCachedSongUrl(
  String cacheKey,
  Duration cacheDuration,
) async {
  final cachedUrl = await getData(
    'cache',
    cacheKey,
    cachingDuration: cacheDuration,
  );

  if (cachedUrl is! String || cachedUrl.isEmpty) {
    return null;
  }

  final cacheBox = await Hive.openBox('cache');
  if (StreamRequestContexts.supports(cachedUrl) &&
      !streamRequestContexts.restore(
        cachedUrl,
        cacheBox.get('${cacheKey}_requestContext'),
      )) {
    // Retain legacy/partial cache data, but do not guess its resolving identity
    // or send a media validation request with unknown provenance.
    return null;
  }
  if (StreamRequestContexts.supports(cachedUrl) &&
      streamRequestContexts.lengthForUrl(cachedUrl) == null &&
      (int.tryParse(Uri.parse(cachedUrl).queryParameters['clen'] ?? '') ?? 0) <=
          0) {
    // Keep old cache bytes intact; obtain selected-format length before reuse.
    return null;
  }
  final cacheDate = cacheBox.get('${cacheKey}_date') as DateTime?;
  final now = DateTime.now();
  final isOld =
      cacheDate != null && now.difference(cacheDate) > _cacheValidationDuration;

  if (!isOld) {
    return cachedUrl;
  }

  if (await _validateCachedUrl(cachedUrl)) {
    return cachedUrl;
  }

  await deleteData('cache', cacheKey);
  await deleteData('cache', '${cacheKey}_date');
  return null;
}

/// Checks if a cached URL still responds successfully.
Future<bool> _validateCachedUrl(String cachedUrl) async {
  return validateStreamUrl(
    cachedUrl,
    headers: streamRequestContexts.forUrl(cachedUrl) ?? const {},
  );
}

Future<List> fetchSongsList(String searchQuery) async {
  try {
    // If not in cache, perform the search
    final List<Video> searchResults = await ytClient.search.search(searchQuery);
    final songsList = searchResults
        .map((video) => returnSongLayout(0, video))
        .toList();

    return songsList;
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsList', error: e, stackTrace: stackTrace);
    return [];
  }
}

Future<List> getRecommendedSongs() async {
  try {
    if (externalRecommendations.value && userRecentlyPlayed.value.isNotEmpty) {
      return await _getRecommendationsFromRecentlyPlayed();
    } else {
      return await _getRecommendationsFromMixedSources();
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error in getRecommendedSongs',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
  }
}

Future<List> _getRecommendationsFromRecentlyPlayed() async {
  final recent = (List.from(
    userRecentlyPlayed.value,
  )..shuffle()).take(5).toList();

  final scores = <String, double>{};
  final songMap = <String, Map>{};

  final futures = recent.asMap().entries.map((entry) async {
    final seedIndex = entry.key;
    final songData = entry.value;
    try {
      final song = await ytClient.videos.get(songData['ytid']);
      final related = await ytClient.videos.getRelatedVideos(song) ?? [];
      for (var i = 0; i < related.length && i < 8; i++) {
        final s = returnSongLayout(0, related[i]);
        final id = s['ytid'];
        final positionWeight = 1.0 - (i / 8);
        final recencyWeight = 1.0 - (seedIndex / recent.length);
        scores[id] = (scores[id] ?? 0) + positionWeight * recencyWeight;
        songMap[id] = s;
      }
    } catch (e, st) {
      logger.log(
        'related videos error for ${songData['ytid']}',
        error: e,
        stackTrace: st,
      );
    }
  }).toList();

  await Future.wait(futures);

  final sorted = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(15).map((e) => songMap[e.key]!).toList();
}

Future<List> _getRecommendationsFromMixedSources() async {
  final playlistSongs = [
    ...userLikedSongsList.value,
    ...userRecentlyPlayed.value,
  ];

  if (globalSongs.isEmpty) {
    const playlistId = 'PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx';
    globalSongs = await getSongsFromPlaylist(playlistId);
  }
  playlistSongs.addAll(globalSongs.take(10));

  if (userCustomPlaylists.value.isNotEmpty) {
    for (final userPlaylist in userCustomPlaylists.value) {
      final _list = List.from(userPlaylist['list'] as List)..shuffle();
      playlistSongs.addAll(_list.take(5));
    }
  }

  return _deduplicateAndShuffle(playlistSongs);
}

List _deduplicateAndShuffle(List playlistSongs) {
  final seenYtIds = <String>{};
  final uniqueSongs = <Map>[];

  playlistSongs.shuffle();

  for (final song in playlistSongs) {
    if (song['ytid'] != null && seenYtIds.add(song['ytid'])) {
      uniqueSongs.add(song);
      // Early exit when we have enough songs
      if (uniqueSongs.length >= 15) break;
    }
  }

  return uniqueSongs;
}

Future<void> updateSongLikeStatus(
  dynamic songId,
  bool add, {
  Map? songData,
}) async {
  try {
    final normalizedSongId = songId?.toString().trim() ?? '';
    if (normalizedSongId.isEmpty) return;

    final updateToken = ++_songLikeUpdateToken;
    _latestSongLikeUpdateTokens[normalizedSongId] = updateToken;

    final songToAdd = add
        ? await _resolveSongForLikedStatus(normalizedSongId, songData)
        : null;

    if (_latestSongLikeUpdateTokens[normalizedSongId] != updateToken) {
      return;
    }

    final updatedLikedSongs = _deduplicateLikedSongs(userLikedSongsList.value);

    if (add) {
      if (songToAdd != null &&
          !updatedLikedSongs.any(
            (song) => song['ytid']?.toString() == normalizedSongId,
          )) {
        updatedLikedSongs.insert(0, songToAdd);
      }
    } else {
      updatedLikedSongs.removeWhere(
        (song) => song['ytid']?.toString() == normalizedSongId,
      );
    }

    if (_likedSongIdsAreEqual(userLikedSongsList.value, updatedLikedSongs))
      return;

    userLikedSongsList.value = updatedLikedSongs;
    unawaited(
      addOrUpdateData<List>('user', 'likedSongs', userLikedSongsList.value),
    );
  } catch (e, stackTrace) {
    logger.log(
      'Error updating song like status',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<Map?> _resolveSongForLikedStatus(String songId, Map? songData) async {
  if (songData?['ytid']?.toString() == songId) {
    return Map<String, dynamic>.from(songData!);
  }

  final cachedSong = _findSongById(userLikedSongsList.value, songId);
  if (cachedSong != null) return Map<String, dynamic>.from(cachedSong);

  return getSongDetails(userLikedSongsList.value.length, songId);
}

Map? _findSongById(Iterable<dynamic> songs, String songId) {
  for (final song in songs) {
    if (song is Map && song['ytid']?.toString() == songId) return song;
  }

  return null;
}

List _deduplicateLikedSongs(Iterable<dynamic> likedSongs) {
  final seenSongIds = <String>{};
  final deduplicatedSongs = [];

  for (final song in likedSongs) {
    if (song is! Map) {
      deduplicatedSongs.add(song);
      continue;
    }

    final songId = song['ytid']?.toString();
    if (songId == null || songId.isEmpty) {
      deduplicatedSongs.add(song);
      continue;
    }

    if (seenSongIds.add(songId)) {
      deduplicatedSongs.add(song);
    }
  }

  return deduplicatedSongs;
}

bool _likedSongIdsAreEqual(List previous, List updated) {
  if (previous.length != updated.length) return false;

  for (var i = 0; i < previous.length; i++) {
    final previousSong = previous[i];
    final updatedSong = updated[i];
    if (previousSong is! Map || updatedSong is! Map) {
      if (previousSong != updatedSong) return false;
      continue;
    }

    if (previousSong['ytid']?.toString() != updatedSong['ytid']?.toString()) {
      return false;
    }
  }

  return true;
}

Future<void> renameSongInLikedSongs(
  dynamic songId,
  String newTitle,
  String newArtist,
) async {
  try {
    final songIndex = userLikedSongsList.value.indexWhere(
      (song) => song['ytid'] == songId,
    );

    if (songIndex != -1) {
      final updatedList = List.from(userLikedSongsList.value);
      updatedList[songIndex] = Map.from(updatedList[songIndex] as Map)
        ..['title'] = newTitle
        ..['artist'] = newArtist;
      userLikedSongsList.value = updatedList;

      unawaited(
        addOrUpdateData<List>('user', 'likedSongs', userLikedSongsList.value),
      );
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error renaming song in liked songs',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

bool isSongAlreadyLiked(songIdToCheck) {
  final songId = songIdToCheck?.toString();
  return userLikedSongsList.value.any(
    (song) => song['ytid']?.toString() == songId,
  );
}

bool isPlaylistAlreadyLiked(playlistIdToCheck) {
  final playlistId = playlistIdToCheck?.toString();
  if (playlistId == null || playlistId.isEmpty) return false;
  return userLikedPlaylists.value.any(
    (playlist) => playlist['ytid']?.toString() == playlistId,
  );
}

bool isSongAlreadyOffline(songIdToCheck) =>
    userOfflineSongs.value.any((song) => song['ytid'] == songIdToCheck);

bool isPlaylistFullyOffline(List songs) {
  if (songs.isEmpty) return false;
  final offlineIds = userOfflineSongs.value
      .whereType<Map>()
      .where(isOfflineSongPlayable)
      .map((s) => s['ytid'])
      .toSet();
  return songs.every((s) => offlineIds.contains(s['ytid']));
}

Map<String, dynamic> getOfflineSongByYtid(String ytid) {
  try {
    final song = userOfflineSongs.value.firstWhere(
      (s) => s['ytid'] == ytid,
      orElse: () => <String, dynamic>{},
    );
    return Map<String, dynamic>.from(song);
  } catch (_) {
    return <String, dynamic>{};
  }
}

Future<List<String>> getSearchSuggestions(String query) async {
  // Custom implementation:

  // const baseUrl = 'https://suggestqueries.google.com/complete/search';
  // final parameters = {
  //   'client': 'firefox',
  //   'ds': 'yt',
  //   'q': query,
  // };

  // final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);

  // try {
  //   final response = await http.get(
  //     uri,
  //     headers: {
  //       'User-Agent':
  //           'Mozilla/5.0 (Windows NT 10.0; rv:96.0) Gecko/20100101 Firefox/96.0',
  //     },
  //   );

  //   if (response.statusCode == 200) {
  //     final suggestions = jsonDecode(response.body)[1] as List<dynamic>;
  //     final suggestionStrings = suggestions.cast<String>().toList();
  //     return suggestionStrings;
  //   }
  // } catch (e, stackTrace) {
  //   logger.log('Error in getSearchSuggestions:$e\n$stackTrace');
  // }

  // Built-in implementation:

  final suggestions = await ytClient.search.getQuerySuggestions(query);

  return suggestions;
}

Future<List<Map<String, int>>> getSkipSegments(String id) async {
  try {
    final res = await ProxyManager().getProxiedResponse(
      Uri(
        scheme: 'https',
        host: 'sponsor.ajay.app',
        path: '/api/skipSegments',
        queryParameters: {
          'videoID': id,
          'category': [
            'sponsor',
            'selfpromo',
            'interaction',
            'intro',
            'outro',
            'music_offtopic',
          ],
          'actionType': 'skip',
        },
      ),
    );
    if (res.statusCode == 200 && res.body != 'Not Found') {
      final data = jsonDecode(res.body);
      final segments = data.map((obj) {
        return Map.castFrom<String, dynamic, String, int>({
          'start': obj['segment'].first.toInt(),
          'end': obj['segment'].last.toInt(),
        });
      }).toList();
      return List.castFrom<dynamic, Map<String, int>>(segments);
    } else {
      return [];
    }
  } catch (e, stackTrace) {
    logger.log('Error in getSkipSegments', error: e, stackTrace: stackTrace);
    return [];
  }
}

Future<void> getSimilarSong(String songYtId) async {
  try {
    final song = await ytClient.videos.get(songYtId);
    final relatedSongs = await ytClient.videos.getRelatedVideos(song) ?? [];

    if (relatedSongs.isNotEmpty) {
      nextRecommendedSong = returnSongLayout(0, relatedSongs[0]);
    } else {
      logger.log('No related songs found for $songYtId');
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error while fetching next similar song:',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// Fetches the best available audio stream for a song.
Future<AudioOnlyStreamInfo?> fetchBestAudioStream(String? songId) async {
  try {
    if (songId == null || songId.isEmpty) {
      logger.log('fetchBestAudioStream: songId is null or empty');
      return null;
    }

    final manifest = await _fetchStreamManifest(songId, preferMuxed: false);
    final audioStream = manifest?.audioOnly;
    if (audioStream == null || audioStream.isEmpty) {
      logger.log('fetchBestAudioStream: no audio streams for $songId');
      return null;
    }
    return selectAudioOnlyStreamForQuality(audioStream.sortByBitrate());
  } on TimeoutException catch (_) {
    logger.log('fetchBestAudioStream request timed out for $songId');
    return null;
  } catch (e, stackTrace) {
    logger.log(
      'Error while fetching best audio stream',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Keeps playback cache publication and invalidation in the resolver's mode.
String songStreamUrlCacheKey(String songId, {bool preferMuxed = true}) =>
    preferMuxed
    ? 'song_${songId}_muxed_${audioQualitySetting.value}_url'
    : 'song_${songId}_${audioQualitySetting.value}_url';

/// Resolves a playable stream URL for the selected video.
/// Prefer a supported muxed format before playback; audio-only remains available
/// when the manifest has no compatible muxed format. Never switch on a denial.
/// Compatibility streams may carry video bytes, so audio bitrate is not promised.
Future<String?> fetchSongStreamUrl(
  String songId,
  bool isLive, {
  bool preferMuxed = true,
  Future<StreamManifest?> Function(String)? manifestLoader,
}) async {
  try {
    if (songId.isEmpty) {
      logger.log('fetchSongStreamUrl: songId is empty');
      return null;
    }
    if (isLive) {
      final streamInfo = await ytClient.videos.streamsClient
          .getHttpLiveStreamUrl(VideoId(songId));
      return streamInfo;
    }

    const _cacheDuration = Duration(hours: 3);
    final cacheKey = songStreamUrlCacheKey(songId, preferMuxed: preferMuxed);

    // Try to get from cache
    final cachedUrl = await _getCachedSongUrl(cacheKey, _cacheDuration);
    if (cachedUrl != null) {
      return cachedUrl;
    }

    // Get fresh URL
    final manifest =
        await (manifestLoader?.call(songId) ??
            _fetchStreamManifest(songId, preferMuxed: preferMuxed));
    final selectedStream = manifest == null
        ? null
        : selectPlaybackStreamForQuality(
            manifest,
            songId,
            preferMuxed: preferMuxed,
          );
    if (selectedStream == null) {
      logger.log('fetchSongStreamUrl: no playable audio formats for $songId');
      return null;
    }
    final url = selectedStream.url.toString();

    final requestHeaders = ytClient.videos.streams.requestHeadersFor(
      selectedStream,
    );
    if (StreamRequestContexts.supports(url) && requestHeaders != null) {
      streamRequestContexts.remember(
        url,
        requestHeaders,
        sourceLength: selectedStream.size.totalBytes,
      );
      final context = streamRequestContexts.snapshot(url);
      if (context != null) {
        try {
          await addOrUpdateData<Map<String, Object>>(
            'cache',
            '${cacheKey}_requestContext',
            context,
          );
        } catch (error, stackTrace) {
          logger.log(
            'Could not cache stream request context',
            error: error,
            stackTrace: stackTrace,
          );
          // The fresh in-memory source is still usable; do not publish an
          // incomplete URL/context cache pair or disturb older cached data.
          return url;
        }
      }
    }

    unawaited(addOrUpdateData<String>('cache', cacheKey, url));

    return url;
  } on TimeoutException catch (_) {
    logger.log('fetchSongStreamUrl request timed out for $songId');
    return null;
  } catch (e, stackTrace) {
    logger.log(
      'Error in fetchSongStreamUrl for $songId:',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<Map<String, dynamic>> getSongDetails(
  int songIndex,
  String songId,
) async {
  try {
    final song = await ytClient.videos.get(songId);
    return returnSongLayout(songIndex, song);
  } catch (e, stackTrace) {
    logger.log(
      'Song metadata fetch failed',
      error: sharedSongFailureDiagnostic(e, phase: 'watch-metadata'),
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<String?> getSongLyrics(
  String? artist,
  String title, {
  String? recordingId,
  SongLyricsLoader? loader,
}) {
  if (artist == null) return Future.value();
  final key = jsonEncode([recordingId ?? '', artist, title]);
  if (lastFetchedLyrics == key && lyrics.value != null) {
    return Future.value(lyrics.value);
  }
  final pending = _pendingLyrics;
  if (pending != null && pending.key == key) return pending.future;

  final generation = ++_lyricsRequestGeneration;
  lyrics.value = null;
  lastFetchedLyrics = null;
  final request = _LyricsRequest(key);
  _pendingLyrics = request;
  request.future =
      Future<String?>.sync(
            () => (loader ?? LyricsManager().fetchLyrics)(artist, title),
          )
          .then((value) {
            final text = value
                ?.replaceAll(RegExp(r'\n{4}'), '\n\n')
                .replaceAll(RegExp(r'\n{2}'), '\n');
            if (generation == _lyricsRequestGeneration) {
              lyrics.value = text;
              lastFetchedLyrics = text == null ? null : key;
            }
            return text;
          })
          .whenComplete(() {
            if (identical(_pendingLyrics, request)) _pendingLyrics = null;
          });
  return request.future;
}

class OfflineAudioDownload {
  const OfflineAudioDownload(this.stream, {this.expectedBytes});
  final Stream<List<int>> stream;
  final int? expectedBytes;
}

typedef OfflineAudioLoader = Future<OfflineAudioDownload?> Function(String id);
typedef OfflineArtworkLoader = Future<List<int>?> Function(String url);
typedef OfflineRegistryWriter =
    Future<void> Function(Box<dynamic> box, List<dynamic> songs);

/// Optional owned acceptance probe; normal downloads supply no callback.
enum OfflineCommitBoundary {
  bodyFlushed,
  ownershipFlushed,
  beforeRename,
  afterRename,
  registryWritten,
  registryFlushed,
  ownershipRemoved,
  beforeReturn,
}

typedef OfflineCommitProbe =
    Future<void> Function(OfflineCommitBoundary boundary);
final Map<String, Future<bool>> _offlineDownloads = {};
Future<void> _offlineRegistryTail = Future.value();
int _offlineCancellationGeneration = 0;

Future<void> cancelOfflineSongDownloads() async {
  _offlineCancellationGeneration++;
  await Future.wait(_offlineDownloads.values.toList());
}

Future<T> _serializeOfflineCommit<T>(Future<T> Function() action) {
  final result = _offlineRegistryTail.then((_) => action());
  _offlineRegistryTail = result.then<void>(
    (_) {},
    onError: (Object _, StackTrace __) {},
  );
  return result;
}

String _offlinePathKey(String value) => Platform.isWindows
    ? value.split(Platform.pathSeparator).join('/').toLowerCase()
    : value;

// Explicit retry may roll back our own interrupted rename, never adopt it.
// Legacy/unknown payloads and malformed ownership proofs remain untouched.
Future<bool> _rollbackOwnedUnregisteredOffline(
  File audio,
  String id,
  bool Function() cancelled,
) => _serializeOfflineCommit(() async {
  final registry = Hive.box(
    'userNoBackup',
  ).get('offlineSongs', defaultValue: []);
  if (registry is! List ||
      registry.whereType<Map>().any(
        (row) =>
            row['ytid'] == id ||
            (row['audioPath'] is String &&
                _offlinePathKey(row['audioPath'] as String) ==
                    _offlinePathKey(audio.path)),
      ))
    return false;
  for (final marker
      in audio.parent.listSync(followLinks: false).whereType<File>()) {
    if (!_offlinePathKey(marker.path)
            .split('/')
            .last
            .startsWith(
              '${_offlinePathKey(audio.path).split('/').last}.download-',
            ) ||
        !marker.path.endsWith('.part.owner.json'))
      continue;
    try {
      final data = jsonDecode(await marker.readAsString());
      if (data is! Map ||
          data['schema'] != 1 ||
          data['ytid'] != id ||
          data['audioPath'] != audio.path)
        continue;
      final partial = data['partialPath'];
      final expected = data['expectedBytes'];
      final digest = data['sha256'];
      final prefix = '${audio.path}.download-';
      if (partial is! String ||
          !partial.startsWith(prefix) ||
          !partial.endsWith('.part') ||
          _offlinePathKey(marker.path) !=
              _offlinePathKey('$partial.owner.json') ||
          !RegExp(
            r'^\d+$',
          ).hasMatch(partial.substring(prefix.length, partial.length - 5)) ||
          expected is! int ||
          expected <= 0 ||
          digest is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest))
        continue;
      if (await audio.length() != expected ||
          (await sha256.bind(audio.openRead()).first).toString() != digest)
        continue;
      if (data['sourceLinkRequired'] == true &&
          (!await File(partial).exists() ||
              !await FileSystemEntity.identical(audio.path, partial)))
        continue;
      if (registry.whereType<Map>().any(
        (row) =>
            row['audioPath'] is String &&
            _offlinePathKey(row['audioPath']) == _offlinePathKey(partial),
      ))
        continue;
      if (cancelled()) return false;
      await audio.delete();
      if (data['sourceLinkRequired'] == true) await File(partial).delete();
      try {
        await marker.delete();
      } catch (_) {
        /* Retain proof if cleanup fails. */
      }
      return true;
    } catch (_) {
      // Do not erase a malformed marker or a payload of unknown ownership.
    }
  }
  return false;
});

Stream<List<int>> _checkedOfflineStream(
  OfflineAudioDownload audio,
  bool Function() cancelled,
) {
  late StreamController<List<int>> controller;
  StreamSubscription<List<int>>? upstream;
  Timer? timer;
  var finished = false;
  var received = 0;
  void fail(Object error, [StackTrace? stack]) {
    if (finished) return;
    finished = true;
    timer?.cancel();
    controller.addError(error, stack);
    unawaited(upstream?.cancel());
    unawaited(controller.close());
  }

  controller = StreamController<List<int>>(
    onListen: () {
      timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (cancelled()) fail(StateError('Offline download cancelled'));
      });
      upstream = audio.stream.listen(
        (bytes) {
          if (finished) return;
          if (cancelled()) {
            fail(StateError('Offline download cancelled'));
            return;
          }
          received += bytes.length;
          if (received > audio.expectedBytes!) {
            fail(StateError('Offline audio exceeds its declared length'));
            return;
          }
          controller.add(bytes);
        },
        onError: fail,
        onDone: () {
          if (finished) return;
          if (cancelled() || received != audio.expectedBytes) {
            fail(StateError('Offline audio is cancelled or incomplete'));
            return;
          }
          finished = true;
          timer?.cancel();
          unawaited(controller.close());
        },
      );
    },
    onPause: () => upstream?.pause(),
    onResume: () => upstream?.resume(),
    onCancel: () async {
      timer?.cancel();
      await upstream?.cancel();
    },
  );
  return controller.stream.timeout(const Duration(seconds: 30));
}

class _OfflineDigestCollector implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Downloads the selected recording using the same compatibility policy as
/// playback. Availability probing is not download success; the writer still
/// requires the complete declared body before publishing an offline entry.
Future<OfflineAudioDownload?> fetchCompatibleOfflineAudio(
  String id, {
  Future<StreamManifest?> Function(String)? manifestLoader,
  http.Client Function()? clientFactory,
}) async {
  final manifest = await (manifestLoader?.call(id) ?? _fetchStreamManifest(id));
  final stream = manifest == null
      ? null
      : selectPlaybackStreamForQuality(manifest, id, preferMuxed: true);
  if (stream == null) return null;
  final headers =
      ytClient.videos.streams.requestHeadersFor(stream) ??
      const <String, String>{};
  if (GoogleVideoByteSource.accepts(stream.url, stream.size.totalBytes)) {
    final source = GoogleVideoByteSource(
      stream.url,
      sourceLength: stream.size.totalBytes,
      requestHeaders: headers,
      clientFactory: clientFactory,
    );
    return OfflineAudioDownload(
      _completeOfflineSource(source),
      expectedBytes: stream.size.totalBytes,
    );
  }
  return OfflineAudioDownload(
    ytClient.videos.streamsClient.get(stream),
    expectedBytes: stream.size.totalBytes,
  );
}

Stream<List<int>> _completeOfflineSource(GoogleVideoByteSource source) async* {
  try {
    final response = await source.request();
    yield* response.stream;
  } finally {
    await source.cancelRequests();
  }
}

Future<bool> makeSongOffline(
  dynamic song, {
  OfflineAudioLoader? audioLoader,
  OfflineArtworkLoader? artworkLoader,
  OfflineRegistryWriter? registryWriter,
  OfflineCommitProbe? commitProbe,
  bool Function()? shouldCancel,
}) async {
  if (song is! Map || song['ytid'] is! String) return false;
  final id = song['ytid'] as String;
  if (id.isEmpty ||
      id == '.' ||
      id == '..' ||
      id.contains(RegExp(r'[/\\\x00]')))
    return false;
  final pending = _offlineDownloads[id];
  if (pending != null) return pending;
  final generation = _offlineCancellationGeneration;
  final future = _makeSongOffline(
    Map<String, dynamic>.from(song),
    audioLoader: audioLoader,
    artworkLoader: artworkLoader,
    registryWriter: registryWriter,
    commitProbe: commitProbe,
    cancelled: () =>
        generation != _offlineCancellationGeneration ||
        (shouldCancel?.call() ?? false),
  );
  _offlineDownloads[id] = future;
  try {
    return await future;
  } finally {
    if (identical(_offlineDownloads[id], future)) {
      unawaited(_offlineDownloads.remove(id));
    }
  }
}

Future<bool> _makeSongOffline(
  Map<String, dynamic> song, {
  required bool Function() cancelled,
  OfflineAudioLoader? audioLoader,
  OfflineArtworkLoader? artworkLoader,
  OfflineRegistryWriter? registryWriter,
  OfflineCommitProbe? commitProbe,
}) async {
  File? partial;
  File? committed;
  File? ownershipMarker;
  var commitFinished = false;
  var ownsPartial = false;
  var canRemoveCommitted = false;
  int? expectedBytes;
  String? expectedDigest;
  try {
    final String? ytid = song['ytid'];

    if (ytid == null || ytid.isEmpty) {
      logger.log('makeSongOffline: song["ytid"] is null or empty');
      return false;
    }

    final stored = Hive.box(
      'userNoBackup',
    ).get('offlineSongs', defaultValue: []);
    if (stored is! List) return false;
    final saved = stored
        .whereType<Map>()
        .where((row) => row['ytid'] == ytid)
        .firstOrNull;
    if (saved != null) return validateRegisteredOfflineSong(ytid);

    final offlineSong = Map<String, dynamic>.from(song as Map);

    final audioPath = FilePaths.getAudioPath(ytid);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(ytid);

    // An unregistered existing payload has unknown provenance/completeness.
    // Preserve it; do not adopt it or overwrite it to manufacture success.
    if (cancelled()) return false;
    if (await audioFile.exists() &&
        !await _rollbackOwnedUnregisteredOffline(audioFile, ytid, cancelled))
      return false;
    if (cancelled()) return false;
    partial = File(
      '${audioFile.path}.download-${DateTime.now().microsecondsSinceEpoch}.part',
    );
    if (await partial.exists()) return false;

    await audioFile.parent.create(recursive: true);

    IOSink? fileStream;
    try {
      final audio = await (audioLoader ?? fetchCompatibleOfflineAudio)(ytid);
      if (audio == null ||
          audio.expectedBytes == null ||
          audio.expectedBytes! <= 0 ||
          cancelled()) {
        logger.log('makeSongOffline: audioManifest is null for $ytid');
        return false;
      }

      await partial.create(exclusive: true);
      ownsPartial = true;
      fileStream = partial.openWrite();
      expectedBytes = audio.expectedBytes;
      final collector = _OfflineDigestCollector();
      final digestSink = sha256.startChunkedConversion(collector);
      try {
        await fileStream.addStream(
          _checkedOfflineStream(audio, cancelled).map((chunk) {
            digestSink.add(chunk);
            return chunk;
          }),
        );
      } finally {
        digestSink.close();
      }
      expectedDigest = collector.value!.toString();
      await fileStream.flush();
      await fileStream.close();
      fileStream = null;
      await flushOfflineFile(partial);
      if (await partial.length() != expectedBytes ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              expectedDigest)
        throw StateError('Offline disk payload differs from received bytes');
      if (commitProbe != null)
        await commitProbe(OfflineCommitBoundary.bodyFlushed);
    } catch (e, stackTrace) {
      logger.log(
        'Error downloading audio file',
        error: e,
        stackTrace: stackTrace,
      );
      try {
        await fileStream?.close();
      } catch (_) {}
      if (ownsPartial && await partial.exists()) {
        await partial.delete();
      }
      return false;
    }

    // Artwork is optional. Preserve an existing file, including invalid evidence,
    // but never register an empty, interrupted or inherited unrelated path.
    offlineSong['artworkPath'] = null;
    try {
      final existing = File(artworkPath);
      if (await existing.exists()) {
        if (await existing.length() > 0)
          offlineSong['artworkPath'] = artworkPath;
      } else if (!cancelled() &&
          offlineSong['highResImage'] is String &&
          (offlineSong['highResImage'] as String).isNotEmpty) {
        final artwork = await _downloadAndSaveArtworkFile(
          offlineSong['highResImage'],
          artworkPath,
          loader: artworkLoader,
          cancelled: cancelled,
        );
        if (artwork != null) offlineSong['artworkPath'] = artwork.path;
      }
    } catch (e, stackTrace) {
      logger.log('Error downloading artwork', error: e, stackTrace: stackTrace);
    }

    offlineSong['audioPath'] = audioFile.path;
    offlineSong['offlineAudioBytes'] = expectedBytes;
    offlineSong['offlineAudioSha256'] = expectedDigest;
    offlineSong['dateAdded'] = DateTime.now().millisecondsSinceEpoch;

    try {
      await _serializeOfflineCommit(() async {
        if (cancelled() || await audioFile.exists())
          throw StateError('Offline commit is cancelled or stale');
        Future<void> validatePayload(File file, {bool linked = false}) async {
          if (linked &&
              !await FileSystemEntity.identical(partial!.path, file.path))
            throw StateError('Offline published file was replaced');
          final check = await checkOfflineAudio({
            ...offlineSong,
            'audioPath': file.path,
          });
          if (!check.playable)
            throw StateError(
              'Offline payload is incomplete or changed: ${check.state.name}',
            );
        }

        await validatePayload(partial!);
        final box = Hive.box('userNoBackup');
        final hadRegistry = box.containsKey('offlineSongs');
        final previous = box.get('offlineSongs', defaultValue: <dynamic>[]);
        if (previous is! List)
          throw StateError('Offline registry is not a valid list');
        final updatedOfflineSongs = List<dynamic>.from(previous);
        final storedIndex = updatedOfflineSongs.indexWhere(
          (entry) => entry is Map && entry['ytid'] == ytid,
        );
        if (storedIndex != -1) {
          updatedOfflineSongs[storedIndex] = offlineSong;
        } else {
          updatedOfflineSongs.add(offlineSong);
        }
        final candidateMarker = File('${partial.path}.owner.json');
        if (await candidateMarker.exists())
          throw StateError('Offline ownership marker already exists');
        ownershipMarker = candidateMarker;
        await ownershipMarker!.writeAsString(
          jsonEncode({
            'schema': 1,
            'ytid': ytid,
            'audioPath': audioFile.path,
            'partialPath': partial.path,
            'expectedBytes': expectedBytes,
            'sha256': expectedDigest,
            'sourceLinkRequired': true,
          }),
          flush: true,
        );
        if (commitProbe != null)
          await commitProbe(OfflineCommitBoundary.ownershipFlushed);
        if (cancelled())
          throw StateError('Offline commit cancelled before rename');
        if (commitProbe != null)
          await commitProbe(OfflineCommitBoundary.beforeRename);
        await validatePayload(partial);
        publishOfflineFile(partial, audioFile);
        committed = audioFile;
        if (commitProbe != null)
          await commitProbe(OfflineCommitBoundary.afterRename);
        await validatePayload(audioFile, linked: true);
        await flushOfflineFile(audioFile);
        try {
          await (registryWriter ??
              (box, values) =>
                  box.put('offlineSongs', values))(box, updatedOfflineSongs);
          if (commitProbe != null)
            await commitProbe(OfflineCommitBoundary.registryWritten);
          await validatePayload(audioFile, linked: true);
          await box.flush();
          if (commitProbe != null)
            await commitProbe(OfflineCommitBoundary.registryFlushed);
          await validatePayload(audioFile, linked: true);
        } catch (_) {
          if (hadRegistry) {
            await box.put('offlineSongs', previous);
          } else {
            await box.delete('offlineSongs');
          }
          await box.flush();
          try {
            canRemoveCommitted =
                await FileSystemEntity.identical(
                  partial.path,
                  audioFile.path,
                ) &&
                (await checkOfflineAudio(offlineSong)).playable;
          } catch (_) {
            canRemoveCommitted = false;
          }
          rethrow;
        }
        userOfflineSongs.value = updatedOfflineSongs;
        _offlineCheckedRows[ytid] = _offlineRowKey(offlineSong);
        offlineAudioChecks.value = {
          ...offlineAudioChecks.value,
          ytid: OfflineAudioCheck(
            OfflineAudioState.ready,
            audioFile.path,
            hasProof: true,
          ),
        };
      });
    } catch (e, st) {
      logger.log(
        'Error updating global offline songs list',
        error: e,
        stackTrace: st,
      );
      if (canRemoveCommitted && committed != null && await committed!.exists())
        await committed!.delete();
      return false;
    }

    commitFinished = true;
    try {
      if (ownershipMarker != null && await ownershipMarker!.exists())
        await ownershipMarker!.delete();
    } catch (error, stackTrace) {
      logger.log(
        'Offline ownership marker cleanup failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (commitProbe != null)
      await commitProbe(OfflineCommitBoundary.ownershipRemoved);
    if (commitProbe != null)
      await commitProbe(OfflineCommitBoundary.beforeReturn);
    final completed = await checkOfflineAudio(offlineSong);
    _offlineCheckedRows[ytid] = _offlineRowKey(offlineSong);
    offlineAudioChecks.value = {...offlineAudioChecks.value, ytid: completed};
    return completed.playable;
  } catch (e, stackTrace) {
    logger.log('Error making song offline', error: e, stackTrace: stackTrace);
    return false;
  } finally {
    try {
      if (ownershipMarker != null &&
          (commitFinished || canRemoveCommitted || committed == null) &&
          await ownershipMarker!.exists())
        await ownershipMarker!.delete();
    } catch (_) {
      /* Leave known proof for explicit retry if cleanup fails. */
    }
    if (ownsPartial &&
        partial != null &&
        (committed == null || canRemoveCommitted || commitFinished) &&
        await partial.exists())
      await partial.delete();
  }
}

Future<bool> removeSongFromOffline(dynamic songId) async {
  try {
    final audioPath = FilePaths.getAudioPath(songId);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(songId);
    final artworkFile = File(artworkPath);

    try {
      if (await audioFile.exists()) await audioFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log('Error deleting audio file', error: e, stackTrace: stackTrace);
    }

    try {
      if (await artworkFile.exists()) await artworkFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log(
        'Error deleting artwork file',
        error: e,
        stackTrace: stackTrace,
      );
    }

    try {
      userOfflineSongs.value = List.from(userOfflineSongs.value)
        ..removeWhere((song) => song['ytid'] == songId);
      unawaited(
        addOrUpdateData<List>(
          'userNoBackup',
          'offlineSongs',
          userOfflineSongs.value,
        ),
      );
    } catch (e, st) {
      logger.log(
        'Error updating offline songs registry after removal',
        error: e,
        stackTrace: st,
      );
    }

    return true;
  } catch (e, stackTrace) {
    logger.log(
      'Error removing song from offline storage',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

Future<List<int>?> _fetchOfflineArtwork(String url) async {
  final response = await ProxyManager().getProxiedResponse(Uri.parse(url));
  return response.statusCode == 200 ? response.bodyBytes : null;
}

Future<File?> _downloadAndSaveArtworkFile(
  String url,
  String filePath, {
  OfflineArtworkLoader? loader,
  required bool Function() cancelled,
}) async {
  File? partial;
  var ownsPartial = false;
  try {
    final bytes = await (loader ?? _fetchOfflineArtwork)(url);
    if (bytes == null || bytes.isEmpty || cancelled()) return null;
    final file = File(filePath);
    await file.parent.create(recursive: true);
    partial = File(
      '$filePath.download-${DateTime.now().microsecondsSinceEpoch}.part',
    );
    if (await partial.exists()) return null;
    await partial.create(exclusive: true);
    ownsPartial = true;
    await partial.writeAsBytes(bytes, flush: true);
    await flushOfflineFile(partial);
    final digest = sha256.convert(bytes).toString();
    if (await partial.length() != bytes.length ||
        (await sha256.bind(partial.openRead()).first).toString() != digest ||
        cancelled())
      return null;
    publishOfflineFile(partial, file);
    await flushOfflineFile(file);
    if (!await FileSystemEntity.identical(partial.path, file.path) ||
        await file.length() != bytes.length ||
        (await sha256.bind(file.openRead()).first).toString() != digest)
      return null;
    return file;
  } catch (e, stackTrace) {
    logger.log(
      'Error downloading and saving artwork',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  } finally {
    if (ownsPartial && partial != null && await partial.exists())
      await partial.delete();
  }
}

const recentlyPlayedSongsLimit = 100;

/// Updates the recently played list and listening count for [songId].
///
/// When [songFallback] is provided, its metadata is used to seed the history
/// entry if the song has never been played before. This avoids a network
/// request when registering offline songs whose metadata is already available
/// locally (e.g. from [userOfflineSongs]).
Future<void> updateRecentlyPlayed(dynamic songId, {Map? songFallback}) async {
  try {
    final now = DateTime.now();

    if (userRecentlyPlayed.value.isNotEmpty &&
        userRecentlyPlayed.value[0]['ytid'] == songId) {
      final updatedList = List.from(userRecentlyPlayed.value);
      final existing = Map.from(updatedList[0] as Map);
      existing['listeningCount'] = (existing['listeningCount'] ?? 0) + 1;
      existing['lastPlayed'] = now;
      updatedList[0] = existing;
      userRecentlyPlayed.value = updatedList;
      unawaited(
        addOrUpdateData<List>(
          'user',
          'recentlyPlayedSongs',
          userRecentlyPlayed.value,
        ),
      );
      return;
    }

    final existingIndex = userRecentlyPlayed.value.indexWhere(
      (song) => song['ytid'] == songId,
    );

    final updatedList = List.from(userRecentlyPlayed.value);

    if (existingIndex == -1 && updatedList.length >= recentlyPlayedSongsLimit) {
      updatedList.removeLast();
    }

    if (existingIndex != -1) {
      final song = Map.from(updatedList.removeAt(existingIndex) as Map);
      song['listeningCount'] = (song['listeningCount'] ?? 0) + 1;
      song['lastPlayed'] = now;
      updatedList.insert(0, song);
    } else {
      final dynamic fetchedSongDetails = songFallback != null
          ? Map<String, dynamic>.from(songFallback)
          : await getSongDetails(0, songId);

      if (fetchedSongDetails is! Map) {
        logger.log('Failed to update recently played: invalid song details');
        return;
      }

      final newSongDetails = Map<String, dynamic>.from(fetchedSongDetails);
      newSongDetails['ytid'] ??= songId;
      newSongDetails['listeningCount'] = 1;
      newSongDetails['lastPlayed'] = now;
      updatedList.insert(0, newSongDetails);
    }

    userRecentlyPlayed.value = updatedList;
    unawaited(
      addOrUpdateData<List>(
        'user',
        'recentlyPlayedSongs',
        userRecentlyPlayed.value,
      ),
    );
  } catch (e, stackTrace) {
    logger.log(
      'Error updating recently played',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<void> removeFromRecentlyPlayed(dynamic songId) async {
  if (userRecentlyPlayed.value.any((song) => song['ytid'] == songId)) {
    userRecentlyPlayed.value = List.from(userRecentlyPlayed.value)
      ..removeWhere((song) => song['ytid'] == songId);
    unawaited(
      addOrUpdateData<List>(
        'user',
        'recentlyPlayedSongs',
        userRecentlyPlayed.value,
      ),
    );
  }
}
