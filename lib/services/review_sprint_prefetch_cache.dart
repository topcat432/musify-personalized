/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:collection';

typedef ReviewSprintStreamResolver = Future<String?> Function(String songId);

class ReviewSprintPrefetchCache {
  ReviewSprintPrefetchCache({this.capacity = 12})
      : assert(capacity > 0, 'capacity must be positive');

  final int capacity;
  final LinkedHashMap<String, String> _urls = LinkedHashMap<String, String>();
  final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};

  int get length => _urls.length;

  bool contains(String songId) => _urls.containsKey(songId);

  Future<String?> resolve(
    String songId,
    ReviewSprintStreamResolver resolver,
  ) {
    final cached = _urls.remove(songId);
    if (cached != null) {
      _urls[songId] = cached;
      return Future<String?>.value(cached);
    }
    final existing = _inFlight[songId];
    if (existing != null) return existing;

    final request = Future<String?>.sync(() => resolver(songId)).then((url) {
      if (url == null || url.isEmpty) return null;
      _urls[songId] = url;
      while (_urls.length > capacity) {
        _urls.remove(_urls.keys.first);
      }
      return url;
    }).whenComplete(() {
      _inFlight.remove(songId);
    });
    _inFlight[songId] = request;
    return request;
  }

  Future<void> prefetch(
    Iterable<String> songIds,
    ReviewSprintStreamResolver resolver,
  ) async {
    final uniqueIds = songIds.where((id) => id.isNotEmpty).toSet();
    await Future.wait(
      uniqueIds.map((id) async {
        try {
          await resolve(id, resolver);
        } catch (_) {
          // Playback retries a failed prefetch when its card becomes current.
        }
      }),
    );
  }

  void clear() {
    _urls.clear();
    _inFlight.clear();
  }
}
