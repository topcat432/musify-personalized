import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_whole_source_readiness.dart';
import '../../tool/visual_review_harness.dart';
import '../support/spotify_empty_source_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const service = SpotifyImportDestinationService();
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('empty-source-');
    Hive.init(root.path); await initPriorityReviewHive(); resetPriorityReviewGlobals();
    await SpotifyEmptySourceFixture.seed();
  });
  tearDown(() async {await Hive.close();await root.delete(recursive:true);});
  Map<String,dynamic> metadata()=>Map<String,dynamic>.from(Hive.box('user').get('spotifyImportMetadata'));
  Future<void> putMetadata(Map<String,dynamic> value)=>Hive.box('user').put('spotifyImportMetadata',value);
  Object? copy(Object? value)=>jsonDecode(jsonEncode(value));
  List<Map> playlists()=>List<Map>.from(Hive.box('user').get('customPlaylists',defaultValue:[]));
  Future<SpotifyEmptySourcePlaylistResult> create({SpotifyImportDestinationService using=service}) async => using.createEmptySourcePlaylist(snapshot:await service.loadSourcePlaylistSnapshot(1));
  Future<void> reopen() async {await Hive.close();Hive.init(root.path);await initPriorityReviewHive();}

  test('pure completeness distinguishes empty membership from zero resolved songs',() async {
    await SpotifyEmptySourceFixture.seed(unsupported:true);
    final box=Hive.box('user');
    SpotifyWholeSourceReadiness inspect(int position)=>SpotifyWholeSourceReadiness.inspect(rawTracks:box.get('spotifyImportTracks'),rawResults:box.get('spotifyMatchResults'),metadata:metadata(),sourcePlaylistPosition:position);
    expect(inspect(1).verifiedEmpty,isTrue);expect(inspect(1).ready,isFalse);
    expect(inspect(2).verifiedEmpty,isFalse);expect(inspect(2).unsupported,1);
    await box.put('spotifyMatchResults',[]);
    expect(inspect(2).verifiedEmpty,isFalse);expect(inspect(2).pending,1);
    final changed=metadata()..remove('totalDataRows');await putMetadata(changed);
    expect(inspect(1).verifiedEmpty,isFalse);
  });
  test('empty-only named file saves source membership without automatically creating destinations',() async {
    final preview=SpotifyEmptySourceFixture.preview(song:false);
    expect(preview.tracks,isEmpty);expect(preview.totalDataRows,0);expect(preview.sourcePlaylists.single.members,isEmpty);
    await SpotifyEmptySourceFixture.seed(song:false);
    expect(playlists().length,1);
    final snapshot=await service.loadSourcePlaylistSnapshot(1);
    expect(snapshot.wholeSourceReadiness!.verifiedEmpty,isTrue);
    expect((await service.createEmptySourcePlaylist(snapshot:snapshot)).created,isTrue);
    expect(playlists().last['list'],isEmpty);
    await reopen();expect(playlists().last['list'],isEmpty);
  });
  test('empty creation is zero-song audited and does not advance successful recording baseline',() async {
    final before=metadata();final originalTracks=copy(Hive.box('user').get('spotifyImportTracks'));
    final result=await create();
    expect(result.created,isTrue);expect(result.trackingRecorded,isTrue);
    expect(playlists().length,2);expect(playlists().last['list'],isEmpty);
    expect(metadata()[importRoutingBaselineKey],before[importRoutingBaselineKey]);
    final audit=(metadata()['routingHistory'] as List).single as Map;
    expect(audit['action'],'create_empty_source_playlist');expect(audit['songTransfer'],isFalse);
    expect(audit['sourceItemCount'],0);expect(audit['selectedCount'],0);expect(audit['addedCount'],0);
    expect(audit.containsKey('resolvedRecordings'),isFalse);
    expect((await service.loadSnapshot()).newlyResolvedRecordingIds,{'owned-choice'});
    expect(Hive.box('user').get('spotifyImportTracks'),originalTracks);
    expect(Hive.box('user').get('likedSongs'),[{'ytid':'keep-owner'}]);
    await reopen();expect((await service.loadSnapshot()).newlyResolvedRecordingIds,{'owned-choice'});
  });
  test('legacy unknown recording baseline stays unknown after zero-song creation',() async {
    await putMetadata(metadata()..remove(importRoutingBaselineKey));
    expect((await service.loadSnapshot()).newlyResolvedBaselineKnown,isFalse);
    await create();await reopen();
    expect(metadata().containsKey(importRoutingBaselineKey),isFalse);
    expect((await service.loadSnapshot()).newlyResolvedBaselineKnown,isFalse);
  });
  test('retry reuses identity without another destination write',() async {
    var writes=0;
    final writer=SpotifyImportDestinationService(destinationWriter:(box,key,value) async {writes++;await box.put(key,value);});
    final first=await create(using:writer);final second=await create(using:writer);
    expect(second.created,isFalse);expect(second.destinationId,first.destinationId);expect(writes,1);
    expect(playlists().length,2);await reopen();expect((await create()).destinationId,first.destinationId);
  });
  test('stable source URI reuses destination across a fresh import without replaying songs',() async {
    final first=await create();final library=copy(playlists());
    await const SpotifyImportSessionService().saveNewImport(SpotifyEmptySourceFixture.preview(),importedAt:DateTime.utc(2026,10,15));
    final second=await create();expect(second.created,isFalse);expect(second.destinationId,first.destinationId);expect(playlists(),library);
    expect(Hive.box('user').get('spotifyMatchResults'),isEmpty);
  });
  test('URI-less source identity stays local to its saved session rather than guessing by name',() async {
    await SpotifyEmptySourceFixture.seed(uri:false);final first=await create();
    await const SpotifyImportSessionService().saveNewImport(SpotifyEmptySourceFixture.preview(uri:false),importedAt:DateTime.utc(2026,10,15));
    final second=await create();expect(second.created,isTrue);expect(second.destinationId,isNot(first.destinationId));expect(playlists().length,3);
  });
  test('rename folder move and intentional added songs survive exact retry',() async {
    final first=await create();final linked=Map<String,dynamic>.from(playlists().last);
    linked['title']='Owner renamed';linked['list']=[{'ytid':'owner-added'}];
    await Hive.box('user').put('customPlaylists',playlists().take(1).toList());
    final folders=[{'id':'owner-folder','title':'Owner folder','playlists':[linked],'ownerField':'keep'}];
    await Hive.box('user').put('playlistFolders',folders);
    final stored=copy(folders);await reopen();
    final result=await create();expect(result.created,isFalse);expect(result.destinationId,first.destinationId);expect(result.destinationTitle,'Owner renamed');
    expect(Hive.box('user').get('playlistFolders'),stored);expect(playlists().length,1);
  });
  test('removed completed destination is never recreated from stale history',() async {
    await create();await Hive.box('user').put('customPlaylists',playlists().take(1).toList());
    final before=copy(Hive.box('user').toMap());
    await expectLater(create(),throwsStateError);expect(Hive.box('user').toMap(),before);
    await reopen();await expectLater(create(),throwsStateError);expect(playlists().length,1);
  });
  test('ambiguous linked destinations reject without choosing by title',() async {
    await create();final duplicate=Map<String,dynamic>.from(playlists().last)..['ytid']='customId-other';
    await Hive.box('user').put('customPlaylists',[...playlists(),duplicate]);
    final before=copy(Hive.box('user').toMap());await expectLater(create(),throwsStateError);expect(Hive.box('user').toMap(),before);
  });
  test('nonempty unsupported or unmatched source cannot create an empty destination',() async {
    await SpotifyEmptySourceFixture.seed(unsupported:true);
    await Hive.box('user').put('spotifyMatchResults',[]);
    final before=copy(Hive.box('user').toMap());
    await expectLater(service.createEmptySourcePlaylist(snapshot:await service.loadSourcePlaylistSnapshot(2)),throwsStateError);
    expect(Hive.box('user').toMap(),before);
  });
  test('stale source name or session after preview rejects before writes',() async {
    final snapshot=await service.loadSourcePlaylistSnapshot(1);final changed=metadata();
    (changed['sourcePlaylists']['playlists'][0] as Map)['name']='Owner renamed source';await putMetadata(changed);
    final before=copy(Hive.box('user').toMap());await expectLater(service.createEmptySourcePlaylist(snapshot:snapshot),throwsStateError);expect(Hive.box('user').toMap(),before);
  });
  test('membership change during pending callback preserves newer source and baseline',() async {
    final baseline=copy(metadata()[importRoutingBaselineKey]);
    final writer=SpotifyImportDestinationService(metadataWriter:(box,value) async {
      await box.put('spotifyImportMetadata',value);
      if(value.containsKey(importRoutingPendingKey)) {
        final changed=metadata();final sources=changed['sourcePlaylists']['playlists'] as List;
        sources[0]['members']=copy(sources[1]['members']);changed['totalDataRows']=2;await putMetadata(changed);
      }
    });
    await expectLater(create(using:writer),throwsStateError);expect(playlists().length,1);
    expect(metadata()['sourcePlaylists']['playlists'][0]['members'],isNotEmpty);
    expect(metadata()[importRoutingBaselineKey],baseline);expect(metadata().containsKey(importRoutingPendingKey),isFalse);
  });
  for(final afterWrite in [false,true]) {
    test('pending metadata failure afterWrite=$afterWrite preserves original values',() async {
      final before=copy(Hive.box('user').toMap());
      final writer=SpotifyImportDestinationService(metadataWriter:(box,value) async {if(afterWrite) await box.put('spotifyImportMetadata',value);throw StateError('Owned pending failure');});
      await expectLater(create(using:writer),throwsStateError);expect(Hive.box('user').toMap(),before);
      await reopen();expect(Hive.box('user').toMap(),before);
    });
  }
  for(final present in [false,true]) {
    test('destination partial failure rolls back exact key presence=$present',() async {
      if(!present) await Hive.box('user').delete('customPlaylists');
      final before=copy(Hive.box('user').toMap());
      final writer=SpotifyImportDestinationService(destinationWriter:(box,key,value) async {await box.put(key,value);throw StateError('Owned destination failure');});
      await expectLater(create(using:writer),throwsStateError);expect(Hive.box('user').toMap(),before);
      await reopen();expect(Hive.box('user').toMap(),before);
      expect((await create()).created,isTrue);
    });
  }
  test('newer independent destination edit survives writer failure without compensation overwrite',() async {
    final newer=[{'ytid':'customId-newer','title':'Owner newer','source':'user-created','list':[{'ytid':'owner-song'}]}];
    final writer=SpotifyImportDestinationService(destinationWriter:(box,key,value) async {await box.put(key,value);await box.put(key,newer);throw StateError('Owned late failure');});
    await expectLater(create(using:writer),throwsStateError);expect(playlists(),newer);
    expect(metadata().containsKey(importRoutingPendingKey),isTrue);await reopen();
    await expectLater(create(),throwsStateError);expect(playlists(),newer);
  });
  test('mutable staged metadata cannot hide an independent owner edit from rollback',() async {
    final writer=SpotifyImportDestinationService(metadataWriter:(box,value) async {
      await box.put('spotifyImportMetadata',value);
      value['ownedIndependentMetadata']='keep';await box.put('spotifyImportMetadata',value);
      throw StateError('Owned metadata failure after independent mutation');
    });
    await expectLater(create(using:writer),throwsStateError);
    expect(metadata()['ownedIndependentMetadata'],'keep',reason:'Owner metadata mutation must survive staged rollback');
    expect(metadata().containsKey(importRoutingPendingKey),isTrue);expect(playlists().length,1);
    await reopen();expect(metadata()['ownedIndependentMetadata'],'keep');
  });
  test('mutable staged destination cannot hide owner rename from rollback; retry preserves it',() async {
    final writer=SpotifyImportDestinationService(destinationWriter:(box,key,value) async {
      await box.put(key,value);value.last['title']='Owner renamed during failure';await box.put(key,value);
      throw StateError('Owned destination failure after independent mutation');
    });
    await expectLater(create(using:writer),throwsStateError);
    expect(playlists().length,2,reason:'Owner destination mutation must survive staged rollback');
    expect(playlists().last['title'],'Owner renamed during failure');await reopen();
    expect((await create()).created,isFalse);expect(playlists().last['title'],'Owner renamed during failure');
  });
  test('audit failure retains actual creation and pending uncertainty; retry creates no duplicate',() async {
    var writes=0;
    final writer=SpotifyImportDestinationService(metadataWriter:(box,value) async {writes++;await box.put('spotifyImportMetadata',value);if(writes==2) throw StateError('Owned audit failure');});
    final baseline=copy(metadata()[importRoutingBaselineKey]);final result=await create(using:writer);
    expect(result.created,isTrue);expect(result.trackingRecorded,isFalse);expect(metadata().containsKey(importRoutingPendingKey),isTrue);
    await reopen();final retry=await create();expect(retry.created,isFalse);expect(retry.destinationId,result.destinationId);expect(playlists().length,2);
    expect(metadata()[importRoutingBaselineKey],baseline);expect(metadata().containsKey(importRoutingPendingKey),isFalse);
  });
  test('prior pending song transfer is retained and not resolved by zero-song action',() async {
    final pending={'action':'song_transfer','operationId':'owner-old'};await putMetadata(metadata()..[importRoutingPendingKey]=pending);
    final before=copy(Hive.box('user').toMap());await expectLater(create(),throwsStateError);expect(Hive.box('user').toMap(),before);
    expect((await service.loadSnapshot()).newlyResolvedBaselineKnown,isFalse);
  });
  test('source-linked destination appearing during pending checkpoint rejects duplicate creation',() async {
    final snapshot=await service.loadSourcePlaylistSnapshot(1);
    final owner={'ytid':'customId-owner-created','title':'Owner created','source':'user-created','importSourcePlaylistKey':snapshot.sourcePlaylistKey,'list':[{'ytid':'owner-added'}]};
    final writer=SpotifyImportDestinationService(metadataWriter:(box,value) async {await box.put('spotifyImportMetadata',value);if(value.containsKey(importRoutingPendingKey)) await box.put('customPlaylists',[...playlists(),owner]);});
    await expectLater(writer.createEmptySourcePlaylist(snapshot:snapshot),throwsStateError);
    expect(playlists().length,2);expect(playlists().last,owner);
  });
  test('silent pending write cannot permit destination mutation',() async {
    final before=copy(Hive.box('user').toMap());
    final writer=SpotifyImportDestinationService(metadataWriter:(_,__) async {});
    await expectLater(create(using:writer),throwsStateError);expect(Hive.box('user').toMap(),before);
  });
  test('silent final audit remains unverified and retry reuses durable identity',() async {
    var writes=0;final writer=SpotifyImportDestinationService(metadataWriter:(box,value) async {if(++writes!=2) await box.put('spotifyImportMetadata',value);});
    final result=await create(using:writer);expect(result.trackingRecorded,isFalse);expect(metadata().containsKey(importRoutingPendingKey),isTrue);
    await reopen();expect((await create()).destinationId,result.destinationId);expect(playlists().length,2);
  });
  test('destination removed during audit is not reported as completed creation or recreated',() async {
    var writes=0;final writer=SpotifyImportDestinationService(metadataWriter:(box,value) async {await box.put('spotifyImportMetadata',value);if(++writes==2) await box.put('customPlaylists',playlists().take(1).toList());});
    await expectLater(create(using:writer),throwsStateError);expect(playlists().length,1);expect(metadata().containsKey(importRoutingPendingKey),isTrue);
    await reopen();await expectLater(create(),throwsStateError);expect(playlists().length,1);
  });
  test('overlapping empty creators share the existing transfer ownership guard',() async {
    final entered=Completer<void>(),release=Completer<void>();var writes=0;
    final writer=SpotifyImportDestinationService(metadataWriter:(box,value) async {await box.put('spotifyImportMetadata',value);if(++writes==1){entered.complete();await release.future;}});
    final first=create(using:writer);await entered.future;
    await expectLater(create(),throwsStateError);release.complete();expect((await first).created,isTrue);expect(playlists().length,2);
  });
  test('saved backup reopens and independently restores empty destination and zero-song audit',() async {
    await create();final before=copy(Hive.box('user').toMap());
    await Hive.box('user').flush();await Hive.box('settings').flush();
    final bytes=await MusifyBackupService.createBundleBytesForTesting({
      'user':await File('${root.path}/user.hive').readAsBytes(),
      'settings':await File('${root.path}/settings.hive').readAsBytes(),
    });
    final saved=File('${root.path}/owned-empty.musifybackup');await saved.writeAsBytes(bytes,flush:true);
    final inspected=await MusifyBackupService.inspectBundleFileForTesting(saved);
    await Hive.close();final independent=Directory('${root.path}/independent');await independent.create();Hive.init(independent.path);
    await initPriorityReviewHive();await Hive.box('user').put('ownedWrongRestoreTarget',true);
    final restored=await MusifyBackupService.restoreValidatedBackup(inspected);expect(restored.success,isTrue);
    await Hive.close();Hive.init(independent.path);await initPriorityReviewHive();
    expect(Hive.box('user').toMap(),before);expect(playlists().last['list'],isEmpty);
    expect((await create()).created,isFalse);expect(playlists().length,2);
  });
}