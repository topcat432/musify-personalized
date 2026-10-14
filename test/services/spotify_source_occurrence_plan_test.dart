import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_source_occurrence_plan.dart';
import 'package:musify/services/spotify_source_playlist.dart';

void main() {
  String uri(int row)=>'spotify:track:${(row==1?'A':'B')*22}';
  List<SpotifySourcePlaylist> sources({List<int?> rows=const [1,2,1],List<String?>? stamps,bool stableSource=true,String name='Owned source'}) => [
    SpotifySourcePlaylist(position:1,name:name,spotifyUri:stableSource?'spotify:playlist:${'P'*22}':null,members:[
      for(final (index,row) in rows.indexed) SpotifyPlaylistMember(position:index+1,sourceRow:row,
        issue:row==null?'Unsupported':null,sourceMetadata:{if(row!=null)'uri':uri(row),
          if((stamps?[index]??(stamps==null?'2026-10-01T00:00:0${index+1}Z':null))!=null)
            'addedAt':stamps?[index]??'2026-10-01T00:00:0${index+1}Z',}),
    ]),
  ];
  final tracks=[for(final row in [1,2]) <String,dynamic>{'sourceRow':row,'spotifyTrackUri':uri(row)}];
  SpotifyImportDestinationSnapshot snapshot({String session='owned',String a='chosen-alternative',bool partial=false})=>SpotifyImportDestinationSnapshot(
    importSessionId:session,sourceName:'owned.json',resolvedSongs:[{'ytid':a},if(!partial){'ytid':'chosen-B'}],
    resolvedResultCount:partial?1:2,unresolvedCount:partial?1:0,customPlaylists:const [],
    sourceRowsReliable:true,recordingIdentitiesReliable:true,
    resolvedRecordings:[{'sourceRow':'1','recordingId':a},if(!partial){'sourceRow':'2','recordingId':'chosen-B'}],
  );
  SpotifySourceOccurrencePlan plan({List<SpotifySourcePlaylist>? source,SpotifyImportDestinationSnapshot? resolved,
    bool exists=false,List<SpotifyDestinationOccurrence> destination=const [],SpotifyOccurrenceBaseline? baseline,String target='target'}) =>
      SpotifySourceOccurrencePlan.preview(sources:source??sources(),position:1,tracks:tracks,snapshot:resolved??snapshot(),
        destinationId:target,targetExists:exists,destination:destination,baseline:baseline);
  SpotifyOccurrenceBaseline baseline(SpotifySourceOccurrencePlan plan,{bool verified=true,String target='target',String? key}) =>
      SpotifyOccurrenceBaseline(sourceKey:key??plan.sourceKey,destinationId:target,sourceFingerprint:plan.sourceFingerprint,verified:verified,entries:plan.occurrences);
  List<SpotifyDestinationOccurrence> owned(SpotifySourceOccurrencePlan plan)=>plan.occurrences.map((entry)=>SpotifyDestinationOccurrence(recordingId:entry.recordingId,occurrenceId:entry.id)).toList();

  test('pure new-destination proposal preserves every source slot and chosen alternative without mutating input',() {
    final source=sources();final before=jsonEncode(SpotifySourcePlaylistCodec.encode(source));
    final result=plan(source:source);
    expect(result.canPropose,isTrue);expect(result.requiresConfirmation,isTrue);
    expect(result.appends.map((row)=>row.recordingId),['chosen-alternative','chosen-B','chosen-alternative']);
    expect(result.occurrences.map((row)=>row.id).toSet().length,3);
    expect(result.occurrences.every((row)=>row.hasReusableAnchor),isTrue);
    expect(result.wouldMatchSourceOrder,isTrue);expect(jsonEncode(SpotifySourcePlaylistCodec.encode(source)),before);
    expect(()=>result.appends.clear(),throwsUnsupportedError);expect(()=>result.issues.clear(),throwsUnsupportedError);
  });
  test('verified unchanged retry proposes zero writes and exact occurrence order',() {
    final initial=plan();final result=plan(exists:true,destination:owned(initial),baseline:baseline(initial));
    expect(result.appends,isEmpty);expect(result.canPropose,isTrue);expect(result.wouldMatchSourceOrder,isTrue);
  });
  test('unique UTC anchors survive source reorder and a new import session',() {
    final original=plan();
    final result=plan(source:sources(rows:[2,1,1],stamps:['2026-10-01T00:00:02Z','2026-10-01T00:00:01Z','2026-10-01T00:00:03Z']),resolved:snapshot(session:'new-session'));
    expect(result.occurrences.map((row)=>row.id),[original.occurrences[1].id,original.occurrences[0].id,original.occurrences[2].id]);
  });
  test('manual additions and reordered destination are preserved while a new anchored slot is proposed at the end',() {
    final original=plan();final destination=[const SpotifyDestinationOccurrence(recordingId:'owner-added'),...owned(original).reversed];
    final before=destination.map((row)=>[row.recordingId,row.occurrenceId]).toList();
    final result=plan(source:sources(rows:[1,2,1,2]),exists:true,destination:destination,baseline:baseline(original));
    expect(result.canPropose,isTrue);expect(result.appends.single.recordingId,'chosen-B');
    expect(result.manualEntries,1);expect(result.wouldMatchSourceOrder,isFalse);
    expect(destination.map((row)=>[row.recordingId,row.occurrenceId]).toList(),before);
  });
  test('previously imported destination removal is retained rather than repaired on retry',() {
    final original=plan();final result=plan(exists:true,destination:owned(original).take(2).toList(),baseline:baseline(original));
    expect(result.canPropose,isTrue);expect(result.appends,isEmpty);
    expect(result.retainedRemovals,{original.occurrences.last.id});expect(result.wouldMatchSourceOrder,isFalse);
  });
  test('source recording choice change and destination recording edit both require review',() {
    final original=plan();
    final changed=plan(resolved:snapshot(a:'owner-new-choice'),exists:true,destination:owned(original),baseline:baseline(original));
    expect(changed.issues,contains(SpotifyOccurrencePlanIssue.sourceRecordingChoiceChanged));expect(changed.appends,isEmpty);
    final edited=owned(original);edited[0]=SpotifyDestinationOccurrence(recordingId:'owner-edited',occurrenceId:original.occurrences[0].id);
    expect(plan(exists:true,destination:edited,baseline:baseline(original)).issues,contains(SpotifyOccurrencePlanIssue.destinationRecordingEdited));
  });
  test('legacy counts and unverified ownership cannot infer slot identity from recording IDs',() {
    final original=plan();
    final unknown=plan(exists:true,destination:[const SpotifyDestinationOccurrence(recordingId:'chosen-alternative')]);
    expect(unknown.issues,contains(SpotifyOccurrencePlanIssue.unknownOwnership));expect(unknown.appends,isEmpty);
    expect(plan(exists:true,destination:owned(original),baseline:baseline(original,verified:false)).canPropose,isFalse);
  });
  test('missing or colliding stamps stay snapshot-scoped and changed snapshots cannot invent new repeats',() {
    final source=sources(stamps:[null,null,null]);final original=plan(source:source);
    expect(original.occurrences.every((row)=>!row.hasReusableAnchor),isTrue);
    expect(plan(source:source,exists:true,destination:owned(original),baseline:baseline(original)).appends,isEmpty);
    final changed=plan(source:sources(rows:[1,2,1,2],stamps:[null,null,null,null]),exists:true,destination:owned(original),baseline:baseline(original));
    expect(changed.issues,contains(SpotifyOccurrencePlanIssue.ambiguousIdentity));expect(changed.appends,isEmpty);
    final collision=plan(source:sources(stamps:['2026-10-01T00:00:01Z','2026-10-01T00:00:02Z','2026-10-01T00:00:01Z']));
    expect(collision.occurrences.where((row)=>!row.hasReusableAnchor).length,2);
  });
  test('retimestamped same source recording cannot masquerade as an additional occurrence',() {
    final original=plan();final changed=plan(source:sources(stamps:['2026-10-02T00:00:01Z','2026-10-01T00:00:02Z','2026-10-01T00:00:03Z']),exists:true,destination:owned(original),baseline:baseline(original));
    expect(changed.issues,contains(SpotifyOccurrencePlanIssue.ambiguousIdentity));expect(changed.appends,isEmpty);
  });
  test('invalid calendar stamps and URI-less sources never gain reusable occurrence anchors',() {
    expect(plan(source:sources(stamps:['2026-02-30T00:00:01Z',null,null])).occurrences.every((row)=>!row.hasReusableAnchor),isTrue);
    expect(plan(source:sources(stableSource:false)).occurrences.every((row)=>!row.hasReusableAnchor),isTrue);
  });
  test('manual recording collision unknown tags duplicate tags and wrong target refuse proposals',() {
    final original=plan();final ledger=baseline(original);
    final added=plan(source:sources(rows:[1,2,1,2]),exists:true,destination:[...owned(original),const SpotifyDestinationOccurrence(recordingId:'chosen-B')],baseline:ledger);
    expect(added.issues,contains(SpotifyOccurrencePlanIssue.manualRecordingCollision));expect(added.appends,isEmpty);
    expect(plan(exists:true,destination:[...owned(original),owned(original).first],baseline:ledger).issues,contains(SpotifyOccurrencePlanIssue.duplicateOwnership));
    expect(plan(exists:true,destination:[const SpotifyDestinationOccurrence(recordingId:'owner',occurrenceId:'unverified')],baseline:ledger).issues,contains(SpotifyOccurrencePlanIssue.unknownOccurrence));
    expect(plan(exists:true,destination:owned(original),baseline:ledger,target:'different-target').issues,contains(SpotifyOccurrencePlanIssue.wrongDestination));
    expect(plan(exists:false,baseline:ledger).issues,contains(SpotifyOccurrencePlanIssue.destinationRemoved));
  });
  test('incomplete sources and empty sources never become implicit recreation proposals',() {
    final incomplete=plan(source:sources(rows:[1,2,null]),resolved:snapshot(partial:true));
    expect(incomplete.unsupportedMembers,1);expect(incomplete.unresolvedMembers,1);expect(incomplete.appends,isEmpty);
    expect(incomplete.issues,contains(SpotifyOccurrencePlanIssue.sourceIncomplete));
    expect(plan(source:sources(rows:[])).issues,contains(SpotifyOccurrencePlanIssue.useExplicitEmptyAction));
  });
  test('oversize destination evidence fails closed before source work',() {
    expect(()=>plan(destination:List.filled(10001,const SpotifyDestinationOccurrence(recordingId:'owned'))),throwsStateError);
  });
}