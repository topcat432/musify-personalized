import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('offline-cleanup-');
    Hive.init('${root.path}/hive');
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    applicationDirPath = '${root.path}/audio';
    await FilePaths.ensureDirectoriesExist();
    offlinePlaylistService.offlinePlaylists.value = [];
    offlinePlaylistService.activeDownloads.clear();
    userOfflineSongs.value = [];
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  Future<void> writeFiles(String id) async {
    await File(FilePaths.getAudioPath(id)).writeAsBytes([1, 2, 3]);
    await File(FilePaths.getArtworkPath(id)).writeAsBytes([4, 5, 6]);
  }

  test(
    'removing one offline playlist preserves shared and library-owned files',
    () async {
      final songs = [
        for (final id in ['exclusive', 'shared', 'liked', 'custom'])
          {'ytid': id},
      ];
      for (final song in songs) {
        await writeFiles(song['ytid']!);
      }
      userOfflineSongs.value = songs;
      userLikedSongsList.value = [
        {'ytid': 'liked'},
      ];
      userCustomPlaylists.value = [
        {
          'ytid': 'custom-owner',
          'source': 'user-created',
          'list': [
            {'ytid': 'custom'},
          ],
        },
      ];
      offlinePlaylistService.offlinePlaylists.value = [
        {'ytid': 'remove-me', 'list': songs},
        {
          'ytid': 'keep-me',
          'list': [
            {'ytid': 'shared'},
          ],
        },
      ];
      await Hive.box('user').put('likedSongs', userLikedSongsList.value);
      await Hive.box('user').put('customPlaylists', userCustomPlaylists.value);
      await offlinePlaylistService.removeOfflinePlaylist('remove-me');
      for (final id in ['shared', 'liked', 'custom']) {
        expect(await File(FilePaths.getAudioPath(id)).readAsBytes(), [1, 2, 3]);
        expect(await File(FilePaths.getArtworkPath(id)).readAsBytes(), [
          4,
          5,
          6,
        ]);
      }
      expect(await File(FilePaths.getAudioPath('exclusive')).exists(), isFalse);
      expect(
        await File(FilePaths.getArtworkPath('exclusive')).exists(),
        isFalse,
      );
      await Hive.box('userNoBackup').flush();
      await Hive.close();
      await initPriorityReviewHive();
      expect(
        (Hive.box('userNoBackup').get('offlineSongs') as List).map(
          (song) => (song as Map)['ytid'],
        ),
        ['shared', 'liked', 'custom'],
      );
      expect(
        (Hive.box('userNoBackup').get('offlinePlaylists') as List)
            .single['ytid'],
        'keep-me',
      );
      expect(Hive.box('user').get('likedSongs'), [
        {'ytid': 'liked'},
      ]);
      expect(
        Hive.box('user').get('customPlaylists'),
        userCustomPlaylists.value,
      );
    },
  );

  test(
    'delete downloads is confined to audio/artwork and offline registries',
    () async {
      await writeFiles('fixture');
      final unrelated = File('$applicationDirPath/keep-note.txt');
      await unrelated.writeAsString('keep');
      final retained = {
        'likedSongs': [
          {'ytid': 'fixture'},
        ],
        'spotifyImportTracks': [
          {'sourceRow': 1},
        ],
        'customPlaylists': [
          {
            'ytid': 'keep',
            'list': [
              {'ytid': 'fixture'},
            ],
          },
        ],
      };
      await Hive.box('user').putAll(retained);
      await Hive.box('settings').put('offlineMode', true);
      await Hive.box('userNoBackup').putAll({
        'offlineSongs': [
          {'ytid': 'fixture'},
        ],
        'offlinePlaylists': [
          {
            'ytid': 'offline',
            'list': [
              {'ytid': 'fixture'},
            ],
          },
        ],
      });
      userOfflineSongs.value = [
        {'ytid': 'fixture'},
      ];
      await offlinePlaylistService.deleteAllDownloads();
      await Hive.box('userNoBackup').flush();
      await Hive.close();
      await initPriorityReviewHive();
      expect(Hive.box('userNoBackup').get('offlineSongs'), isEmpty);
      expect(Hive.box('userNoBackup').get('offlinePlaylists'), isEmpty);
      expect(
        await Directory('$applicationDirPath/tracks').list().toList(),
        isEmpty,
      );
      expect(
        await Directory('$applicationDirPath/artworks').list().toList(),
        isEmpty,
      );
      expect(await unrelated.readAsString(), 'keep');
      for (final entry in retained.entries) {
        expect(Hive.box('user').get(entry.key), entry.value, reason: entry.key);
      }
      expect(Hive.box('settings').get('offlineMode'), isTrue);
    },
  );
}
