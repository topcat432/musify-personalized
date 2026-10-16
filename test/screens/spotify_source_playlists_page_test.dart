import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_hub_page.dart';
import 'package:musify/screens/spotify_source_playlists_page.dart';
import 'package:musify/services/spotify_import_session_service.dart';
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
      final draft = SpotifyPlaylistDraft.parseBytes(
        SpotifyPlaylistFixture.bytes(),
      );
      final sources = draft.playlists;
      await tester.runAsync(
        () => Hive.box('user').put(
          'spotifyImportTracks',
          draft
              .toPreview(fileName: 'owned.json')
              .tracks
              .map((track) => track.toJson())
              .toList(),
        ),
      );
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
  for (final corruption in [
    'missing row',
    'different URI',
    'missing URI',
    'both missing URI',
    'invalid URI',
  ]) {
    testWidgets(
      'reopened $corruption retains damaged data and shows reference error',
      (tester) async {
        final preview = SpotifyPlaylistDraft.parseBytes(
          SpotifyPlaylistFixture.bytes(),
        ).toPreview(fileName: 'owned.json');
        await tester.runAsync(
          () => const SpotifyImportSessionService().saveNewImport(preview),
        );
        await tester.runAsync(() async {
          final box = Hive.box('user');
          final metadata =
              jsonDecode(jsonEncode(box.get('spotifyImportMetadata'))) as Map;
          final member =
              metadata['sourcePlaylists']['playlists'][0]['members'][0];
          if (corruption == 'missing row') member['sourceRow'] = 9999;
          if (corruption == 'different URI')
            member['sourceMetadata']['uri'] = 'spotify:track:${'B' * 22}';
          if (corruption == 'invalid URI')
            member['sourceMetadata']['uri'] = 'spotify:track:bad';
          if (corruption.contains('missing URI'))
            member['sourceMetadata'].remove('uri');
          if (corruption == 'both missing URI') {
            final tracks =
                jsonDecode(jsonEncode(box.get('spotifyImportTracks'))) as List;
            tracks[0].remove('spotifyTrackUri');
            await box.put('spotifyImportTracks', tracks);
          }
          await box.put('spotifyImportMetadata', metadata);
          await Hive.close();
          await Hive.openBox('user');
        });
        final before = jsonDecode(jsonEncode(Hive.box('user').toMap()));
        await tester.pumpWidget(
          const MaterialApp(home: SpotifySourcePlaylistsPage()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Source data retained'), findsOneWidget);
        expect(find.textContaining('Song retained'), findsNothing);
        expect(find.text('Route resolved songs'), findsNothing);
        expect(Hive.box('user').toMap(), before);
      },
    );
  }
  testWidgets('valid saved membership survives reopen unchanged', (
    tester,
  ) async {
    final preview = SpotifyPlaylistDraft.parseBytes(
      SpotifyPlaylistFixture.bytes(),
    ).toPreview(fileName: 'owned.json');
    await tester.runAsync(() async {
      await const SpotifyImportSessionService().saveNewImport(preview);
      await Hive.close();
      await Hive.openBox('user');
    });
    final before = jsonDecode(jsonEncode(Hive.box('user').toMap()));
    await tester.pumpWidget(
      const MaterialApp(home: SpotifySourcePlaylistsPage()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Song retained'), findsWidgets);
    expect(find.text('Route resolved songs'), findsOneWidget);
    expect(find.text('Source data retained'), findsNothing);
    expect(Hive.box('user').toMap(), before);
    expect(tester.takeException(), isNull);
  });
}
