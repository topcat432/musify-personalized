import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_source_playlist_copy_page.dart';
import 'package:musify/screens/spotify_source_playlists_page.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import 'package:musify/services/spotify_playlist_draft.dart';

import '../../tool/visual_review_harness.dart';
import '../support/spotify_source_copy_fixture.dart';

void main() {
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('source-copy-page-');
    Hive.init(root.path); await initPriorityReviewHive(); resetPriorityReviewGlobals();
    await SpotifySourceCopyFixture.seed();
  });
  tearDown(() async { await Hive.close(); await root.delete(recursive: true); });
  Object? inventory() => copyImportRoutingValue(Hive.box('user').toMap());
  List<Map> playlists() => List<Map>.from(Hive.box('user').get('customPlaylists'));
  Future<void> open(WidgetTester tester, _IoCopyService service, {double scale = 2}) async {
    await tester.binding.setSurfaceSize(const Size(412, 915)); addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(priorityReviewApp(brightness: Brightness.dark, textScale: scale, reducedMotion: true,
      child: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () => Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => RepaintBoundary(key: const ValueKey('copy-capture'),
          child: SpotifySourcePlaylistCopyPage(sourcePosition: 1, service: service)))), child: const Text('Open copy preview'))))));
    await tester.tap(find.text('Open copy preview')); await tester.pump();
    await tester.runAsync(() => service.lastPreview!); await tester.pumpAndSettle();
  }
  Future<void> confirm(WidgetTester tester, _IoCopyService service, {String label = 'Create playlist copy'}) async {
    await tester.tap(find.text(label)); await tester.pump();
    await tester.runAsync(() => service.lastCreation!); await tester.pumpAndSettle();
  }
  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.environment['MUSIFY_SOURCE_COPY_CAPTURE'] != '1') return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('copy-capture')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = await Directory('build/source-copy-review').create(recursive: true);
        await File('${directory.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
        if (name == 'source-copy-created-dark-compact-2x') {
          final beforeFile = File('${directory.path}/source-copy-preview-dark-compact-2x.png');
          if (await beforeFile.exists()) {
            final codec = await ui.instantiateImageCodec(await beforeFile.readAsBytes());
            final frame = await codec.getNextFrame(); final recorder = ui.PictureRecorder();
            Canvas(recorder)..drawImage(frame.image, Offset.zero, Paint())
              ..drawImage(image, Offset.zero, Paint()..blendMode = BlendMode.difference);
            final picture = recorder.endRecording(); final difference = await picture.toImage(image.width, image.height);
            try {
              final data = await difference.toByteData(format: ui.ImageByteFormat.png);
              await File('${directory.path}/source-copy-state-diff-dark-compact-2x.png').writeAsBytes(data!.buffer.asUint8List(), flush: true);
            } finally { difference.dispose(); picture.dispose(); frame.image.dispose(); codec.dispose(); }
          }
        }
      } finally { image.dispose(); }
    });
  }
  testWidgets('compact2x preview explains exact repeated slots and cancel writes nothing', (tester) async {
    final service = _IoCopyService(); final before = inventory(); await open(tester, service);
    expect(find.textContaining('3 playlist entries'), findsOneWidget);
    expect(find.textContaining('2 unique recordings'), findsOneWidget);
    expect(find.textContaining('1 repeated entry'), findsOneWidget);
    expect(find.text('Create playlist copy').hitTestable(), findsOneWidget);
    await capture(tester, 'source-copy-preview-dark-compact-2x');
    expect(inventory(), before); await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    expect(find.text('Open copy preview'), findsOneWidget); expect(inventory(), before); expect(tester.takeException(), isNull);
  });
  testWidgets('explicit confirm saves chosen original-order slots once and completed re-entry is a no-op', (tester) async {
    final service = _IoCopyService(); await open(tester, service); await confirm(tester, service);
    expect(playlists(), hasLength(2)); expect(playlists().last['list'].map((song) => song['ytid']), SpotifySourceCopyFixture.expectedIds);
    expect(find.textContaining('Created "Synthetic source order"'), findsOneWidget);
    await capture(tester, 'source-copy-created-dark-compact-2x');
    await tester.tap(find.text('Done')); await tester.pumpAndSettle();
    await tester.tap(find.text('Open copy preview')); await tester.pump(); await tester.runAsync(() => service.lastPreview!); await tester.pumpAndSettle();
    expect(find.text('Copy already exists'), findsOneWidget); final before = inventory();
    await confirm(tester, service, label: 'Verify existing copy'); expect(inventory(), before); expect(tester.takeException(), isNull);
  });
  testWidgets('another copy needs a fresh explicit preview and confirmation', (tester) async {
    final service = _IoCopyService(); await open(tester, service); await confirm(tester, service);
    final before = inventory(); await tester.tap(find.text('Review another independent copy')); await tester.pump();
    await tester.runAsync(() => service.lastPreview!); await tester.pumpAndSettle();
    expect(find.text('Another independent copy'), findsOneWidget); expect(inventory(), before);
    await confirm(tester, service); expect(playlists(), hasLength(3)); expect(tester.takeException(), isNull);
  });
  testWidgets('unresolved source shows retained review and never exposes confirmation', (tester) async {
    final results = List<Map>.from(Hive.box('user').get('spotifyMatchResults'))..removeLast();
    await tester.runAsync(() => Hive.box('user').put('spotifyMatchResults', results));
    final before = inventory(); await open(tester, _IoCopyService());
    expect(find.text('Create playlist copy'), findsNothing); expect(find.text('Source copy retained for review'), findsOneWidget);
    expect(inventory(), before); expect(tester.takeException(), isNull);
  });
  testWidgets('stale choice after preview reports retained state without creating a playlist', (tester) async {
    final service = _IoCopyService(); await open(tester, service);
    final rows = copyImportRoutingValue(Hive.box('user').get('spotifyMatchResults')) as List;
    rows.first['bestCandidate']['ytid'] = 'new-owner-choice'; await tester.runAsync(() => Hive.box('user').put('spotifyMatchResults', rows));
    final before = inventory(); await confirm(tester, service);
    expect(inventory(), before); expect(find.textContaining('resolved recordings changed'), findsOneWidget); expect(tester.takeException(), isNull);
  });
  testWidgets('audit failure says saved/unverified and navigation disposal cannot change durable outcome', (tester) async {
    var calls = 0;
    final service = _IoCopyService(metadataWriter: (box, values) async {
      calls++; if (calls == 2) throw StateError('Injected audit failure'); await box.put('spotifyImportMetadata', values);
    });
    await open(tester, service); await confirm(tester, service);
    expect(playlists(), hasLength(2)); expect(find.textContaining('is saved, but verification is incomplete'), findsOneWidget);
    expect(Hive.box('user').get('spotifyImportMetadata')[importRoutingPendingKey], isA<Map>());
    await capture(tester, 'source-copy-unverified-dark-compact-2x');
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(); expect(tester.takeException(), isNull);
  });
  testWidgets('page disposal during held final audit keeps the lock and finishes without setState after dispose', (tester) async {
    final entered = Zone.root.run(() => Completer<void>()); final release = Zone.root.run(() => Completer<void>()); var calls = 0;
    final service = _IoCopyService(metadataWriter: (box, values) async {
      calls++; await box.put('spotifyImportMetadata', values); if (calls == 2) { entered.complete(); await release.future; }
    });
    await open(tester, service); await tester.tap(find.text('Create playlist copy')); await tester.pump();
    await tester.runAsync(() => entered.future); await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async { release.complete(); await service.lastCreation!; }); await tester.pump();
    expect(playlists(), hasLength(2)); expect(Hive.box('user').get('spotifyImportMetadata').containsKey(importRoutingPendingKey), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unsaved source preview never offers the new creation action', (tester) async {
    final metadata = Hive.box('user').get('spotifyImportMetadata') as Map;
    final sources = SpotifySourcePlaylistCodec.readSaved(metadata['sourcePlaylists'], Hive.box('user').get('spotifyImportTracks'));
    await tester.pumpWidget(MaterialApp(home: SpotifySourcePlaylistsPage(preview: sources))); await tester.pumpAndSettle();
    expect(find.text('Review source-order copy'), findsNothing); expect(playlists(), hasLength(1));
  });
  testWidgets('saved source action opens a light-theme explicit preview without an automatic write', (tester) async {
    final service = _IoCopyService(); final before = inventory();
    await tester.binding.setSurfaceSize(const Size(412, 915)); addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(priorityReviewApp(brightness: Brightness.light, reducedMotion: true,
      child: SpotifySourcePlaylistsPage(routingService: service))); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review source-order copy')); await tester.tap(find.text('Review source-order copy')); await tester.pump();
    await tester.runAsync(() => service.lastPreview!); await tester.pumpAndSettle();
    expect(find.text('Playlist copy'), findsOneWidget); expect(find.text('Create playlist copy').hitTestable(), findsOneWidget);
    expect(find.text('Selected alternative A'), findsNWidgets(2));
    expect(inventory(), before); expect(tester.takeException(), isNull);
  });
}

