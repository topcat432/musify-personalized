// Deterministic metadata fixtures; no provider transport or media lookup.
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/artist_service.dart';
import 'package:musify/services/playlists_manager.dart';

final ownedArtistId = 'UC${List<String>.filled(22, 'A').join()}';
Map<String, dynamic> get ownedArtist => {
  'ytid': ownedArtistId,
  'title': 'Owned route artist',
  'isVerifiedArtist': true,
  'isArtist': true,
  'source': 'youtube-artist',
};
Map<String, dynamic> ownedCatalog(String id, String title) => {
  'ytid': id,
  'title': title,
  'source': 'user-created',
  'image': '',
  'list': [
    {
      'ytid': 'owned-route-recording',
      'title': 'Owned route recording',
      'artist': 'Owned route artist',
      'duration': 8,
    },
  ],
};
Future<void> prepareOwnedSearchFixtures() async {
  final user = Hive.box('user');
  if (!user.containsKey('gapSearchSeeded')) {
    final existing = List<dynamic>.from(
      user.get('customPlaylists', defaultValue: <dynamic>[]),
    );
    await user.putAll({
      'gapSearchSeeded': true,
      'searchHistory': ['Owned routes', 'Owned empty', 'Owned failed'],
      'customPlaylists': [
        ...existing,
        ownedCatalog('customId-gap-album', 'Owned route album'),
        ownedCatalog('customId-gap-playlist', 'Owned route playlist'),
      ],
    });
  }
  // Real artist resolver, verified synthetic ID and complete cached catalog.
  // This is cached navigation, not a live provider-catalog pass.
  final key = 'artist_catalog_v${artistCatalogCacheVersion}_$ownedArtistId';
  await Hive.box('cache').putAll({
    key: {
      ...ownedArtist,
      'catalogStatus': 'complete',
      'isCatalogComplete': true,
      'list': ownedCatalog('unused', 'unused')['list'],
    },
    '${key}_date': DateTime.now(),
  });
  reloadPlaylistLibraryStateFromStorage();
  reloadSearchHistoryFromStorage();
}

Future<List<dynamic>> _lookup(String query, List<dynamic> values) async {
  if (query.toLowerCase().contains('failed'))
    throw StateError('Owned metadata fixture failure');
  if (query.toLowerCase().contains('empty')) return [];
  return values;
}

Widget ownedSearchPage() => SearchPage(
  songSearch: (query) => _lookup(query, []),
  videoSearch: (query) => _lookup(query, []),
  artistSearch: (query) => _lookup(query, [ownedArtist]),
  playlistSearch: (query, type) => _lookup(query, [
    ownedCatalog(
      type == 'album' ? 'customId-gap-album' : 'customId-gap-playlist',
      type == 'album' ? 'Owned route album' : 'Owned route playlist',
    ),
  ]),
  suggestionSearch: (_) async => [],
);
