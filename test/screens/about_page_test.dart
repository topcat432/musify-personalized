import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/constants/version.dart';
import 'package:musify/screens/about_page.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final launchedUrls = <String>[];
  late Directory hiveRoot;

  setUpAll(() {
    initPriorityReviewTestPlugins();
  });

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('about-page-test-');
    Hive.init(hiveRoot.path);
    await initPriorityReviewHive();

    launchedUrls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
          switch (call.method) {
            case 'canLaunch':
              return true;
            case 'launch':
              launchedUrls.add((call.arguments as Map)['url'] as String);
              return true;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, null);
    await Hive.close();
    if (await hiveRoot.exists()) {
      await hiveRoot.delete(recursive: true);
    }
  });

  Future<void> pumpAbout(WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = PriorityFakeHttpClient.new;
    visualReviewSetViewport(tester, visualReviewStandardPhone);
    await tester.pumpWidget(
      priorityReviewApp(brightness: Brightness.light, child: const AboutPage()),
    );
    await tester.pumpAndSettle();
  }

  // `debugNetworkImageHttpClientProvider` must be reset to null before the
  // testWidgets callback returns (not in an outer tearDown/addTearDown),
  // otherwise Flutter's post-test invariant check fails with "The value of a
  // painting debug variable was changed by the test."
  void resetNetworkImageOverride() =>
      debugNetworkImageHttpClientProvider = null;

  testWidgets('renders brand, version, and developer identity', (tester) async {
    await pumpAbout(tester);

    expect(find.text('Musify'), findsOneWidget);
    expect(find.text('v$appVersion'), findsOneWidget);
    expect(find.text('Valeri Gokadze'), findsOneWidget);
    expect(find.text('WEB & APP Developer'), findsOneWidget);

    resetNetworkImageOverride();
  });

  testWidgets('tapping the GitHub button launches the GitHub profile URL', (
    tester,
  ) async {
    await pumpAbout(tester);

    await tester.tap(find.byTooltip('Github'));
    await tester.pumpAndSettle();

    expect(launchedUrls, contains('https://github.com/gokadzev'));

    resetNetworkImageOverride();
  });

  testWidgets('tapping the Website button launches the website URL', (
    tester,
  ) async {
    await pumpAbout(tester);

    await tester.tap(find.byTooltip('Website'));
    await tester.pumpAndSettle();

    expect(launchedUrls, contains('https://gokadzev.github.io'));

    resetNetworkImageOverride();
  });

  testWidgets('social buttons expose semantic labels beyond the tooltip', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpAbout(tester);

    expect(find.bySemanticsLabel('Open the GitHub profile'), findsOneWidget);
    expect(find.bySemanticsLabel('Open the developer website'), findsOneWidget);

    handle.dispose();
    resetNetworkImageOverride();
  });
}
