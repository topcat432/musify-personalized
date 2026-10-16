import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';

import '../../tool/visual_review_harness.dart';

/// Behavior coverage for `BottomNavigationPage`, separate from pixel/golden
/// assertions. These pin the exact contracts Phase 4A must preserve:
/// back-navigation, double-tap-to-reset, and offline tab hiding/redirect.
void main() {
  late Directory hiveRoot;

  setUpAll(initPriorityReviewTestPlugins);

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('shell-test-');
    Hive.init(hiveRoot.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    await bindPriorityReviewAudioHandler();
  });

  tearDown(() async {
    closeCurrentBottomSheet();
    await Hive.close();
    if (await hiveRoot.exists()) {
      await hiveRoot.delete(recursive: true);
    }
  });

  Future<void> tapNavDestination(WidgetTester tester, String label) async {
    final finder = find
        .descendant(of: find.byType(NavigationBar), matching: find.text(label))
        .first;
    await tester.tap(finder);
  }

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    String initialLocation = '/home',
  }) async {
    final router = buildPriorityShellNavRouter(
      initialLocation: initialLocation,
    );
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      priorityReviewShellApp(router: router, brightness: Brightness.light),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'Back dismisses repeated persistent pickers without changing Settings tab',
    (tester) async {
      final router = await pumpShell(tester, initialLocation: '/settings');
      for (var repeat = 0; repeat < 2; repeat++) {
        final context = tester.element(
          find.byType(PriorityShellBranchPlaceholder).first,
        );
        showCustomBottomSheet(context, const Text('Owned picker choice'));
        await tester.pumpAndSettle();
        expect(find.text('Owned picker choice'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Owned picker choice'), findsNothing);
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          '/settings',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    },
  );

  testWidgets(
    'Back dismisses Home sheet and switching tabs closes stale sheet',
    (tester) async {
      final router = await pumpShell(tester, initialLocation: '/library');
      final context = tester.element(
        find.byType(PriorityShellBranchPlaceholder).first,
      );
      showCustomBottomSheet(context, const Text('Owned pending sheet'));
      await tester.pumpAndSettle();
      await tapNavDestination(tester, 'Home');
      await tester.pumpAndSettle();
      expect(find.text('Owned pending sheet'), findsNothing);
      expect(currentBottomSheetOpen.value, isFalse);
      final homeContext = tester.element(find.byType(Scaffold).last);
      showCustomBottomSheet(homeContext, const Text('Owned Home sheet'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Owned Home sheet'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/home',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    },
  );

  testWidgets(
    'root preference picker Back and selection preserve nested Settings route',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = buildPriorityShellNavRouter(initialLocation: '/settings');
      await tester.pumpWidget(
        priorityReviewShellAppSized(
          router: router,
          brightness: Brightness.light,
          viewSize: const Size(412, 915),
        ),
      );
      await tester.pumpAndSettle();
      for (var repeat = 0; repeat < 2; repeat++) {
        final context = tester.element(
          find.byType(PriorityShellBranchPlaceholder).first,
        );
        showPreferenceBottomSheet(context, const Text('Owned root picker'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Owned root picker'), findsNothing);
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          '/settings',
        );
      }
      final context = tester.element(
        find.byType(PriorityShellBranchPlaceholder).first,
      );
      showPreferenceBottomSheet(
        context,
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Owned select'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owned select'));
      await tester.pumpAndSettle();
      expect(find.text('Owned select'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    },
  );

  testWidgets('double-tapping the active tab resets its branch location', (
    tester,
  ) async {
    final router = await pumpShell(tester);

    await tapNavDestination(tester, 'Library');
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/library',
    );

    await tapNavDestination(tester, 'Library');
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/library',
      reason:
          'Reselecting the active tab resets to its initial location '
          'rather than navigating away.',
    );
  });

  testWidgets(
    'system back on a non-Home tab returns to Home instead of exiting',
    (tester) async {
      final router = await pumpShell(tester);

      await tapNavDestination(tester, 'Library');
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/library',
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/home',
        reason:
            'Back from a non-Home tab must jump to Home (goBranch(0)), not '
            'exit the app.',
      );
    },
  );

  testWidgets('offline mode hides the Search destination', (tester) async {
    await pumpShell(tester);

    expect(find.text('Search'), findsOneWidget);

    offlineMode.value = true;
    await tester.pumpAndSettle();

    expect(
      find.text('Search'),
      findsNothing,
      reason: 'Search destination must be hidden while offline.',
    );
  });

  testWidgets('switching to offline mode while on Search redirects to Home', (
    tester,
  ) async {
    final router = await pumpShell(tester, initialLocation: '/search');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/search',
    );

    offlineMode.value = true;
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/home',
      reason:
          'Turning on offline mode while viewing Search must redirect to '
          'Home, since Search is unavailable offline.',
    );
  });

  testWidgets('wide screens show a NavigationRail instead of a NavigationBar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = buildPriorityShellNavRouter();
    await tester.pumpWidget(
      priorityReviewShellAppSized(
        router: router,
        brightness: Brightness.light,
        viewSize: const Size(900, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
