import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_page.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_file_reader.dart';

void main() {
  late Directory root;
  late FilePickerPlatform originalPicker;
  late _Picker picker;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('import-page-');
    Hive.init(root.path);
    await Hive.openBox('user');
    originalPicker = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    await Hive.close();
    await root.delete(recursive: true);
  });
  FilePickerResult csv(String name) {
    final bytes = Uint8List.fromList(
      utf8.encode(
        'index,title,artist,album\n0,$name,Owned artist,Owned album\n',
      ),
    );
    return FilePickerResult([
      PlatformFile(name: '$name.csv', size: bytes.length, bytes: bytes),
    ]);
  }

  Finder button(String label) => find.widgetWithText(FilledButton, label);
  Future<void> pumpPage(
    WidgetTester tester,
    SpotifyImportSessionService service, {
    SpotifyImportReader readFile = SpotifyImportFileReader.read,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SpotifyImportPage(sessionService: service, readFile: readFile),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleSave(WidgetTester tester) async {
    // Give real Hive file I/O time while advancing the widget's fake clock.
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
      if (find.text('Saving\u2026').evaluate().isEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
    fail(
      'The owned import write did not complete within the bounded I/O wait.',
    );
  }

  Future<void> choose(WidgetTester tester, String name) async {
    picker.results.add(Future.value(csv(name)));
    await tester.tap(button('Choose song list file'));
    await tester.pumpAndSettle();
  }

  testWidgets('saved picker cancellation retains ready and outcomes', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _IoSessionService(sessionWriter: (box, values) => box.putAll(values)),
    );
    await choose(tester, 'A');
    await tester.tap(button('Save and continue'));
    await tester.pump();
    await settleSave(tester);
    await tester.runAsync(
      () => Hive.box('user').put('spotifyMatchResults', [
        {'status': 'accepted'},
      ]),
    );
    picker.results.add(Future.value(null));
    await tester.tap(button('Choose song list file'));
    await tester.pumpAndSettle();
    expect(find.text('Ready for matching'), findsOneWidget);
    expect(Hive.box('user').get('spotifyMatchResults'), [
      {'status': 'accepted'},
    ]);
  });
  testWidgets('stale saved callback cannot replace matching work', (
    tester,
  ) async {
    var writes = 0;
    await pumpPage(
      tester,
      _IoSessionService(
        sessionWriter: (box, values) async {
          writes++;
          await box.putAll(values);
        },
      ),
    );
    await choose(tester, 'A');
    final callback = tester
        .widget<FilledButton>(button('Save and continue'))
        .onPressed!;
    await tester.tap(button('Save and continue'));
    await tester.pump();
    await settleSave(tester);
    await tester.runAsync(
      () => Hive.box('user').put('spotifyMatchResults', [
        {'status': 'accepted'},
      ]),
    );
    callback();
    await tester.pump();
    await settleSave(tester);
    expect(Hive.box('user').get('spotifyMatchResults'), [
      {'status': 'accepted'},
    ]);
    expect(writes, 1);
  });

  testWidgets(
    'pending save rejects new selection and completion marks only its preview',
    (tester) async {
      final pending = Completer<void>();
      var writes = 0;
      await pumpPage(
        tester,
        _IoSessionService(
          sessionWriter: (box, values) async {
            writes++;
            await pending.future;
            await box.putAll(values);
          },
        ),
      );
      await choose(tester, 'A');
      final stalePickCallback = tester
          .widget<FilledButton>(button('Choose song list file'))
          .onPressed!;
      await tester.tap(button('Save and continue'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(button('Choose song list file')).onPressed,
        isNull,
      );
      stalePickCallback();
      await tester.pump();
      expect(picker.calls, 1);
      expect(find.text('Ready for matching'), findsNothing);
      pending.complete();
      await settleSave(tester);
      expect(find.text('Ready for matching'), findsOneWidget);
      expect(
        (Hive.box('user').get('spotifyImportMetadata') as Map)['fileName'],
        'A.csv',
      );
      expect(writes, 1);
      expect(
        tester.widget<FilledButton>(button('Saved for matching')).onPressed,
        isNull,
      );
      await tester.runAsync(
        () => Hive.box('user').put('spotifyMatchResults', [
          {'sourceRow': 2, 'status': 'accepted'},
        ]),
      );
      picker.results.add(Future.value(null));
      await tester.tap(button('Choose song list file'));
      await tester.pumpAndSettle();
      expect(find.text('Ready for matching'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(button('Saved for matching')).onPressed,
        isNull,
      );
      expect(Hive.box('user').get('spotifyMatchResults'), [
        {'sourceRow': 2, 'status': 'accepted'},
      ]);
      await choose(tester, 'B');
      expect(find.text('Ready for matching'), findsNothing);
      expect(find.text('B.csv'), findsNWidgets(2));
      expect(
        (Hive.box('user').get('spotifyImportMetadata') as Map)['fileName'],
        'A.csv',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pending file read blocks stale save callback and cancellation preserves preview',
    (tester) async {
      var writes = 0;
      await pumpPage(
        tester,
        _IoSessionService(
          sessionWriter: (box, values) async {
            writes++;
            await box.putAll(values);
          },
        ),
      );
      await choose(tester, 'A');
      final staleSaveCallback = tester
          .widget<FilledButton>(button('Save and continue'))
          .onPressed!;
      final read = Completer<FilePickerResult?>();
      picker.results.add(read.future);
      await tester.tap(button('Choose song list file'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(button('Save and continue')).onPressed,
        isNull,
      );
      staleSaveCallback();
      await tester.pump();
      expect(writes, 0);
      read.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('A.csv'), findsNWidgets(2));
      expect(
        tester.widget<FilledButton>(button('Save and continue')).onPressed,
        isNotNull,
      );
      expect(Hive.box('user').containsKey('spotifyImportMetadata'), isFalse);
    },
  );
  testWidgets(
    'failed delayed save releases controls and retains previous session',
    (tester) async {
      await tester.runAsync(
        () => Hive.box('user').putAll({
          'spotifyImportMetadata': {'fileName': 'original.csv'},
          'spotifyMatchResults': [
            {'status': 'accepted'},
          ],
        }),
      );
      final pending = Completer<void>();
      await pumpPage(
        tester,
        _IoSessionService(
          sessionWriter: (box, values) async {
            await pending.future;
            await box.putAll(values);
            throw StateError('Owned write failure');
          },
        ),
      );
      await choose(tester, 'A');
      await tester.tap(button('Save and continue'));
      await tester.pump();
      pending.complete();
      await settleSave(tester);
      expect(find.text('Ready for matching'), findsNothing);
      expect(find.text('The import could not be saved.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(button('Save and continue')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<FilledButton>(button('Choose song list file')).onPressed,
        isNotNull,
      );
      expect(Hive.box('user').get('spotifyImportMetadata'), {
        'fileName': 'original.csv',
      });
      expect(Hive.box('user').get('spotifyMatchResults'), [
        {'status': 'accepted'},
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'TSV preview saves offline and reopens in the existing session shape',
    (tester) async {
      final bytes = Uint8List.fromList(
        utf8.encode(
          'title\tartist\tduration ms\nFirst, original\tOwned artist\t8000\nSecond\tOther artist\t9000\n',
        ),
      );
      picker.results.add(
        Future.value(
          FilePickerResult([
            PlatformFile(name: 'owned.tsv', size: bytes.length, bytes: bytes),
          ]),
        ),
      );
      await tester.runAsync(
        () => Hive.box('user').put('likedSongs', ['keep-owned-liked']),
      );
      await pumpPage(tester, const _IoSessionService());
      await tester.tap(button('Choose song list file'));
      await tester.pumpAndSettle();
      expect(picker.extensions, ['csv', 'tsv', 'json']);
      expect(find.text('Generic music TSV'), findsOneWidget);
      expect(find.text('First, original'), findsOneWidget);
      expect(Hive.box('user').containsKey('spotifyImportTracks'), isFalse);
      await tester.ensureVisible(button('Save and continue'));
      await tester.tap(button('Save and continue'));
      await settleSave(tester);
      expect(find.text('Ready for matching'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Hive.close();
        final box = await Hive.openBox('user');
        expect(
          (box.get('spotifyImportTracks') as List).map((t) => t['title']),
          ['First, original', 'Second'],
        );
        expect(
          (box.get('spotifyImportTracks') as List).map((t) => t['sourceRow']),
          [2, 3],
        );
        expect(box.get('spotifyImportMetadata')['fileName'], 'owned.tsv');
        expect(box.get('spotifyImportMetadata')['format'], 'Generic music TSV');
        expect(
          box.get('spotifyImportMetadata')['matchingStatus'],
          'not_started',
        );
        expect(box.get('spotifyMatchResults'), isEmpty);
        expect(box.get('likedSongs'), ['keep-owned-liked']);
      });
    },
  );

  testWidgets(
    'invalid TSV preview leaves the existing completed import intact',
    (tester) async {
      final box = Hive.box('user');
      await tester.runAsync(
        () => box.putAll({
          'spotifyImportTracks': [
            {'title': 'Owned original'},
          ],
          'spotifyImportMetadata': {
            'fileName': 'original.csv',
            'matchingStatus': 'completed',
          },
          'spotifyMatchResults': [
            {'status': 'accepted', 'ytid': 'owned-choice'},
          ],
        }),
      );
      final before = Map<dynamic, dynamic>.from(box.toMap());
      final bytes = Uint8List.fromList(
        utf8.encode('album\tgenre\nOwned\tRock\n'),
      );
      picker.results.add(
        Future.value(
          FilePickerResult([
            PlatformFile(name: 'invalid.tsv', size: bytes.length, bytes: bytes),
          ]),
        ),
      );
      await pumpPage(tester, const _IoSessionService());
      await tester.tap(button('Choose song list file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('A title/track-name column'), findsOneWidget);
      expect(box.toMap(), before);
      expect(button('Save and continue'), findsNothing);
    },
  );
  testWidgets(
    'JSON preview discloses track-only scope and saves only on explicit approval',
    (tester) async {
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'tracks': [
              {
                'artist': 'Owned artist',
                'track': 'Saved JSON song',
                'album': 'Owned album',
                'uri': 'spotify:track:AAAAAAAAAAAAAAAAAAAAAA',
              },
            ],
            'albums': [{}],
          }),
        ),
      );
      picker.results.add(
        Future.value(
          FilePickerResult([
            PlatformFile(
              name: 'YourLibrary.json',
              size: bytes.length,
              bytes: bytes,
            ),
          ]),
        ),
      );
      await pumpPage(tester, const _IoSessionService());
      await tester.tap(button('Choose song list file'));
      await tester.pumpAndSettle();
      expect(picker.extensions, ['csv', 'tsv', 'json']);
      expect(picker.streamed, isTrue);
      expect(picker.inMemory, isFalse);
      expect(find.text('Spotify saved tracks JSON'), findsOneWidget);
      expect(find.text('Albums: 1 entry not imported.'), findsOneWidget);
      expect(Hive.box('user').containsKey('spotifyImportTracks'), isFalse);
      await tester.ensureVisible(button('Save and continue'));
      await tester.tap(button('Save and continue'));
      await settleSave(tester);
      expect(find.text('Ready for matching'), findsOneWidget);
      expect(Hive.box('user').get('spotifyImportTracks')[0]['sourceRow'], 1);
      expect(
        Hive.box('user').get('spotifyImportTracks')[0]['spotifyTrackId'],
        'AAAAAAAAAAAAAAAAAAAAAA',
      );
      expect(
        Hive.box('user').get('spotifyImportMetadata').containsKey('notices'),
        isFalse,
      );
      picker.results.add(Future.value(null));
      await tester.tap(button('Choose song list file'));
      await tester.pumpAndSettle();
      expect(find.text('Ready for matching'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(button('Saved for matching')).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'unsupported JSON leaves the existing completed source and decisions untouched',
    (tester) async {
      final box = Hive.box('user');
      await tester.runAsync(
        () => box.putAll({
          'spotifyImportMetadata': {
            'fileName': 'old.csv',
            'matchingStatus': 'completed',
          },
          'spotifyMatchResults': [
            {'ytid': 'owned-choice', 'status': 'accepted'},
          ],
        }),
      );
      final before = Map<dynamic, dynamic>.from(box.toMap());
      final bytes = Uint8List.fromList(utf8.encode('{"playlists":[]}'));
      picker.results.add(
        Future.value(
          FilePickerResult([
            PlatformFile(
              name: 'Playlist.json',
              size: bytes.length,
              bytes: bytes,
            ),
          ]),
        ),
      );
      await pumpPage(tester, const _IoSessionService());
      await tester.tap(button('Choose song list file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only Spotify YourLibrary'), findsOneWidget);
      expect(box.toMap(), before);
      expect(button('Save and continue'), findsNothing);
    },
  );

  testWidgets('closing import page cancels its reader without saving', (
    tester,
  ) async {
    var stopped = false;
    picker.results.add(
      Future.value(
        FilePickerResult([PlatformFile(name: 'YourLibrary.json', size: 100)]),
      ),
    );
    Future<Uint8List> pendingRead(
      PlatformFile file, {
      Future<void>? cancelled,
    }) async {
      await cancelled;
      stopped = true;
      throw const SpotifyImportException('Owned cancelled read');
    }

    await pumpPage(tester, const _IoSessionService(), readFile: pendingRead);
    await tester.tap(button('Choose song list file'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(stopped, isTrue);
    expect(Hive.box('user').containsKey('spotifyImportTracks'), isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _Picker extends FilePickerPlatform {
  final results = <Future<FilePickerResult?>>[];
  int calls = 0;
  List<String>? extensions;
  bool? streamed;
  bool? inMemory;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) {
    extensions = allowedExtensions;
    streamed = withReadStream;
    inMemory = withData;
    calls++;
    return results.removeAt(0);
  }
}

// Hive's serialized I/O must not retain Flutter's per-test fake-clock zone.
class _IoSessionService extends SpotifyImportSessionService {
  const _IoSessionService({super.sessionWriter});
  @override
  Future<void> saveNewImport(
    SpotifyImportPreview preview, {
    DateTime? importedAt,
  }) {
    final completion = Completer<void>();
    Zone.root.run(() {
      super
          .saveNewImport(preview, importedAt: importedAt)
          .then(
            (_) => completion.complete(),
            onError: (Object error, StackTrace stack) =>
                completion.completeError(error, stack),
          );
    });
    return completion.future;
  }
}
