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
  'isAlbum': id == 'customId-gap-album',
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
  final savedPlaylists = List<dynamic>.from(user.get('customPlaylists'));
  final albumIndex = savedPlaylists.indexWhere(
    (row) => row is Map && row['ytid'] == 'customId-gap-album',
  );
  if (albumIndex >= 0 && savedPlaylists[albumIndex]['isAlbum'] != true) {
    savedPlaylists[albumIndex] = Map<String, dynamic>.from(
      savedPlaylists[albumIndex],
    )..['isAlbum'] = true;
    await user.put('customPlaylists', savedPlaylists);
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
  final history = List<dynamic>.from(
    user.get('searchHistory', defaultValue: []),
  );
  if (!history.contains('Owned partial')) {
    await user.put('searchHistory', [...history, 'Owned partial']);
  }
  reloadSearchHistoryFromStorage();
}

Future<List<dynamic>> _lookup(String query, List<dynamic> values) async {
  if (query.toLowerCase().contains('failed'))
    throw StateError('Owned metadata fixture failure');
  if (query.toLowerCase().contains('empty')) return [];
  return values;
}

Widget ownedSearchPage() => SearchPage(
  songSearch: (query) => _lookup(query, [
    {
      'ytid': 'owned-healthy-recording',
      'title': 'Owned healthy recording',
      'artist': 'Owned route artist',
      'duration': 8,
      'sourceType': 'youtube_music_song',
    },
  ]),
  videoSearch: (query) => _lookup(query, [
    {
      'ytid': 'owned-healthy-video',
      'title': 'Owned healthy video',
      'artist': 'Owned fixture channel',
      'duration': 8,
    },
  ]),
  artistSearch: (query) {
    if (query.toLowerCase().contains('partial'))
      throw StateError('Owned artist failure');
    return _lookup(query, [ownedArtist]);
  },
  playlistSearch: (query, type) {
    if (query.toLowerCase().contains('partial') && type == 'album') {
      throw StateError('Owned album failure');
    }
    return _lookup(query, [
      ownedCatalog(
        type == 'album' ? 'customId-gap-album' : 'customId-gap-playlist',
        type == 'album' ? 'Owned route album' : 'Owned route playlist',
      ),
    ]);
  },
  suggestionSearch: (_) async => [],
);
