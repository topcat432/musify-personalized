import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_page.dart';
import 'package:musify/screens/spotify_source_playlists_page.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import '../../tool/visual_review_harness.dart';
import '../support/spotify_empty_source_fixture.dart';

void main() {
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {root=await Directory.systemTemp.createTemp('empty-source-page-');Hive.init(root.path);await initPriorityReviewHive();resetPriorityReviewGlobals();await SpotifyEmptySourceFixture.seed();});
  tearDown(() async {await Hive.close();await root.delete(recursive:true);});
  List<Map> playlists()=>List<Map>.from(Hive.box('user').get('customPlaylists',defaultValue:[]));
  Future<void> open(WidgetTester tester, {_IoEmptyService? service}) async {
    await tester.binding.setSurfaceSize(const Size(412,915));addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(priorityReviewApp(child:SpotifySourcePlaylistsPage(routingService:service??_IoEmptyService()),brightness:Brightness.dark,textScale:2,reducedMotion:true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Review empty playlist creation'),150,scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }
  Future<void> review(WidgetTester tester) async {await tester.pumpAndSettle();await tester.ensureVisible(find.text('Review empty playlist creation'));await tester.pumpAndSettle();expect(find.text('Review empty playlist creation').hitTestable(),findsOneWidget);await tester.tap(find.text('Review empty playlist creation'));await tester.pumpAndSettle();expect(find.text('Create empty source playlist?'),findsOneWidget);expect(find.textContaining('0 source items'),findsWidgets);}
  Future<void> confirm(WidgetTester tester,_IoEmptyService service) async {
    await tester.tap(find.text('Confirm empty playlist'));await tester.pump();
    await tester.runAsync(()=>service.lastCreation!.then<void>((_) {},onError:(Object _,StackTrace __) {}));await tester.pumpAndSettle();
  }
  testWidgets('compact2x explicit zero-song confirmation cancel create and repeat preserve unrelated content',(tester) async {
    final service=_IoEmptyService();final before=jsonDecode(jsonEncode(Hive.box('user').toMap()));
    await open(tester,service:service);expect(playlists().length,1);await review(tester);await tester.tap(find.text('Cancel'));await tester.pumpAndSettle();expect(Hive.box('user').toMap(),before);
    await review(tester);await confirm(tester,service);expect(playlists().length,2);expect(playlists().last['list'],isEmpty);
    await tester.scrollUntilVisible(find.text('Review empty playlist creation'),150,scrollable:find.byType(Scrollable).first);
    await review(tester);await confirm(tester,service);expect(playlists().length,2);
    expect(find.textContaining('Reused'),findsOneWidget);expect(find.textContaining('0 songs transferred'),findsOneWidget);expect(tester.takeException(),isNull);
  });
  testWidgets('source becoming nonempty during confirmation fails without creating destination',(tester) async {
    final service=_IoEmptyService();await open(tester,service:service);await review(tester);
    await tester.runAsync(() async {final metadata=Map<String,dynamic>.from(Hive.box('user').get('spotifyImportMetadata'));final sources=metadata['sourcePlaylists']['playlists'] as List;sources[0]['members']=sources[1]['members'];metadata['totalDataRows']=2;await Hive.box('user').put('spotifyImportMetadata',metadata);});
    await confirm(tester,service);expect(playlists().length,1);expect(find.textContaining('changed'),findsWidgets);expect(tester.takeException(),isNull);
  });
  testWidgets('preview-only empty source never exposes a create or transfer action',(tester) async {
    await tester.pumpWidget(MaterialApp(home:SpotifySourcePlaylistsPage(preview:SpotifyEmptySourceFixture.preview(song:false).sourcePlaylists)));
    await tester.pumpAndSettle();expect(find.text('Review empty playlist creation'),findsNothing);expect(find.text('Route resolved songs'),findsNothing);expect(playlists().length,1);
  });
  testWidgets('unsupported-only selected source is disclosed as nonempty rather than empty creation',(tester) async {
    await tester.runAsync(()=>SpotifyEmptySourceFixture.seed(song:false,unsupported:true));
    await tester.pumpWidget(const MaterialApp(home:SpotifySourcePlaylistsPage()));await tester.pumpAndSettle();
    final dropdown=find.byType(DropdownButtonFormField<int>);await tester.tap(dropdown);await tester.pumpAndSettle();await tester.tap(find.text('2. Owned other').last);await tester.pumpAndSettle();
    expect(find.text('1 source items'),findsOneWidget);expect(find.text('Review empty playlist creation'),findsNothing);expect(find.text('Route resolved songs'),findsOneWidget);expect(playlists().length,1);expect(tester.takeException(),isNull);
  });
  testWidgets('saved empty-only import opens actionable source review without automatic destination creation',(tester) async {
    final save=_IoSessionService();final preview=SpotifyEmptySourceFixture.preview(song:false);
    await tester.binding.setSurfaceSize(const Size(900,1800));addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(priorityReviewApp(child:SpotifyImportPage(initialPreview:preview,sessionService:save),brightness:Brightness.dark,reducedMotion:true));await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save and continue'));await tester.tap(find.text('Save and continue'));await tester.pump();await tester.runAsync(()=>save.lastSave!);await tester.pumpAndSettle();
    expect(find.text('Saved source playlists'),findsOneWidget);expect(playlists().length,1);
    await tester.ensureVisible(find.text('Review source playlists'));await tester.tap(find.text('Review source playlists'));await tester.pumpAndSettle();
    expect(find.text('Saved source membership'),findsOneWidget);expect(find.text('Review empty playlist creation'),findsOneWidget);expect(playlists().length,1);expect(tester.takeException(),isNull);
  });
}

// Actual serialized Hive writes run outside the widget fake clock.
class _IoEmptyService extends SpotifyImportDestinationService {
  Future<SpotifyEmptySourcePlaylistResult>? lastCreation;
  @override
  Future<SpotifyEmptySourcePlaylistResult> createEmptySourcePlaylist({required SpotifyImportDestinationSnapshot snapshot}) {
    final completed=Zone.root.run(() => Completer<SpotifyEmptySourcePlaylistResult>());
    Zone.root.run(()=>super.createEmptySourcePlaylist(snapshot:snapshot).then<void>(completed.complete,onError:(Object error,StackTrace stack)=>completed.completeError(error,stack)));
    return lastCreation=completed.future;
  }
}
class _IoSessionService extends SpotifyImportSessionService {
  Future<void>? lastSave;
  @override
  Future<void> saveNewImport(SpotifyImportPreview preview,{DateTime? importedAt}) {
    final completed=Zone.root.run(() => Completer<void>());
    Zone.root.run(()=>super.saveNewImport(preview,importedAt:importedAt).then<void>((_)=>completed.complete(),onError:(Object error,StackTrace stack)=>completed.completeError(error,stack)));
    return lastSave=completed.future;
  }
}