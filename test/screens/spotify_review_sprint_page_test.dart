import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/screens/spotify_review_sprint_page.dart';
import 'package:musify/services/review_sprint_audio_player.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

void main() {
  testWidgets('a rejected card leaves the queue and the next preview plays', (
    tester,
  ) async {
    final source = _FakeReviewDataSource([
      _item(row: 1, title: 'First song', songId: 'first'),
      _item(row: 2, title: 'Second song', songId: 'second'),
    ]);
    final player = _FakeAudioPlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: SpotifyReviewSprintPage(
          dataSource: source,
          audioPlayer: player,
          streamResolver: (songId) async => 'url-$songId',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First song'), findsOneWidget);
    expect(player.loadedUrls, contains('url-first'));

    await tester.tap(find.byKey(const ValueKey('review-reject-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(source.decisions.single.accept, isFalse);
    expect(find.text('First song'), findsNothing);
    expect(find.text('Second song'), findsOneWidget);
    expect(player.loadedUrls, contains('url-second'));
    expect(player.playCount, greaterThanOrEqualTo(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await player.dispose();
  });

  testWidgets('successive decisions drain the review queue', (tester) async {
    final source = _FakeReviewDataSource([
      _item(row: 1, title: 'First song', songId: 'first'),
      _item(row: 2, title: 'Second song', songId: 'second'),
    ]);
    final player = _FakeAudioPlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: SpotifyReviewSprintPage(
          dataSource: source,
          audioPlayer: player,
          streamResolver: (songId) async => 'url-$songId',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('review-accept-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-reject-button')));
    await tester.pumpAndSettle();

    expect(
      source.decisions.map((decision) => decision.accept),
      orderedEquals(<bool>[true, false]),
    );
    expect(find.text('Review queue cleared'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await player.dispose();
  });
}

Map<String, dynamic> _item({
  required int row,
  required String title,
  required String songId,
}) {
  return <String, dynamic>{
    'sourceRow': row,
    'sourceTitle': title,
    'sourceArtist': 'Source artist',
    'sourceAlbum': 'Source album',
    'sourceIsrc': 'TEST$row',
    'status': 'needs_review',
    'alternatives': <Map<String, dynamic>>[
      <String, dynamic>{
        'score': 0.82,
        'candidate': <String, dynamic>{
          'ytid': songId,
          'title': '$title suggestion',
          'artist': 'Candidate artist',
          'album': 'Candidate album',
          'duration': 180,
          'sourceType': 'youtube_music_song',
        },
        'evidence': <String, dynamic>{
          'titleScore': 1.0,
          'primaryArtistScore': 0.95,
          'reasons': <String>['Exact title match', 'Primary artist matches'],
        },
      },
    ],
  };
}

class _Decision {
  const _Decision({required this.row, required this.accept});

  final String row;
  final bool accept;
}

class _FakeReviewDataSource implements SpotifyReviewSprintDataSource {
  _FakeReviewDataSource(List<Map<String, dynamic>> items)
      : _items = List<Map<String, dynamic>>.from(items);

  final List<Map<String, dynamic>> _items;
  final List<_Decision> decisions = <_Decision>[];

  @override
  Future<List<Map<String, dynamic>>> loadUnresolvedItems() async {
    return _items.map(Map<String, dynamic>.from).toList(growable: false);
  }

  @override
  Future<SpotifyResolutionResult> resolveItem({
    required Map<String, dynamic> item,
    required bool accept,
    Map<String, dynamic>? selectedAlternative,
  }) async {
    final row = item['sourceRow'].toString();
    decisions.add(_Decision(row: row, accept: accept));
    _items.removeWhere((candidate) => candidate['sourceRow'].toString() == row);
    return SpotifyResolutionResult(
      duplicatesApplied: 0,
      remainingUnresolved: _items.length,
    );
  }

  @override
  Future<int> bulkApproveCluster(String key) async => 0;
}

class _FakeAudioPlayer implements ReviewSprintAudioPlayer {
  final StreamController<ReviewSprintAudioState> _controller =
      StreamController<ReviewSprintAudioState>.broadcast();
  final List<String> loadedUrls = <String>[];
  int playCount = 0;

  @override
  Stream<ReviewSprintAudioState> get stateStream => _controller.stream;

  @override
  Future<void> setUrl(String url) async => loadedUrls.add(url);

  @override
  Future<void> play() async {
    playCount++;
    _controller.add(
      const ReviewSprintAudioState(playing: true, completed: false),
    );
  }

  @override
  Future<void> pause() async {
    _controller.add(
      const ReviewSprintAudioState(playing: false, completed: false),
    );
  }

  @override
  Future<void> stop() async {
    _controller.add(
      const ReviewSprintAudioState(playing: false, completed: false),
    );
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() => _controller.close();
}
