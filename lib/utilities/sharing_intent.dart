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

import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/shared_song_metadata.dart';
import 'package:musify/utilities/formatter.dart';

final _youtubeLinkRegex = RegExp(r'(youtube\.com|youtu\.be)');
final _sharedSongMetadata = SharedSongMetadataResolver(
  (id) => getSongDetails(0, id),
);

/// The platform text stream excludes the intent that launched the process.
/// A later share or disposed owner must supersede a delayed initial read.
Future<void> consumeInitialSharedTextIntent({
  required Future<String?> Function() readInitialText,
  required bool Function() stillCurrent,
  required Future<void> Function(String? value) consume,
  required void Function(Object error, StackTrace stackTrace) onError,
  MusifyAudioHandler? audioHandler,
}) async {
  final ownsInitialRead = audioHandler?.capturePlaybackActionOwner();
  String? value;
  try {
    value = await readInitialText();
  } catch (error, stackTrace) {
    if (stillCurrent() && (ownsInitialRead?.call() ?? true))
      onError(error, stackTrace);
    return;
  }
  if (!stillCurrent() ||
      !(ownsInitialRead?.call() ?? true) ||
      value == null ||
      value.trim().isEmpty)
    return;
  try {
    // The consumer reserves its own action before metadata resolution.
    await consume(value);
  } catch (error, stackTrace) {
    if (stillCurrent()) onError(error, stackTrace);
  }
}

Future<void> handleYoutubeSharedTextIntent(
  String? value, {
  required MusifyAudioHandler audioHandler,
  required void Function(Object error, StackTrace stackTrace) onError,
  bool Function()? stillCurrent,
  Future<Map> Function(String songId)? resolveSong,
  SharedSongMetadataResolver? metadataResolver,
  void Function(Object error, StackTrace stack, bool Function() ownsAction)? onOwnedError,
}) async {
  final isCurrent = stillCurrent ?? () => true;
  if (!isCurrent() || value == null || !_youtubeLinkRegex.hasMatch(value)) {
    return;
  }

  final songId = getSongId(value);
  if (songId == null) {
    return;
  }

  bool Function()? ownsAction;
  try {
    await audioHandler.resolveAndPlayOwnedSong(
      () {
        // Capture the reserved action before the first metadata await. A
        // control can supersede it after the handler releases its load token
        // but before this error reaches the UI callback.
        ownsAction = audioHandler.capturePlaybackActionOwner();
        return resolveSong?.call(songId) ??
          (metadataResolver ?? _sharedSongMetadata).resolve(
            songId,
            knownSongs: [
              audioHandler.currentSong,
              ...userRecentlyPlayed.value,
              ...userOfflineSongs.value,
              ...userLikedSongsList.value,
              ...globalSongs,
              for (final playlist in userCustomPlaylists.value)
                if (playlist['list'] is List) ...(playlist['list'] as List),
            ],
          );
      },
      stillCurrent: isCurrent,
    );
  } catch (e, stackTrace) {
    final ownsFailure = ownsAction;
    if (isCurrent() && ownsFailure != null && ownsFailure()) {
      if (onOwnedError != null) {
        onOwnedError(e, stackTrace, ownsFailure);
      } else {
        onError(e, stackTrace);
      }
    }
  }
}

Future<void> consumeYoutubeSharedTextIntent(
  String? value, {
  required MusifyAudioHandler audioHandler,
  required void Function(Object error, StackTrace stackTrace) onError,
  bool Function()? stillCurrent,
  Future<Map> Function(String songId)? resolveSong,
  SharedSongMetadataResolver? metadataResolver,
  void Function(Object error, StackTrace stack, bool Function() ownsAction)? onOwnedError,
}) async {
  if (value == null || value.isEmpty) {
    return;
  }

  final normalizedValue = value.trim();
  if (normalizedValue.isEmpty) {
    return;
  }

  await handleYoutubeSharedTextIntent(
    normalizedValue,
    audioHandler: audioHandler,
    onError: onError,
    stillCurrent: stillCurrent,
    resolveSong: resolveSong,
    metadataResolver: metadataResolver,
    onOwnedError: onOwnedError,
  );
}
