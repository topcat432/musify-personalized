import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_manual_match_page.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

void main() {
  for (final scenario in ['edited', 'replaced', 'failed']) {
    testWidgets('manual choice retains the result query after $scenario search text', (tester) async {
      tester.view.physicalSize = const Size(1100, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = await tester.runAsync(() => Directory.systemTemp.createTemp('owned-manual-query-'));
      Map<String, dynamic>? queued;
      final searches = <String>[];
      await tester.runAsync(() async {
        Hive.init(root!.path);
        final box = await Hive.openBox('user');
        await box.putAll({
          'spotifyMatchResults': [{
            'sourceTitle': 'Owned song', 'sourceArtist': 'Owned artist',
            'sourceRow': 12, 'status': 'needs_review',
          }],
          'spotifyImportMetadata': {'importSessionId': 'owned-query-session'},
          'likedSongs': [{'ytid': 'owned-existing-like'}],
          'ownedUnrelated': {'keep': true},
        });
        queued = (await const SpotifyReviewWorkflowService().loadUnresolvedItems()).single;
      });
      try {
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
            SpotifyManualMatchPage(item: queued!, candidateSearch: (query) async {
              searches.add(query);
              if (query == 'Owned failed lookup') throw StateError('Owned lookup failure');
              return [{
                'ytid': query == 'Owned replacement lookup' ? 'owned-new-result' : 'owned-initial-result',
                'title': 'Owned candidate', 'artist': 'Owned artist', 'duration': 180,
              }];
            }))), child: const Text('Open manual')))));
        await tester.tap(find.text('Open manual'));
        await tester.pumpAndSettle();
        var expectedQuery = 'Owned artist Owned song';
        var expectedId = 'owned-initial-result';
        if (scenario != 'edited') {
          final query = scenario == 'failed' ? 'Owned failed lookup' : 'Owned replacement lookup';
          await tester.enterText(find.byType(TextField), query);
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
          if (scenario == 'replaced') {
            expectedQuery = query;
            expectedId = 'owned-new-result';
          } else {
            expect(find.textContaining('Owned lookup failure'), findsOneWidget);
          }
        }
        await tester.enterText(find.byType(TextField), 'Owned unsearched edit');
        final use = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Use match'));
        await tester.runAsync(() async {
          final box = Hive.box('user');
          final saved = box.watch(key: 'spotifyMatchResults').first.timeout(const Duration(seconds: 2));
          use.onPressed!();
          await saved;
          await box.flush();
        });
        await tester.pumpAndSettle();
        expect(find.text('Open manual'), findsOneWidget);
        await tester.runAsync(() async {
          await Hive.close();
          Hive.init(root!.path);
          final box = await Hive.openBox('user');
          final result = (box.get('spotifyMatchResults') as List).single as Map;
          expect(result['manualSearchQuery'], expectedQuery, reason: 'MANUAL_CHOICE_SAVED_UNSEARCHED_QUERY');
          expect(result['bestCandidate']['ytid'], expectedId);
          expect(result['manualSourceUrl'], isNull);
          expect(result['reviewDecision'], 'manual_search');
          expect(result['status'], 'manually_matched');
          expect(box.get('likedSongs'), [{'ytid': 'owned-existing-like'}]);
          expect(box.get('ownedUnrelated'), {'keep': true});
        });
        expect(searches, isNot(contains('Owned unsearched edit')));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.runAsync(() async { await Hive.close(); await root!.delete(recursive: true); });
      }
    }, timeout: const Timeout(Duration(seconds: 20)));
  }
}
