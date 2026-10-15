import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_manual_match_page.dart';
import 'package:musify/services/manual_preview_player_pool.dart';
import 'package:musify/services/review_sprint_audio_player.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

const _item = {'sourceTitle': 'Owned song', 'sourceArtist': 'Owned artist'};
final _candidates = <Map<String, dynamic>>[
  {'ytid': 'owned-a', 'title': 'Candidate A', 'artist': 'Owned artist', 'duration': 180},
  {'ytid': 'owned-b', 'title': 'Candidate B', 'artist': 'Owned artist', 'duration': 40},
];

void main() {
  late _Backend first;
  late _Backend second;
  late ManualPreviewPlayerPool pool;
  late int created;
  late int searches;

  setUp(() {
    first = _Backend(); second = _Backend(); created = 0; searches = 0;
    pool = ManualPreviewPlayerPool(() => ++created == 1 ? first : second,
      operationTimeout: const Duration(seconds: 1),
      teardownTimeout: const Duration(milliseconds: 100));
  });
  tearDown(() async {
    first.finishPending(); second.finishPending();
    await first.dispose().catchError((Object _) {});
    await second.dispose().catchError((Object _) {});
  });

  Widget page() => SpotifyManualMatchPage(item: _item,
    audioPlayer: first, previewPool: pool,
    candidateSearch: (_) async { searches++; return _candidates; },
    streamResolver: (id) async => id == 'owned-a' ? 'url-a' : 'url-b');

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: page()));
    await tester.pumpAndSettle();
  }
  Future<void> preview(WidgetTester tester, int index) async {
    await tester.tap(find.byType(OutlinedButton).at(index)); await tester.pump();
  }

  for (final operation in ['load', 'seek']) {
    for (final failure in [false, true]) {
      testWidgets('hung $operation retires before B and ignores late failure=$failure', (tester) async {
        final gate = Completer<void>();
        if (operation == 'load') { first.loadGate = gate; } else { first.seekGate = gate; }
        await mount(tester);
        await preview(tester, 0);
        await preview(tester, 1);
        try {
          expect(second.played, ['url-b'], reason: 'HUNG_MANUAL_PREVIEW_BLOCKED_SUCCESSOR');
          expect(created, 2);
          expect(first.disposals, 1);
          expect(gate.isCompleted, isFalse);
          if (failure) { gate.completeError(StateError('Owned retired operation error')); }
          else { gate.complete(); }
          await tester.pump();
          expect(second.played, ['url-b']);
          expect(second.disposals, 0);
          expect(first.played, isEmpty);
          expect(find.textContaining('Owned retired operation error'), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          if (!gate.isCompleted) gate.complete();
          await tester.pump();
        }
      });
    }
  }

  testWidgets('native operation deadline retires a hung load and allows fresh retry', (tester) async {
    first.loadGate = Completer<void>();
    await mount(tester); await preview(tester, 0);
    try {
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(first.disposals, 1);
      expect(find.textContaining('did not respond in time'), findsOneWidget);
      await preview(tester, 1);
      expect(second.played, ['url-b']);
      expect(first.loadGate!.isCompleted, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink()); first.finishPending(); await tester.pump();
    }
  });

  testWidgets('unconfirmed teardown bounds Search and refuses successor until confirmed', (tester) async {
    first.loadGate = Completer<void>(); first.disposeGate = Completer<void>();
    await mount(tester); await preview(tester, 0);
    try {
      await tester.enterText(find.byType(TextField), 'Owned replacement query');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 150)); await tester.pump();
      expect(searches, 2);
      expect(find.text('Possible matches'), findsOneWidget);
      await preview(tester, 1);
      expect(created, 1);
      expect(find.textContaining('cleanup is not confirmed'), findsOneWidget);
      first.disposeGate!.complete(); await tester.pump();
      await preview(tester, 1);
      expect(created, 2);
      expect(second.played, ['url-b']);
      expect(first.loadGate!.isCompleted, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink()); first.finishPending(); await tester.pump();
    }
  });

  testWidgets('failed disposal remains quarantined across manual page reopen', (tester) async {
    first.loadGate = Completer<void>(); first.disposeError = StateError('Owned disposal failure');
    await mount(tester); await preview(tester, 0);
    try {
      await tester.pumpWidget(const SizedBox.shrink()); await tester.pump();
      await tester.pumpWidget(MaterialApp(home: page())); await tester.pumpAndSettle();
      await preview(tester, 1);
      expect(created, 1);
      expect(second.played, isEmpty);
      expect(find.textContaining('cleanup is not confirmed'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink()); first.finishPending(); await tester.pump();
    }
  });

  testWidgets('Use match saves through real writer despite hung load and unconfirmed teardown', (tester) async {
    tester.view.physicalSize = const Size(1100, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = await tester.runAsync(() => Directory.systemTemp.createTemp('owned-preview-save-'));
    Map<String, dynamic>? queued;
    await tester.runAsync(() async {
      Hive.init(root!.path); final box = await Hive.openBox('user');
      await box.putAll({
        'spotifyMatchResults': [{..._item, 'sourceRow': 8, 'status': 'needs_review'}],
        'spotifyImportMetadata': {'importSessionId': 'owned-preview-save'},
        'likedSongs': [{'ytid': 'owned-existing-like'}],
      });
      queued = (await const SpotifyReviewWorkflowService().loadUnresolvedItems()).single;
    });
    first.loadGate = Completer<void>(); first.disposeGate = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
        SpotifyManualMatchPage(item: queued!, audioPlayer: first, previewPool: pool,
          candidateSearch: (_) async => _candidates,
          streamResolver: (_) async => 'url-a'))), child: const Text('Open manual')))));
    await tester.tap(find.text('Open manual')); await tester.pumpAndSettle();
    await preview(tester, 0);
    try {
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Use match').at(1));
      await tester.runAsync(() async {
        final box = Hive.box('user');
        final saved = box.watch(key: 'spotifyMatchResults').first.timeout(const Duration(seconds: 2));
        button.onPressed!();
        await saved;
        await box.flush();
        expect((box.get('spotifyMatchResults') as List).single['bestCandidate']['ytid'], 'owned-b');
        expect(first.loadGate!.isCompleted, isFalse);
        expect(first.disposeGate!.isCompleted, isFalse);
        expect(created, 1);
      });
      await tester.pumpAndSettle();
      expect(find.text('Open manual'), findsOneWidget);
      await tester.runAsync(() async {
        await Hive.close(); Hive.init(root!.path); final box = await Hive.openBox('user');
        expect((box.get('spotifyMatchResults') as List).single['bestCandidate']['ytid'], 'owned-b');
        expect(box.get('likedSongs'), [{'ytid': 'owned-existing-like'}]);
      });
    } finally {
      await tester.pumpWidget(const SizedBox.shrink()); first.finishPending(); await tester.pump();
      await tester.runAsync(() async { await Hive.close(); await root!.delete(recursive: true); });
    }
  });
}

