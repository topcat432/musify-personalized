import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

void main() {
  late Directory root;
  const service = SpotifyReviewWorkflowService();
  setUp(() async {
    root = await Directory.systemTemp.createTemp('owned-manual-exclusion-');
    Hive.init(root.path);
    await Hive.openBox('user');
  });
  tearDown(() async { await Hive.close(); await root.delete(recursive: true); });
  for (final state in ['excluded', 'history', 'unreadable', 'allowed']) {
    test('manual save retains permanent outcome and legacy scope: $state', () async {
      final box = Hive.box('user');
      final row = <String, dynamic>{'sourceRow': 7, 'sourceTitle': 'Owned song',
        'sourceArtist': 'Owned artist', 'sourceIsrc': 'USOWN2600001', 'status': 'needs_review'};
      await box.put('spotifyMatchResults', [row, {...row, 'sourceRow': 8}]);
      await box.put('spotifyImportMetadata', <String, dynamic>{});
      await box.put('likedSongs', [{'ytid': 'owned-liked'}]);
      final stale = (await service.loadUnresolvedItems()).first;
      if (state == 'excluded') await service.excludeItem(item: stale);
      if (state == 'history') await box.put('spotifyExcludedImportRows', ['7']);
      if (state == 'unreadable') await box.put('spotifyExcludedImportRows', {'unknown': true});
      await box.flush();
      final before = await File('${root.path}/user.hive').readAsBytes();
      final pending = service.resolveManualItem(item: stale, query: 'Owned explicit query', isDirectUrl: false,
          selectedAlternative: {'candidate': {'ytid': 'owned-selected', 'title': 'Chosen alternate', 'artist': 'Owned artist', 'version': 'live'}, 'score': 0.3, 'evidence': {'keep': true}});
      if (state == 'allowed') {
        final result = await pending;
        expect(result.duplicatesApplied, 0);
        final saved = (box.get('spotifyMatchResults') as List).first as Map;
        expect(saved['bestCandidate']['ytid'], 'owned-selected');
        expect(saved['reviewDecision'], 'manual_search');
        expect(saved['manualSearchQuery'], 'Owned explicit query');
        expect(saved['manualSourceUrl'], isNull);
        expect((box.get('spotifyMatchResults') as List).last['status'], 'needs_review');
      } else {
        await expectLater(pending, throwsA(isA<StateError>()));
        await box.flush();
        expect(await File('${root.path}/user.hive').readAsBytes(), before);
      }
      await Hive.close(); Hive.init(root.path); await Hive.openBox('user');
      expect(Hive.box('user').get('likedSongs'), [{'ytid': 'owned-liked'}]);
      final saved = (Hive.box('user').get('spotifyMatchResults') as List).first as Map;
      expect(saved['status'], state == 'excluded' ? 'excluded' : state == 'allowed' ? 'manually_matched' : 'needs_review');
    });
  }
}
