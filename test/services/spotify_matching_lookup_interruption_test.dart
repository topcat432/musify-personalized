import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_track_matching_service.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('owned-lookup-');
    Hive.init(root.path);
    final b = await Hive.openBox('user');
    await b.putAll({
      'spotifyImportTracks': [
        {
          'sourceRow': 1,
          'title': 'Retained owned recording',
          'artist': 'Synthetic',
        },
        {
          'sourceRow': 2,
          'title': 'Pending owned recording',
          'artist': 'Synthetic',
        },
      ],
      'spotifyImportMetadata': {
        'importSessionId': 'owned-lookup',
        'nextTrackIndex': 1,
        'matchingStatus': 'paused',
      },
      'spotifyMatchResults': [
        {
          'sourceRow': 1,
          'status': 'manually_matched',
          'bestCandidate': {'ytid': 'retained-owned-alternate'},
        },
      ],
      'likedSongs': [
        {'ytid': 'retained-owned-like'},
      ],
    });
  });
  tearDown(() async {
    await Hive.close();
    final own = await root.resolveSymbolicLinks();
    final tmp = await Directory.systemTemp.resolveSymbolicLinks();
    if (!own.startsWith('$tmp${Platform.pathSeparator}owned-lookup-'))
      throw StateError('Unowned root');
    await root.delete(recursive: true);
  });
  test(
    'cancelled music response never launches fallback and checkpoints paused cursor',
    () async {
      final entered = Completer<void>();
      final response = Completer<List<Map<String, dynamic>>>();
      var cancelled = false;
      var fallbacks = 0;
      final s = SpotifyTrackMatchingService(
        musicLookup: (_) {
          entered.complete();
          return response.future;
        },
        videoLookup: (_) async {
          fallbacks++;
          return [];
        },
      );
      final pending = s.matchNextBatch(
        batchSize: 1,
        shouldCancel: () => cancelled,
      );
      await entered.future;
      cancelled = true;
      response.complete([]);
      final result = await pending;
      expect(fallbacks, 0);
      expect(result.nextTrackIndex, 1);
      expect(result.status, 'paused');
      expect(
        (Hive.box('user').get('spotifyMatchResults') as List)
            .single['bestCandidate']['ytid'],
        'retained-owned-alternate',
      );
    },
  );
  test(
    'all failed lookup sources are errors rather than verified unmatched recordings',
    () async {
      Future<List<Map<String, dynamic>>> failed(String _) async =>
          throw const SocketException('Owned lookup unavailable');
      final result = await SpotifyTrackMatchingService(
        musicLookup: failed,
        videoLookup: failed,
      ).matchNextBatch(batchSize: 1);
      expect(result.errorCount, 1);
      expect(result.unmatchedCount, 0);
      expect(result.nextTrackIndex, 2);
    },
  );
  test(
    'healthy empty sources remain unmatched and resumable completed membership stays unique',
    () async {
      final s = SpotifyTrackMatchingService(
        musicLookup: (_) async => [],
        videoLookup: (_) async => [],
      );
      final result = await s.matchNextBatch(batchSize: 1);
      expect(result.unmatchedCount, 1);
      expect(result.errorCount, 0);
      await Hive.close();
      await Hive.openBox('user');
      final repeated = await s.matchNextBatch(batchSize: 1);
      expect(repeated.nextTrackIndex, 2);
      expect(Hive.box('user').get('spotifyMatchResults'), hasLength(2));
    },
  );
  test(
    'legacy import replacement during lookup preserves replacement and prevents fallback',
    () async {
      final b = Hive.box('user');
      await b.put('spotifyImportMetadata', {
        'fileName': 'owned.csv',
        'nextTrackIndex': 1,
        'matchingStatus': 'paused',
      });
      final entered = Completer<void>();
      final response = Completer<List<Map<String, dynamic>>>();
      var fallbackCalls = 0;
      final s = SpotifyTrackMatchingService(
        musicLookup: (_) {
          entered.complete();
          return response.future;
        },
        videoLookup: (_) async {
          fallbackCalls++;
          return [];
        },
      );
      final pending = s.matchNextBatch(batchSize: 1);
      await entered.future;
      final replacement = {
        'fileName': 'owned.csv',
        'nextTrackIndex': 0,
        'matchingStatus': 'not_started',
      };
      await b.putAll({
        'spotifyImportMetadata': replacement,
        'spotifyImportTracks': [
          {'sourceRow': 2, 'title': 'Owned replacement', 'artist': 'Synthetic'},
        ],
        'spotifyMatchResults': <dynamic>[],
      });
      response.complete([]);
      final result = await pending;
      expect(fallbackCalls, 0);
      expect(result.nextTrackIndex, 0);
      expect(result.totalTracks, 1);
      expect(result.status, 'not_started');
      expect(b.get('spotifyImportMetadata'), replacement);
      expect(b.get('spotifyMatchResults'), isEmpty);
      expect(b.get('likedSongs'), [
        {'ytid': 'retained-owned-like'},
      ]);
    },
  );
  test(
    'partially unavailable empty catalog is error while healthy candidate remains usable',
    () async {
      Future<List<Map<String, dynamic>>> failed(String _) async =>
          throw const SocketException('Owned primary unavailable');
      final empty = await SpotifyTrackMatchingService(
        musicLookup: failed,
        videoLookup: (_) async => [],
      ).matchNextBatch(batchSize: 1);
      expect(empty.errorCount, 1);
      expect(empty.unmatchedCount, 0);
      await Hive.box('user').put('spotifyImportMetadata', {
        'importSessionId': 'owned-lookup',
        'nextTrackIndex': 1,
        'matchingStatus': 'paused',
      });
      await Hive.box('user').put('spotifyMatchResults', [
        {
          'sourceRow': 1,
          'status': 'manually_matched',
          'bestCandidate': {'ytid': 'retained-owned-alternate'},
        },
      ]);
      final useful = await SpotifyTrackMatchingService(
        musicLookup: failed,
        videoLookup: (_) async => [
          {
            'ytid': 'owned-healthy-candidate',
            'title': 'Pending owned recording',
            'artist': 'Synthetic',
            'videoAuthor': 'Synthetic - Topic',
            'sourceType': 'youtube_music_song',
          },
        ],
      ).matchNextBatch(batchSize: 1);
      expect(useful.errorCount, 0);
      expect(
        (Hive.box('user').get('spotifyMatchResults') as List)
            .last['bestCandidate']['ytid'],
        'owned-healthy-candidate',
      );
    },
  );
  test(
    'review acceptance during cancelled lookup is never overwritten by stale pause checkpoint',
    () async {
      final b = Hive.box('user');
      await b.put('spotifyMatchResults', [
        {
          'sourceRow': 1,
          'status': 'needs_review',
          'bestCandidate': {'ytid': 'owned-old-choice'},
        },
      ]);
      final entered = Completer<void>();
      final response = Completer<List<Map<String, dynamic>>>();
      var cancelled = false;
      final s = SpotifyTrackMatchingService(
        musicLookup: (_) {
          entered.complete();
          return response.future;
        },
        videoLookup: (_) async => [],
      );
      final pending = s.matchNextBatch(
        batchSize: 1,
        shouldCancel: () => cancelled,
      );
      await entered.future;
      cancelled = true;
      await s.resolveReviewItem(
        sourceRow: 1,
        accept: true,
        selectedAlternative: {
          'candidate': {'ytid': 'owned-new-choice'},
          'score': 1.0,
          'evidence': <String, dynamic>{},
        },
      );
      response.complete([]);
      final snapshot = await pending;
      expect(snapshot.nextTrackIndex, 1);
      expect(snapshot.matchedCount, 1);
      expect(snapshot.reviewCount, 0);
      expect(
        (b.get('spotifyMatchResults') as List).single['bestCandidate']['ytid'],
        'owned-new-choice',
      );
    },
  );
  test(
    'older overlapping run cannot overwrite the newer completed recording',
    () async {
      final entered = Completer<void>();
      final response = Completer<List<Map<String, dynamic>>>();
      var staleFallbacks = 0;
      final old = SpotifyTrackMatchingService(
        musicLookup: (_) {
          entered.complete();
          return response.future;
        },
        videoLookup: (_) async {
          staleFallbacks++;
          return [];
        },
      );
      final pending = old.matchNextBatch(batchSize: 1);
      await entered.future;
      final winner = SpotifyTrackMatchingService(
        musicLookup: (_) async => [
          {
            'ytid': 'owned-winning-recording',
            'title': 'Pending owned recording',
            'artist': 'Synthetic',
            'videoAuthor': 'Synthetic - Topic',
            'sourceType': 'youtube_music_song',
          },
        ],
        videoLookup: (_) async => [],
      );
      await winner.matchNextBatch(batchSize: 1);
      response.complete([]);
      final snapshot = await pending;
      expect(snapshot.nextTrackIndex, 2);
      expect(staleFallbacks, 0);
      expect(
        (Hive.box('user').get('spotifyMatchResults') as List)
            .last['bestCandidate']['ytid'],
        'owned-winning-recording',
      );
    },
  );
  test(
    'fresh permanent exclusion during lookup prevents fallbacks and remains excluded on resume',
    () async {
      final entered = Completer<void>();
      final response = Completer<List<Map<String, dynamic>>>();
      var fallbackCalls = 0;
      final s = SpotifyTrackMatchingService(
        musicLookup: (_) {
          entered.complete();
          return response.future;
        },
        videoLookup: (_) async {
          fallbackCalls++;
          return [];
        },
      );
      final pending = s.matchNextBatch(batchSize: 1);
      await entered.future;
      await Hive.box('user').put('spotifyExcludedImportRows', ['2']);
      response.complete([]);
      final interrupted = await pending;
      expect(interrupted.nextTrackIndex, 1);
      expect(fallbackCalls, 0);
      final resumed = await const SpotifyTrackMatchingService().matchNextBatch(
        batchSize: 1,
      );
      expect(resumed.nextTrackIndex, 2);
      expect(resumed.excludedCount, 1);
    },
  );
  test(
    'numeric legacy source rows retain permanent exclusions without lookup',
    () async {
      final b = Hive.box('user');
      await b.put('spotifyImportTracks', [
        {'sourceRow': 1.0, 'title': 'Owned retained row'},
        {'sourceRow': 2.0, 'title': 'Owned numeric excluded row'},
      ]);
      await b.put('spotifyExcludedImportRows', ['2']);
      var calls = 0;
      final s = SpotifyTrackMatchingService(
        musicLookup: (_) async {
          calls++;
          return [];
        },
        videoLookup: (_) async {
          calls++;
          return [];
        },
      );
      final result = await s.matchNextBatch(batchSize: 1);
      expect(calls, 0);
      expect(result.excludedCount, 1);
      expect(result.nextTrackIndex, 2);
    },
  );
  test(
    'multi-track batch reaches every checkpoint without exposing unsaved cache mutations',
    () async {
      final b = Hive.box('user');
      await b.put('spotifyImportTracks', [
        for (var row = 1; row <= 7; row++)
          {'sourceRow': row, 'title': 'Owned row $row', 'artist': 'Synthetic'},
      ]);
      final s = SpotifyTrackMatchingService(
        musicLookup: (_) async => [],
        videoLookup: (_) async => [],
      );
      final result = await s.matchNextBatch(
        batchSize: 6,
        onProgress: (snapshot) {
          if (snapshot.nextTrackIndex < 6) {
            expect((b.get('spotifyMatchResults') as List).length, 1);
            expect(
              (b.get('spotifyImportMetadata') as Map)['nextTrackIndex'],
              1,
            );
          }
        },
      );
      expect(result.nextTrackIndex, 7);
      expect(result.isComplete, isTrue);
      expect(b.get('spotifyMatchResults'), hasLength(7));
    },
  );
}
