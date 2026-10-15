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
import 'package:musify/utilities/formatter.dart';

final _youtubeLinkRegex = RegExp(r'(youtube\.com|youtu\.be)');

/// The platform text stream excludes the intent that launched the process.
/// A later share or disposed owner must supersede a delayed initial read.
Future<void> consumeInitialSharedTextIntent({
  required Future<String?> Function() readInitialText,
  required bool Function() stillCurrent,
  required Future<void> Function(String? value) consume,
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    final value = await readInitialText();
    if (stillCurrent() && value != null && value.trim().isNotEmpty) {
      await consume(value);
    }
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
}) async {
  final isCurrent = stillCurrent ?? () => true;
  if (!isCurrent() || value == null || !_youtubeLinkRegex.hasMatch(value)) {
    return;
  }

  final songId = getSongId(value);
  if (songId == null) {
    return;
  }

  try {
    await audioHandler.resolveAndPlayOwnedSong(
      () => resolveSong?.call(songId) ?? getSongDetails(0, songId),
      stillCurrent: isCurrent,
    );
  } catch (e, stackTrace) {
    if (isCurrent()) onError(e, stackTrace);
  }
}

Future<void> consumeYoutubeSharedTextIntent(
  String? value, {
  required MusifyAudioHandler audioHandler,
  required void Function(Object error, StackTrace stackTrace) onError,
  bool Function()? stillCurrent,
  Future<Map> Function(String songId)? resolveSong,
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
  );
}
