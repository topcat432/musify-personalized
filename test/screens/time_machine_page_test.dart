import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/time_machine_page.dart';
import 'package:musify/services/settings_manager.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  late Directory hiveRoot;

  setUpAll(() {
    initPriorityReviewTestPlugins();
  });

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('time-machine-test-');
    Hive.init(hiveRoot.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) {
      await hiveRoot.delete(recursive: true);
    }
  });

  Future<void> pumpTimeMachine(WidgetTester tester) async {
    await tester.pumpWidget(
      priorityReviewApp(
        brightness: Brightness.light,
        child: const TimeMachinePage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when listening stats are disabled', (
    tester,
  ) async {
    wrappedEnabled.value = false;

    await pumpTimeMachine(tester);

    expect(find.text('No listening stats yet'), findsOneWidget);
  });
}
