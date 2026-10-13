import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/settings_page.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  late Directory root;
  late _NavigationAudio navigationAudio;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('production-settings-nav-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    navigationAudio = _NavigationAudio();
    audioHandler = navigationAudio;
    offlineMode.value = true;
  });
  tearDown(() async {
    await navigationAudio.mediaItem.close();
    await Hive.close();
    await root.delete(recursive: true);
  });

  testWidgets(
    'production router reaches real Settings from saved-only Home and Library',
    (tester) async {
      final manager = NavigationManager();
      final router = NavigationManager.router;
      expect(manager.routerDelegate, same(router.routerDelegate));
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      try {
        await tester.pumpWidget(
          priorityReviewShellAppSized(
            router: router,
            brightness: Brightness.light,
            viewSize: const Size(412, 915),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> tap(String label) async {
          final destination = find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          );
          expect(destination, findsOneWidget);
          await tester.tap(destination);
          await tester.pumpAndSettle();
        }

        await tap('Settings');
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/settings',
        );
        expect(find.byType(SettingsPage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
        await tap('Library');
        expect(router.routerDelegate.currentConfiguration.uri.path, '/library');
        await tap('Settings');
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/settings',
        );
        expect(find.byType(SettingsPage), findsOneWidget);
        offlineMode.value = false;
        await tester.pump(const Duration(milliseconds: 500));
        await tap('Library');
        expect(router.routerDelegate.currentConfiguration.uri.path, '/library');
        await tap('Settings');
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/settings',
        );
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );
}

class _NavigationAudio extends Fake implements MusifyAudioHandler {
  @override
  final mediaItem = BehaviorSubject<MediaItem?>.seeded(null);
}
