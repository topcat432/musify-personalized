import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:musify/services/playlists_manager.dart';

/// One live-page Undo; no occurrence identity or recovery record is persisted.
class PlaylistSlotUndo {
  PlaylistSlotUndo(
    this._playlist, {
    required List<dynamic> remainingSourceSongs,
    required Map removedSong,
    required this.sourceIndex,
  }) : _sourceSnapshot = _copy(remainingSourceSongs) as List,
       _removedSong = _copy(removedSong) as Map;

  final Map _playlist;
  final List _sourceSnapshot;
  final Map _removedSong;
  final int sourceIndex;
  bool _used = false;
  bool get used => _used;

  List<dynamic>? restoredSource(List<dynamic> currentSource) {
    if (_used ||
        sourceIndex < 0 ||
        sourceIndex > currentSource.length ||
        !_same(currentSource, _sourceSnapshot)) {
      return null;
    }
    return (_copy(currentSource) as List<dynamic>)
      ..insert(sourceIndex, _copy(_removedSong));
  }

  Future<Map?> apply({
    required List<dynamic> expectedCurrentSongs,
    required List<int> currentSourceOrder,
    required List<int> restoredOrder,
    Future<void> Function(String key, List<dynamic> value)? write,
  }) async {
    if (_used) {
      return null;
    }
    _used =
        true; // Consume before awaiting; a stale/uncertain attempt never repeats.
    try {
      if (sourceIndex < 0 ||
          sourceIndex > _sourceSnapshot.length ||
          !_validOrder(currentSourceOrder, _sourceSnapshot.length) ||
          !_validOrder(restoredOrder, _sourceSnapshot.length + 1) ||
          !_same(expectedCurrentSongs, [
            for (final i in currentSourceOrder) _sourceSnapshot[i],
          ])) {
        return null;
      }
      final source = (_copy(_sourceSnapshot) as List)
        ..insert(sourceIndex, _copy(_removedSong));
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
      final expected = _copy(expectedCurrentSongs);
      if (!identical(location.playlist, _playlist) ||
          !_same(_playlist['list'], expected)) {
        return null;
      }
      // Stage a separate value so Hive's failed-write rollback retains its old map.
      final staged = _copy(location.collection) as List<dynamic>;
      final target = location.inner == null
          ? staged[location.outer] as Map
          : (staged[location.outer]['playlists'] as List)[location.inner!]
                as Map;
      target['list'] = [for (final i in restoredOrder) _copy(source[i])];
      final frozenStaged = _copy(staged);
      await (write ?? box.put)(location.key, staged);
      if (!_same(box.get(location.key), frozenStaged) ||
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
