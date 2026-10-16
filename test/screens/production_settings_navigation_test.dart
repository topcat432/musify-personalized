import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/screens/about_page.dart';
import 'package:musify/screens/home_page.dart';
import 'package:musify/screens/library_page.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/screens/settings_page.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:rxdart/rxdart.dart';

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
    'production router covers real tabs and Settings About Back compact and wide',
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
        for (final size in [const Size(412, 915), const Size(1280, 900)]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            priorityReviewShellAppSized(
              router: router,
              brightness: Brightness.light,
              viewSize: size,
            ),
          );
          await tester.pumpAndSettle();
          final nav = size.width > 800
              ? find.byType(NavigationRail)
              : find.byType(NavigationBar);
          expect(nav, findsOneWidget);
          Future<void> realTab(String label, String path, Type page) async {
            final Finder destination;
            if (size.width > 800) {
              final rail = tester.widget<NavigationRail>(nav);
              final index = [
                'Home',
                'Search',
                'Library',
                'Settings',
              ].indexOf(label);
              final item = rail.destinations[index];
              destination = find
                  .byWidget(
                    rail.selectedIndex == index ? item.selectedIcon : item.icon,
                  )
                  .hitTestable();
            } else {
              destination = find
                  .descendant(of: nav, matching: find.text(label))
                  .hitTestable();
            }
            expect(destination, findsOneWidget);
            await tester.tap(destination);
            await tester.pumpAndSettle();
            expect(router.routerDelegate.currentConfiguration.uri.path, path);
            expect(find.byType(page), findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          await realTab('Home', '/home', HomePage);
          await realTab('Search', '/search', SearchPage);
          await realTab('Library', '/library', LibraryPage);
          await realTab('Settings', '/settings', SettingsPage);
          final about = find.descendant(
            of: find.byType(SettingsPage),
            matching: find.text('About'),
          );
          expect(about, findsOneWidget);
          await tester.ensureVisible(about);
          await tester.pumpAndSettle();
          await tester.tap(about);
          await tester.pumpAndSettle();
          expect(
            router.routerDelegate.currentConfiguration.uri.path,
            '/settings/about',
          );
          expect(find.byType(AboutPage), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            router.routerDelegate.currentConfiguration.uri.path,
            '/settings',
          );
          expect(find.byType(SettingsPage), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
          expect(find.byType(HomePage), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
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