class _Backend implements ReviewSprintAudioPlayer {
  final _states = StreamController<ReviewSprintAudioState>.broadcast();
  final played = <String?>[];
  final _plays = <Completer<void>>[];
  Completer<void>? loadGate;
  Completer<void>? seekGate;
  Completer<void>? disposeGate;
  Object? disposeError;
  String? _url;
  int disposals = 0;
  Future<void>? _disposal;
  @override
  Stream<ReviewSprintAudioState> get stateStream => _states.stream;
  @override
  Future<void> setUrl(String url) async { if (loadGate != null) await loadGate!.future; _url = url; }
  @override
  Future<void> seek(Duration position) async { if (seekGate != null) await seekGate!.future; }
  @override
  Future<void> play() {
    played.add(_url); final playing = Completer<void>(); _plays.add(playing);
    _states.add(const ReviewSprintAudioState(playing: true, completed: false)); return playing.future;
  }
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    disposals++;
    if (disposeGate != null) await disposeGate!.future;
    for (final play in _plays) { if (!play.isCompleted) play.complete(); }
    await _states.close();
    // Model a native failure without letting fixture teardown throw again.
    if (disposeError != null) { final error = disposeError!; disposeError = null; throw error; }
  }
  void finishPending() {
    for (final gate in [loadGate, seekGate, disposeGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
  }
}
