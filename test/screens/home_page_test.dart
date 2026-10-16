import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/settings_manager.dart';

import '../../tool/visual_review_harness.dart';

/// Behavior coverage for `HomePage`, separate from pixel/golden assertions.
/// Pins the exact contracts Phase 4A must preserve: announcement dismiss and
/// the recap/recommended-for-you sections' state gating.
///
/// Every test seeds [seedPriorityHomeRecommendations] regardless of what it
/// is checking: `getRecommendedSongs()` (called unconditionally from
/// `HomePage.initState`) only stays offline when `globalSongs` is non-empty
/// — otherwise it falls through to a live YouTube retry loop that leaves a
/// pending `Timer` at test teardown. A true "nothing to recommend" empty
/// state therefore cannot be reached deterministically without touching the
/// network, so that state is intentionally not covered here (see the
/// handoff report).
///
/// Not covered here: tapping a suggested-playlist cube to navigate. The
/// narrow-width rail renders via `CarouselView.weighted`, and invoking its
/// `onTap(index)` callback directly (bypassing `WidgetTester.tap`, which
/// cannot reliably hit-test the carousel's custom render geometry in this
/// harness) did not produce an observable `GoRouter` location change either,
/// despite matching the exact call Flutter's own `CarouselView` makes
/// internally. This looks like a test-harness/go_router interaction gap
/// specific to this widget, not a defect in `home_page.dart` (the
/// `context.push('/home/playlist/${ytid}')` call itself is unchanged by
/// Phase 4A and was verified directly against source). Left unresolved and
/// reported rather than forcing a flaky or misleading test.
void main() {
  late Directory hiveRoot;

  setUpAll(initPriorityReviewTestPlugins);

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('home-page-test-');
    Hive.init(hiveRoot.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    seedPriorityHomeRecommendations();
    await bindPriorityReviewAudioHandler();
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) {
      await hiveRoot.delete(recursive: true);
    }
  });

  GoRouter buildRouter() =>
      buildPriorityReviewShellRouter(initialLocation: '/home');

  Future<void> pumpHome(WidgetTester tester, GoRouter router) async {
    tester.view.physicalSize = visualReviewStandardPhone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Uses the MediaQuery-correct wrapper: Home's own layout (playlist rail
    // height) depends on a real `MediaQuery.sizeOf(context).height`, which
    // `priorityReviewShellApp`'s bare `MediaQueryData(...)` cannot provide
    // (see `priorityReviewShellAppSized`'s doc comment).
    await tester.pumpWidget(
      priorityReviewShellAppSized(
        router: router,
        brightness: Brightness.light,
        viewSize: visualReviewStandardPhone,
      ),
    );
    // Let the AsyncLoader futures (suggested playlists, recommendations)
    // resolve, and let any route/entrance animation finish; both data
    // sources are seeded/offline so this settles quickly.
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  testWidgets('dismissing the announcement clears announcementURL', (
    tester,
  ) async {
    announcementURL.value = 'https://example.com/announcement';
    final router = buildRouter();
    await pumpHome(tester, router);

    expect(find.byIcon(FluentIcons.dismiss_circle_24_regular), findsOneWidget);
    await tester.tap(find.byIcon(FluentIcons.dismiss_circle_24_regular));
    await tester.pump();

    expect(announcementURL.value, isNull);
  });

  testWidgets('recap section stays collapsed when wrappedEnabled is false', (
    tester,
  ) async {
    wrappedEnabled.value = false;
    final router = buildRouter();
    await pumpHome(tester, router);

    expect(find.text('Listening stats'), findsNothing);
  });

  testWidgets(
    'recommended-for-you section renders with a play-all action once data resolves',
    (tester) async {
      final router = buildRouter();
      await pumpHome(tester, router);

      expect(find.text('Recommended for you'), findsOneWidget);
      expect(find.byIcon(FluentIcons.play_circle_24_filled), findsOneWidget);
    },
  );
}
