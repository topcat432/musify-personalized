import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_hub_page.dart';
import 'package:musify/screens/spotify_source_playlists_page.dart';
import 'package:musify/services/spotify_playlist_draft.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import '../support/spotify_playlist_fixture.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('source-review-');
    Hive.init(root.path);
    await Hive.openBox('user');
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  testWidgets(
    'legacy absence stays empty and malformed source stays retained',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SpotifySourcePlaylistsPage()),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('This import has no saved playlist membership.'),
        findsOneWidget,
      );
      await tester.runAsync(
        () => Hive.box('user').put('spotifyImportMetadata', {
          'sourcePlaylists': {'version': 2, 'playlists': []},
          'sentinel': 'keep',
        }),
      );
      final before = jsonDecode(jsonEncode(Hive.box('user').toMap()));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: SpotifySourcePlaylistsPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Source data retained'), findsOneWidget);
      expect(Hive.box('user').toMap(), before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'saved source review link responds to commit without reopening hub',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SpotifyImportHubPage()));
      await tester.pumpAndSettle();
      expect(find.text('Review saved source playlists'), findsNothing);
      final sources = SpotifyPlaylistDraft.parseBytes(
        SpotifyPlaylistFixture.bytes(),
      ).playlists;
      await tester.runAsync(
        () => Hive.box('user').put('spotifyImportMetadata', {
          'sourcePlaylists': SpotifySourcePlaylistCodec.encode(sources),
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review saved source playlists'), findsOneWidget);
      await tester.tap(find.text('Review saved source playlists'));
      await tester.pumpAndSettle();
      expect(find.text('Saved source membership'), findsOneWidget);
      expect(find.text('Unavailable item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'compact large-text source review retains selectable playlist order',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sources = SpotifyPlaylistDraft.parseBytes(
        SpotifyPlaylistFixture.bytes(),
      ).playlists;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: SpotifySourcePlaylistsPage(preview: sources),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1. One'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Two').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Local track; audio was not imported'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Local track; audio was not imported'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
