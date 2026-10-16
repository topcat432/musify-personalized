import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_incoming_files_page.dart';
import 'package:musify/screens/spotify_import_page.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_incoming_file_inbox.dart';
import 'package:musify/services/spotify_incoming_file_service.dart';

class OwnedService extends SpotifyIncomingFileService {
  int reads = 0;
  bool failRead = false;
  bool disposed = false;
  List<int>? sourceBytes;
  Completer<List<int>>? pending;
  @override
  Stream<List<int>> openStream(SpotifyIncomingFile file) async* {
    reads++;
    if (failRead) throw const SpotifyImportException('Owned read failed; prior import retained.');
    yield pending == null ? sourceBytes ?? utf8.encode('Title,Artist\nOwned,Artist\n') : await pending!.future;
  }
  @override
  Future<void> finish(SpotifyIncomingFileLease lease) async { if (inbox.finish(lease) && !disposed) notifyListeners(); }
  @override
  Future<void> dismiss(String id) async { inbox.dismiss(id); notifyListeners(); }
  @override
  void dispose() { disposed = true; super.dispose(); }
}
Future<void> settlePreview(WidgetTester tester, String label) async {
  // The bounded StreamIterator performs asynchronous subscription cleanup.
  // Wait for the observable result rather than assuming a frame means I/O ended.
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 10));
    if (find.text(label).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Preview did not reach its expected result: $label');
}
void main() {
  late Directory root;
  late OwnedService service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('incoming-widget-');
    Hive.init(root.path); await Hive.openBox('user');
    await Hive.box('user').putAll({'spotifyImportTracks': [{'sentinel': 'completed'}], 'spotifyMatchResults': [{'sentinel': 'selected'}]});
    service = OwnedService();
    service.inbox.offer(SpotifyIncomingFile(id: 'a', uri: Uri.parse('content://owned/a'), name: 'owned.csv', readGrantVerified: true));
  });
  tearDown(() async { service.dispose(); await Hive.close(); await root.delete(recursive: true); });
  testWidgets('arrival and explicit preview never save prior completed import', (tester) async {
    final before = jsonDecode(jsonEncode(Hive.box('user').toMap()));
    await tester.binding.setSurfaceSize(const Size(900,1800)); addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: SpotifyIncomingFilesPage(service: service)));
    await tester.pumpAndSettle(); expect(service.reads, 0);
    await tester.tap(find.text('Preview')); await settlePreview(tester, 'Save and continue');
    expect(service.reads, 1); expect(find.text('Save and continue'), findsOneWidget);
    expect(Hive.box('user').toMap(), before);
    await tester.pageBack(); await tester.pumpAndSettle();
    expect(service.inbox.active, isNull); expect(Hive.box('user').toMap(), before);
  });
  testWidgets('read failure retains active request for deliberate retry', (tester) async {
    service.failRead = true;
    final before = jsonDecode(jsonEncode(Hive.box('user').toMap()));
    await tester.pumpWidget(MaterialApp(home: SpotifyIncomingFilesPage(service: service)));
    await tester.pumpAndSettle(); await tester.tap(find.text('Preview')); await settlePreview(tester, 'Retry preview');
    expect(service.inbox.active!.id, 'a'); expect(find.text('Retry preview'), findsOneWidget);
    expect(Hive.box('user').toMap(), before);
    service.failRead = false;
    await tester.tap(find.text('Retry preview'));
    await settlePreview(tester, 'Import song list');
    expect(find.byType(SpotifyImportPage), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Save and continue'), 200, scrollable: find.descendant(of: find.byType(SpotifyImportPage), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('Save and continue'), findsOneWidget); expect(service.reads, 2);
    expect(Hive.box('user').toMap(), before);
  });
  testWidgets('cancel and late bytes cannot open a successor preview', (tester) async {
    service.pending = Completer<List<int>>();
    final before = jsonDecode(jsonEncode(Hive.box('user').toMap()));
    await tester.pumpWidget(MaterialApp(home: SpotifyIncomingFilesPage(service: service)));
    await tester.pumpAndSettle(); await tester.tap(find.text('Preview')); await tester.pump();
    await tester.tap(find.text('Cancel read')); await tester.pumpAndSettle();
    service.pending!.complete(utf8.encode('Title,Artist\nLate,Owner\n'));
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Save and continue'), findsNothing); expect(service.inbox.active, isNull);
    expect(Hive.box('user').toMap(), before);
  });
  testWidgets('global notice and second inbox preserve the active reading and Save preview owner', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    service.inbox.offer(SpotifyIncomingFile(id: 'b', uri: Uri.parse('content://owned/b'), name: 'b.csv', readGrantVerified: true));
    service.pending = Completer<List<int>>();
    final before = jsonDecode(jsonEncode(Hive.box('user').toMap()));
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('Owned home')),
      builder: (context, child) => Stack(children: [child!, Align(alignment: Alignment.topCenter, child: SpotifyIncomingFileNotice(service: service, onReview: () => navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => SpotifyIncomingFilesPage(service: service)))))]),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review')); await tester.pumpAndSettle();
    await tester.tap(find.text('Preview').first); await tester.pump();
    expect(service.inbox.active!.id, 'a');
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Review')).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Preview')).onPressed, isNull);
    await tester.tap(find.text('Review')); await tester.tap(find.text('Preview')); await tester.pump();
    expect(tester.takeException(), isNull); expect(service.reads, 1);
    expect(service.inbox.pending.single.id, 'b'); expect(Hive.box('user').toMap(), before);
    service.pending!.complete(utf8.encode('Title,Artist\nOwned,Artist\n'));
    await settlePreview(tester, 'Save and continue');
    expect(find.byType(SpotifyImportPage), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Review')).onPressed, isNull);
    await tester.tap(find.text('Review')); await tester.pump();
    // A second entry route must also respect the global owner even if reached
    // through navigation independent of the arrival notice.
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => SpotifyIncomingFilesPage(service: service))));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Preview')).onPressed, isNull);
    await tester.tap(find.text('Preview')); await tester.pump();
    expect(tester.takeException(), isNull); expect(service.reads, 1);
    expect(service.inbox.active!.id, 'a'); expect(service.inbox.pending.single.id, 'b');
    expect(Hive.box('user').toMap(), before);
    navigator.currentState!.pop(); await tester.pumpAndSettle();
    navigator.currentState!.pop(); await tester.pumpAndSettle();
    expect(service.inbox.active, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Preview')).onPressed, isNotNull);
    expect(Hive.box('user').toMap(), before);
  });
  testWidgets('incoming many-row rejection preserves the completed import and retry lease', (tester) async {
    service.sourceBytes = utf8.encode('Title,Artist\n${List.filled(SpotifyCsvImporter.maxJsonTracks + 1, 'a,b\n').join()}"malformed tail');
    final before = jsonDecode(jsonEncode(Hive.box('user').toMap()));
    await tester.pumpWidget(MaterialApp(home: SpotifyIncomingFilesPage(service: service)));
    await tester.pumpAndSettle(); await tester.tap(find.text('Preview'));
    await settlePreview(tester, 'Retry preview');
    expect(find.text('Incoming song lists must contain at most ${SpotifyCsvImporter.maxJsonTracks} data rows.'), findsOneWidget);
    expect(service.inbox.active!.id, 'a'); expect(Hive.box('user').toMap(), before);
    await tester.tap(find.text('Cancel read')); await tester.pumpAndSettle();
    expect(service.inbox.active, isNull); expect(Hive.box('user').toMap(), before);
  });
}
