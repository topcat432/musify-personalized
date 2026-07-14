/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/formatter.dart';

class SpotifyManualSourceService {
  const SpotifyManualSourceService();

  static String? parseExactVideoId(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    return getSongId(value);
  }

  Future<Map<String, dynamic>> loadExactVideo(String input) async {
    final videoId = parseExactVideoId(input);
    if (videoId == null) {
      throw const FormatException(
        'Paste a valid YouTube or YouTube Music video link.',
      );
    }

    final song = await getSongDetails(0, videoId);
    return Map<String, dynamic>.from(song)
      ..['sourceType'] = 'youtube_exact_video'
      ..['sourceUrl'] = input.trim();
  }
}