typedef _Outcome<T> = ({T? value, Object? error, StackTrace? stack});
Future<_Outcome<T>> _realIo<T>(Future<T> Function() action) => Zone.root.run(() async {
  try { return (value: await action(), error: null, stack: null); }
  catch (error, stack) { return (value: null, error: error, stack: stack); }
});
class _IoCopyService extends SpotifyImportDestinationService {
  _IoCopyService({super.metadataWriter});
  Future<void>? lastPreview, lastCreation;
  @override
  Future<SpotifyPlaylistCopyPreview> previewSourcePlaylistCopy(int position, {String? title, bool additionalCopy = false}) async {
    final outcome = _realIo(() => super.previewSourcePlaylistCopy(position, title: title, additionalCopy: additionalCopy));
    lastPreview = Zone.root.run(() => outcome.then<void>((_) {})); final completed = await outcome;
    if (completed.error != null) Error.throwWithStackTrace(completed.error!, completed.stack!); return completed.value!;
  }
  @override
  Future<SpotifyPlaylistCopyResult> createSourcePlaylistCopy(SpotifyPlaylistCopyPreview preview) async {
    final outcome = _realIo(() => super.createSourcePlaylistCopy(preview));
    lastCreation = Zone.root.run(() => outcome.then<void>((_) {})); final completed = await outcome;
    if (completed.error != null) Error.throwWithStackTrace(completed.error!, completed.stack!); return completed.value!;
  }
}
