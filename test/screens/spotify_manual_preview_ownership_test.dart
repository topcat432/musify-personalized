import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/screens/spotify_manual_match_page.dart';
import 'package:musify/services/review_sprint_audio_player.dart';
import 'package:musify/services/manual_preview_player_pool.dart';

final _candidates = <Map<String, dynamic>>[
  {'ytid': 'owned-a', 'title': 'Candidate A', 'artist': 'Owned artist', 'duration': 180},
  {'ytid': 'owned-b', 'title': 'Candidate B', 'artist': 'Owned artist', 'duration': 40},
];

void main() {
  late _Player player;
  setUp(() => player = _Player());
  tearDown(() => player.dispose());

  Future<void> mount(WidgetTester tester, Future<String?> Function(String) resolver) async {
    tester.view.physicalSize = const Size(1100, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var initial = true;
    final pool = ManualPreviewPlayerPool(() {
      if (initial) { initial = false; return player; }
      return player.fresh();
    });
    await tester.pumpWidget(MaterialApp(home: SpotifyManualMatchPage(
      item: const {'sourceTitle': 'Owned song', 'sourceArtist': 'Owned artist'},
      audioPlayer: player, previewPool: pool, streamResolver: resolver,
      candidateSearch: (_) async => _candidates,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, int index) async {
    await tester.tap(find.byType(OutlinedButton).at(index));
    await tester.pump();
  }

  for (final failure in [false, true]) {
    testWidgets('late manual preview resolver cannot replace or stop B: failure=$failure', (tester) async {
      final pending = Completer<String?>();
      await mount(tester, (id) => id == 'owned-a' ? pending.future : Future.value('url-b'));
      await preview(tester, 0);
      await preview(tester, 1);
      expect(player.playedUrls, ['url-b']);
      final stops = player.stops;
      if (failure) {
        pending.completeError(StateError('Owned stale resolver error'));
      } else {
        pending.complete('url-a');
      }
      await tester.pump();
      expect(player.loadedUrls, ['url-b'], reason: 'STALE_MANUAL_RESOLVER_LOADED_AFTER_B');
      expect(player.playedUrls, ['url-b']);
      expect(player.stops, stops);
      expect(find.textContaining('Owned stale resolver error'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Pause'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final failure in [false, true]) {
    testWidgets('late native load stays isolated from B: failure=$failure', (tester) async {
      final pending = Completer<void>();
      player.loadGate = pending;
      await mount(tester, (id) async => id == 'owned-a' ? 'url-a' : 'url-b');
      await preview(tester, 0);
      expect(player.operations, contains('load:url-a'));
      await preview(tester, 1);
      if (failure) {
        pending.completeError(StateError('Owned stale native load'));
      } else {
        pending.complete();
      }
      await tester.pump();
      expect(player.currentUrl, 'url-b');
      expect(player.playedUrls, ['url-b']);
      expect(find.textContaining('Owned stale native load'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Pause'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('late seek for A cannot relabel or start the newer B twice', (tester) async {
    final pending = Completer<void>();
    player.seekGate = pending;
    await mount(tester, (id) async => id == 'owned-a' ? 'url-a' : 'url-b');
    await preview(tester, 0);
    expect(player.operations, contains('seek:20000'));
    await preview(tester, 1);
    pending.complete();
    await tester.pump();
    expect(player.currentUrl, 'url-b');
    expect(player.playedUrls, ['url-b']);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton).at(1));
    expect(find.descendant(of: find.byWidget(button), matching: find.text('Pause')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('new manual search invalidates its previous pending preview', (tester) async {
    final pending = Completer<String?>();
    await mount(tester, (_) => pending.future);
    await preview(tester, 0);
    await tester.enterText(find.byType(TextField), 'Owned new query');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    pending.complete('url-a');
    await tester.pump();
    expect(player.loadedUrls, isEmpty);
    expect(player.playedUrls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('leaving manual search prevents a late resolver touching its player', (tester) async {
    final pending = Completer<String?>();
    await mount(tester, (_) => pending.future);
    await preview(tester, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    final operations = List<String>.from(player.operations);
    pending.complete('url-a');
    await tester.pump();
    expect(player.operations, operations);
    expect(player.playedUrls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late play failure cannot stop a newer resume of the same recording', (tester) async {
    player.holdPlayCompletion = true;
    await mount(tester, (_) async => 'url-a');
    await preview(tester, 0);
    await preview(tester, 0);
    await preview(tester, 0);
    expect(player.playedUrls, ['url-a', 'url-a']);
    final stops = player.stops;
    player.playFutures.first.completeError(StateError('Owned prior play failure'));
    await tester.pump();
    expect(player.stops, stops);
    expect(find.textContaining('Owned prior play failure'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Pause'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('manual preview pause resume keeps source and enforces the cutoff', (tester) async {
    await mount(tester, (_) async => 'url-a');
    await preview(tester, 0);
    expect(player.loadedUrls, ['url-a']);
    expect(player.operations, contains('seek:20000'));
    await preview(tester, 0);
    expect(find.widgetWithText(OutlinedButton, 'Pause'), findsNothing);
    await tester.pump(const Duration(seconds: 31));
    final stops = player.stops;
    await preview(tester, 0);
    expect(player.loadedUrls, ['url-a']);
    expect(player.playedUrls, ['url-a', 'url-a']);
    await tester.pump(const Duration(seconds: 29));
    expect(player.stops, stops);
    await tester.pump(const Duration(seconds: 2));
    expect(player.stops, stops + 1);
    expect(find.widgetWithText(OutlinedButton, 'Pause'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _History {
  final operations = <String>[];
  final loadedUrls = <String>[];
  final playedUrls = <String?>[];
  final playFutures = <Completer<void>>[];
  _Player? active;
  int terminations = 0;
  bool holdPlayCompletion = false;
}

class _Player implements ReviewSprintAudioPlayer {
  _Player({_History? history}) : _history = history ?? _History();
  final _History _history;
  final _states = StreamController<ReviewSprintAudioState>.broadcast();
  final _ownedPlays = <Completer<void>>[];
  Completer<void>? loadGate;
  Completer<void>? seekGate;
  Completer<void>? _playing;
  String? _loadedUrl;
  Future<void>? _disposal;
  _Player fresh() => _Player(history: _history);
  List<String> get operations => _history.operations;
  List<String> get loadedUrls => _history.loadedUrls;
  List<String?> get playedUrls => _history.playedUrls;
  List<Completer<void>> get playFutures => _history.playFutures;
  String? get currentUrl => _history.active?._loadedUrl;
  int get stops => _history.terminations;
  set holdPlayCompletion(bool value) => _history.holdPlayCompletion = value;

  @override
  Stream<ReviewSprintAudioState> get stateStream => _states.stream;
  @override
  Future<void> setUrl(String url) async {
    operations.add('load:$url');
    if (url == 'url-a' && loadGate != null) await loadGate!.future;
    _loadedUrl = url;
    loadedUrls.add(url);
  }
  @override
  Future<void> seek(Duration position) async {
    operations.add('seek:${position.inMilliseconds}');
    if (seekGate != null) await seekGate!.future;
  }
  @override
  Future<void> play() {
    operations.add('play:$_loadedUrl');
    _history.active = this;
    playedUrls.add(_loadedUrl);
    _playing = Completer<void>();
    _ownedPlays.add(_playing!);
    playFutures.add(_playing!);
    _states.add(const ReviewSprintAudioState(playing: true, completed: false));
    return _playing!.future;
  }
  void _finish() {
    if (!_history.holdPlayCompletion && _playing != null && !_playing!.isCompleted) _playing!.complete();
    _playing = null;
  }
  @override
  Future<void> pause() async {
    operations.add('pause');
    _finish();
    _states.add(const ReviewSprintAudioState(playing: false, completed: false));
  }
  @override
  Future<void> stop() async {
    operations.add('stop');
    _history.terminations++;
    _finish();
    _states.add(const ReviewSprintAudioState(playing: false, completed: false));
  }
  @override
  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    operations.add('dispose');
    _history.terminations++;
    _finish();
    for (final play in _ownedPlays) {
      if (!play.isCompleted) play.complete();
    }
    await _states.close();
  }
}
