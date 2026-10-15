import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:musify/services/playlists_manager.dart';

/// One dialog's selected occurrence; no persistent identity or journal is added.
class PlaylistSongRename {
  PlaylistSongRename(
    this._playlist, {
    required this.sourceIndex,
    required Map expectedSong,
    List<int>? sourceOrder,
  }) : _selectedSong = expectedSong,
       _sourceSnapshot = _playlist['list'] is List
           ? _copy(_playlist['list']) as List
           : <dynamic>[],
       _sourceOrder = List<int>.from(
         sourceOrder ??
             List.generate(
               _playlist['list'] is List ? (_playlist['list'] as List).length : 0,
               (i) => i,
             ),
       );

  final Map _playlist;
  final int sourceIndex;
  final List _sourceSnapshot;
  final Map _selectedSong;
  final List<int> _sourceOrder;
  bool _used = false;

  Future<Map?> apply({
    required String title,
    required String artist,
    Future<void> Function(String key, List<dynamic> value)? write,
  }) async {
    if (_used) return null;
    _used = true;
    try {
      if (title.trim().isEmpty ||
          artist.trim().isEmpty ||
          sourceIndex < 0 ||
          sourceIndex >= _sourceSnapshot.length ||
          _sourceSnapshot[sourceIndex] is! Map ||
          !_validOrder(_sourceOrder, _sourceSnapshot.length) ||
          !_same(_playlist['list'], _sourceSnapshot) ||
          !identical((_playlist['list'] as List)[sourceIndex], _selectedSong)) {
        return null;
      }
      final id = _playlist['ytid'];
      if (id is! String || _playlist['source'] != 'user-created') {
        return null;
      }
      final globals = getUserCustomPlaylists()
          .where((p) => p['ytid'] == id)
          .toList();
      if (globals.length != 1 || !identical(globals.single, _playlist)) {
        return null;
      }
      final box = Hive.box('user');
      final locations =
          <
            ({String key, List collection, int outer, int? inner, Map playlist})
          >[];
      for (final key in ['customPlaylists', 'playlistFolders']) {
        final collection = box.get(key, defaultValue: const []);
        if (collection is! List) {
          return null;
        }
        for (var outer = 0; outer < collection.length; outer++) {
          final item = collection[outer];
          if (item is! Map) {
            return null;
          }
          if (key == 'customPlaylists') {
            if (item['ytid'] == id) {
              locations.add((
                key: key,
                collection: collection,
                outer: outer,
                inner: null,
                playlist: item,
              ));
            }
          } else {
            final children = item['playlists'] ?? const [];
            if (children is! List) {
              return null;
            }
            for (var inner = 0; inner < children.length; inner++) {
              final child = children[inner];
              if (child is! Map) {
                return null;
              }
              if (child['ytid'] == id) {
                locations.add((
                  key: key,
                  collection: collection,
                  outer: outer,
                  inner: inner,
                  playlist: child,
                ));
              }
            }
          }
        }
      }
      if (locations.length != 1) {
        return null;
      }
      final location = locations.single;
      final expected = _sourceSnapshot;
      if (!identical(location.playlist, _playlist) ||
          !_same(_playlist['list'], expected)) {
        return null;
      }
      final liveCollection = location.key == 'customPlaylists'
          ? userCustomPlaylists.value
          : userPlaylistFolders.value;
      // Refuse pre-existing divergence before writing either owner's collection.
      // This also leaves stored-only legacy entries untouched until normal reload.
      if (!_same(liveCollection, location.collection)) {
        return null;
      }
      // Stage a separate value so Hive's failed-write rollback retains its old map.
      final staged = _copy(location.collection) as List<dynamic>;
      final target = location.inner == null
          ? staged[location.outer] as Map
          : (staged[location.outer]['playlists'] as List)[location.inner!]
                as Map;
      final viewSongs = target['list'] as List;
      final selected = viewSongs[sourceIndex] as Map;
      selected
        ..['title'] = title.trim()
        ..['artist'] = artist.trim();
      final sourceSongs = List<dynamic>.filled(viewSongs.length, null);
      for (var i = 0; i < viewSongs.length; i++) {
        sourceSongs[_sourceOrder[i]] = viewSongs[i];
      }
      target['list'] = sourceSongs;
      final frozenStaged = _copy(staged);
      final expectedLiveCollection = _copy(liveCollection);
      await (write ?? box.put)(location.key, staged);
      if (!_same(box.get(location.key), frozenStaged) ||
          !_same(
            location.key == 'customPlaylists'
                ? userCustomPlaylists.value
                : userPlaylistFolders.value,
            expectedLiveCollection,
          ) ||
          !_same(_playlist['list'], expected) ||
          !identical(
            getUserCustomPlaylists().where((p) => p['ytid'] == id).single,
            _playlist,
          )) {
        return null;
      }
      if (location.key == 'customPlaylists') {
        userCustomPlaylists.value = List<Map>.from(staged);
      } else {
        userPlaylistFolders.value = List<Map>.from(staged);
      }
      return target;
    } catch (_) {
      // A failed/uncertain write is reported; never erase an independently saved value.
      return null;
    }
  }
}

dynamic _copy(dynamic value) {
  if (value is Uint8List) {
    return Uint8List.fromList(value);
  }
  if (value is List) {
    return [for (final item in value) _copy(item)];
  }
  if (value is Map) {
    return {for (final entry in value.entries) entry.key: _copy(entry.value)};
  }
  return value;
}

bool _same(dynamic a, dynamic b) {
  if (a is DateTime || b is DateTime) {
    return a is DateTime && b is DateTime && a == b && a.isUtc == b.isUtc;
  }
  if ((a is Uint8List) != (b is Uint8List)) return false;
  if (a is List && b is List) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
  }
  return a == b;
}


bool _validOrder(List<int> order, int count) =>
    order.length == count &&
    order.toSet().length == count &&
    order.every((i) => i >= 0 && i < count);
