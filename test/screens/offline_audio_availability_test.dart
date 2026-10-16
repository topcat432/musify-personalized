import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/screens/user_songs_page.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/widgets/song_bar.dart';

import '../../tool/visual_review_harness.dart';

class _CaptureHandler extends MusifyAudioHandler {
  List<Map> songs = [];
  bool shuffled = false;
  int? index;
  @override
  Future<void> addPlaylistToQueue(
    List<Map> songs, {
    bool replace = false,
    int? startIndex,
    bool shuffle = false,
  }) async {
    this.songs = List<Map>.from(songs);
    index = startIndex;
    shuffled = shuffle;
  }
}

void main() {
  late Directory root;
  late _CaptureHandler handler;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('offline-ui-');
    Hive.init('${root.path}/hive');
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    userOfflineSongs.value = [];
    offlineAudioChecks.value = {};
    offlineMode.value = true;
    offlineSortSetting = 'default_';
    applicationDirPath = '${root.path}/files';
    await FilePaths.ensureDirectoriesExist();
    handler = _CaptureHandler();
    audioHandler = handler;
  });
  tearDown(() async {
    await handler.audioPlayer.dispose();
    await Hive.close();
    final resolved = await root.resolveSymbolicLinks();
    final temporary = await Directory.systemTemp.resolveSymbolicLinks();
    if (!resolved.startsWith('$temporary${Platform.pathSeparator}offline-ui-'))
      throw StateError('Outside owned root');
    await root.delete(recursive: true);
  });
  Future<Map<String, dynamic>> fixture(
    String id, {
    bool valid = false,
    bool legacy = false,
  }) async {
    final file = File(FilePaths.getAudioPath(id));
    await file.writeAsBytes(valid ? [1, 2, 3, 4] : [], flush: true);
    return {
      'ytid': id,
      'title': id,
      'artist': 'Synthetic fixture',
      'audioPath': file.path,
      if (!legacy) 'offlineAudioBytes': 4,
      if (!legacy)
        'offlineAudioSha256': sha256.convert([1, 2, 3, 4]).toString(),
    };
  }

  Future<void> register(List<Map> rows) async {
    await Hive.box('userNoBackup').put('offlineSongs', rows);
    userOfflineSongs.value = rows;
  }

  testWidgets(
    'invalid saved row stays visible, cannot play or queue, and offers explicit removal',
    (tester) async {
      final row = (await tester.runAsync(() async {
        final row = await fixture('Unavailable saved row');
        await register([row]);
        await refreshOfflineAudioAvailability();
        return row;
      }))!;
      var taps = 0;
      await tester.pumpWidget(
        priorityReviewApp(
          brightness: Brightness.light,
          child: Scaffold(body: SongBar(row, true, onPlay: () => taps++)),
        ),
      );
      expect(find.text('Saved audio is unavailable'), findsOneWidget);
      await tester.tap(find.text('Unavailable saved row'));
      expect(taps, 0);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      final values = tester
          .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
          .map((item) => item.value);
      expect(values, contains('offline'));
      expect(values, isNot(contains('play_next')));
      expect(values, isNot(contains('add_to_queue')));
      expect(Hive.box('userNoBackup').get('offlineSongs'), [row]);
      expect(File(row['audioPath']).lengthSync(), 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final mixed in [false, true]) {
    testWidgets(
      'offline page preserves all rows and queues only validated files, mixed=$mixed',
      (tester) async {
        tester.view
          ..physicalSize = const Size(800, 1400)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final rows = (await tester.runAsync(() async {
          final rows = [
            if (mixed) await fixture('First valid', valid: true, legacy: true),
            await fixture('Invalid saved'),
            if (mixed) await fixture('Last valid', valid: true),
          ];
          await register(rows);
          return rows;
        }))!;
        await tester.pumpWidget(
          priorityReviewApp(
            brightness: Brightness.light,
            child: const UserSongsPage(page: 'offline'),
          ),
        );
        await tester.runAsync(refreshOfflineAudioAvailability);
        await tester.pumpAndSettle();
        expect(find.text('Invalid saved'), findsOneWidget);
        expect(find.text('Saved audio is unavailable'), findsOneWidget);
        final play = find.widgetWithText(FilledButton, 'Play');
        final shuffle = find.widgetWithText(FilledButton, 'Shuffle');
        expect(tester.widget<FilledButton>(play).onPressed != null, mixed);
        expect(tester.widget<FilledButton>(shuffle).onPressed != null, mixed);
        if (mixed) {
          await tester.tap(play);
          await tester.pump();
          expect(handler.songs.map((row) => row['ytid']), [
            'First valid',
            'Last valid',
          ]);
          await tester.tap(shuffle);
          await tester.pump();
          expect(handler.shuffled, isTrue);
          expect(handler.songs.map((row) => row['ytid']), [
            'First valid',
            'Last valid',
          ]);
          await tester.tap(find.text('Last valid'));
          await tester.pump();
          expect(handler.index, 1);
        }
        expect(Hive.box('userNoBackup').get('offlineSongs'), rows);
        expect(userOfflineSongs.value, rows);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test(
    'availability does not reuse a successful check after row proof changes',
    () async {
      final row = await fixture('Revision', valid: true);
      await register([row]);
      await refreshOfflineAudioAvailability();
      expect(isOfflineSongPlayable(row), isTrue);
      final changed = {...row, 'offlineAudioBytes': 20};
      await register([changed]);
      expect(isOfflineSongPlayable(changed), isFalse);
      expect(await validateRegisteredOfflineSong('Revision'), isFalse);
      expect(Hive.box('userNoBackup').get('offlineSongs'), [changed]);
    },
  );
}
