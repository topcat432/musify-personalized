/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:musify/utilities/formatter.dart';

class SpotifyManualSourceService {
  const SpotifyManualSourceService({
    this.clientFactory,
    this.timeout = const Duration(seconds: 10),
  });

  final http.Client Function()? clientFactory;
  final Duration timeout;

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

    final client = (clientFactory ?? http.Client.new)();
    try {
      return await _loadPublicMetadata(
        client,
        videoId,
        input.trim(),
      ).timeout(timeout);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _loadPublicMetadata(
    http.Client client,
    String videoId,
    String input,
  ) async {
    // Public registered oEmbed metadata, without watch-page challenges,
    // credentials, cookies or a fallback after an access-denied response.
    final uri = Uri.https('www.youtube.com', '/oembed', {
      'url': 'https://www.youtube.com/watch?v=$videoId',
      'format': 'json',
    });
    final response = await client.send(
      http.Request('GET', uri)..followRedirects = false,
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Public video metadata is unavailable. Try song search.',
      );
    }
    const limit = 64 * 1024;
    if ((response.contentLength ?? 0) > limit) {
      throw const FormatException('Video metadata is too large.');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > limit) {
        throw const FormatException('Video metadata is too large.');
      }
      bytes.addAll(chunk);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map ||
        decoded['type'] != 'video' ||
        decoded['provider_name'] != 'YouTube' ||
        decoded['title'] is! String ||
        decoded['author_name'] is! String) {
      throw const FormatException('Video metadata is invalid.');
    }
    final raw = (decoded['title'] as String).trim();
    final author = (decoded['author_name'] as String).trim();
    if (raw.isEmpty || author.isEmpty) {
      throw const FormatException('Video metadata is incomplete.');
    }
    final separator = raw.indexOf(' - ');
    final artist = separator < 0 ? author : raw.substring(0, separator).trim();
    final rawTitle = separator < 0 ? raw : raw.substring(separator + 3).trim();
    final title = formatSongTitle(rawTitle);
    final thumbnail = Uri.tryParse(decoded['thumbnail_url']?.toString() ?? '');
    final image =
        thumbnail != null &&
            thumbnail.scheme == 'https' &&
            (thumbnail.host == 'i.ytimg.com' ||
                thumbnail.host == 'img.youtube.com')
        ? thumbnail.toString()
        : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    return {
      'id': 0, 'ytid': videoId, 'title': title.isEmpty ? rawTitle : title,
      'rawTitle': rawTitle, 'artist': artist, 'videoAuthor': author,
      'image': image, 'lowResImage': image, 'highResImage': image,
      // oEmbed does not report duration; do not fabricate one for scoring.
      'duration': null, 'sourceType': 'youtube_exact_video', 'sourceUrl': input,
    };
  }
}
