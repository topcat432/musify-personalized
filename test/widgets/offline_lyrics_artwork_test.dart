import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('offline-lyrics-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
  });
  tearDown(() async {
    await Hive.close();
    final owned = await root.resolveSymbolicLinks();
    final temporary = await Directory.systemTemp.resolveSymbolicLinks();
    if (!owned.startsWith(
      '$temporary${Platform.pathSeparator}offline-lyrics-',
    )) {
      throw StateError('Refusing outside owned test root');
    }
    await root.delete(recursive: true);
  });
  testWidgets('offline artwork never starts a hidden lyrics lookup', (
    tester,
  ) async {
    offlineMode.value = true;
    var calls = 0;
    await tester.pumpWidget(
      priorityReviewApp(
        brightness: Brightness.light,
        child: Scaffold(
          body: NowPlayingArtwork(
            size: const Size(400, 800),
            metadata: const MediaItem(
              id: 'owned-offline-art',
              title: 'Owned offline',
              artist: 'Synthetic',
            ),
            lyricsController: FlipCardController(),
            lyricsLoader: (_, _) async {
              calls++;
              return 'Owned text';
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 0);
  });
}
