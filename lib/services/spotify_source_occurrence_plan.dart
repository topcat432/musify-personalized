import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import 'package:musify/services/spotify_source_playlist_projection.dart';

/// Read-only experimental facts. No persistence fields or playback IDs are added.
class SpotifySourceOccurrence {
  const SpotifySourceOccurrence({required this.id, required this.recordingId, required this.sourceRecordingUri,
    required this.position, required this.sourceRow, required this.hasReusableAnchor});
  final String id, recordingId, sourceRecordingUri;
  final int position, sourceRow;
  final bool hasReusableAnchor;
}

class SpotifyDestinationOccurrence {
  const SpotifyDestinationOccurrence({required this.recordingId, this.occurrenceId});
  final String recordingId;
  final String? occurrenceId;
}

/// A future verified ownership journal, never inferred from legacy song counts.
/// This type deliberately has no Hive/JSON adapter or storage-key convention.
class SpotifyOccurrenceBaseline {
  SpotifyOccurrenceBaseline({required this.sourceKey, required this.destinationId,
    required this.sourceFingerprint, required this.verified,
    required List<SpotifySourceOccurrence> entries}) : entries=List.unmodifiable(entries);
  final String sourceKey, destinationId, sourceFingerprint;
  final bool verified;
  final List<SpotifySourceOccurrence> entries;
}

enum SpotifyOccurrencePlanIssue {
  sourceIncomplete, useExplicitEmptyAction, unknownOwnership, wrongDestination,
  wrongSource, destinationRemoved, duplicateOwnership, unknownOccurrence,
  destinationRecordingEdited, sourceRecordingChoiceChanged, ambiguousIdentity,
  manualRecordingCollision, destinationCapacityExceeded,
}

/// Proposals only: append-only on verified existing ownership, exact source order
/// for a new destination. Existing order, removals and manual entries are retained.
class SpotifySourceOccurrencePlan {
  SpotifySourceOccurrencePlan._({required this.sourceKey, required this.sourceFingerprint,
    required List<SpotifySourceOccurrence> occurrences,
    required List<SpotifySourceOccurrence> appends,
    required Set<SpotifyOccurrencePlanIssue> issues,
    required Set<String> retainedRemovals,
    required this.manualEntries, required this.unsupportedMembers,
    required this.unresolvedMembers, required this.wouldMatchSourceOrder})
    : occurrences=List.unmodifiable(occurrences), appends=List.unmodifiable(appends),
      issues=Set.unmodifiable(issues), retainedRemovals=Set.unmodifiable(retainedRemovals);
  final String sourceKey, sourceFingerprint;
  final List<SpotifySourceOccurrence> occurrences, appends;
  final Set<SpotifyOccurrencePlanIssue> issues;
  final Set<String> retainedRemovals;
  final int manualEntries, unsupportedMembers, unresolvedMembers;
  final bool wouldMatchSourceOrder;
  bool get canPropose => issues.isEmpty;
  bool get requiresConfirmation => true;

  static SpotifySourceOccurrencePlan preview({
    required List<SpotifySourcePlaylist> sources, required int position,
    required List<Map<String,dynamic>> tracks,
    required SpotifyImportDestinationSnapshot snapshot,
    required String destinationId, required bool targetExists,
    required List<SpotifyDestinationOccurrence> destination,
    SpotifyOccurrenceBaseline? baseline,
  }) {
    void require(bool valid) {if(!valid) throw StateError('Occurrence ownership cannot be verified. No source or destination was changed.');}
    require(destinationId.isNotEmpty && destinationId.length<=2048 &&
        destination.length<=10000 && snapshot.importSessionId.length<=2048 &&
        snapshot.resolvedRecordings.length<=10000 && snapshot.resolvedSongs.length<=10000 &&
        (baseline==null || baseline.entries.length<=10000));
    require(snapshot.recordingIdentitiesReliable);
    final projected=SpotifySourcePlaylistProjection.project(sources:sources,position:position,tracks:tracks,snapshot:snapshot);
    final issues=<SpotifyOccurrencePlanIssue>{};
    if(projected.unsupportedMembers>0 || projected.pendingMembers>0) issues.add(SpotifyOccurrencePlanIssue.sourceIncomplete);
    if(projected.source.members.isEmpty) issues.add(SpotifyOccurrencePlanIssue.useExplicitEmptyAction);
    final resolved=<int,String>{for(final row in snapshot.resolvedRecordings) int.parse(row['sourceRow']!):row['recordingId']!};
    final stampCounts=<String,int>{};
    for(final member in projected.source.members) {
      final stamp=_utcStamp(member.sourceMetadata['addedAt']);
      if(member.sourceRow==null || stamp==null) continue;
      final key=jsonEncode([member.sourceMetadata['uri'],stamp]);stampCounts[key]=(stampCounts[key]??0)+1;
    }
    final occurrences=<SpotifySourceOccurrence>[];
    for(final member in projected.source.members) {
      final recording=resolved[member.sourceRow];if(recording==null) continue;
      require(recording.isNotEmpty && recording.length<=2048);
      final stamp=_utcStamp(member.sourceMetadata['addedAt']);
      final stampKey=jsonEncode([member.sourceMetadata['uri'],stamp]);
      final stable=projected.source.spotifyUri!=null && stamp!=null && stampCounts[stampKey]==1;
      final identity=stable
          ? ['stable-v1',projected.scopeKey,member.sourceMetadata['uri'],stamp]
          : ['snapshot-v1',projected.scopeKey,projected.fingerprint,member.position];
      occurrences.add(SpotifySourceOccurrence(id:sha256.convert(utf8.encode(jsonEncode(identity))).toString(),
          recordingId:recording,sourceRecordingUri:member.sourceMetadata['uri']!,position:member.position,sourceRow:member.sourceRow!,hasReusableAnchor:stable));
    }
    final prior=<String,SpotifySourceOccurrence>{};
    if(baseline!=null) {
      require(baseline.sourceKey.isNotEmpty && baseline.sourceKey.length<=4096 && baseline.destinationId.length<=2048 && baseline.sourceFingerprint.length<=128);
      if(!baseline.verified) issues.add(SpotifyOccurrencePlanIssue.unknownOwnership);
      if(baseline.sourceKey!=projected.scopeKey) issues.add(SpotifyOccurrencePlanIssue.wrongSource);
      if(baseline.destinationId!=destinationId) issues.add(SpotifyOccurrencePlanIssue.wrongDestination);
      for(final entry in baseline.entries) {
        require(entry.id.isNotEmpty && entry.id.length<=2048 && entry.recordingId.isNotEmpty && entry.recordingId.length<=2048 && entry.sourceRecordingUri.length<=128);
        if(prior.containsKey(entry.id)) issues.add(SpotifyOccurrencePlanIssue.duplicateOwnership);
        prior[entry.id]=entry;
      }
    }
    final actual=<String,SpotifyDestinationOccurrence>{};
    final manual=<SpotifyDestinationOccurrence>[];
    for(final entry in destination) {
      require(entry.recordingId.isNotEmpty && entry.recordingId.length<=2048);
      final id=entry.occurrenceId;
      if(id==null) {manual.add(entry);continue;}
      require(id.isNotEmpty && id.length<=2048);
      if(actual.containsKey(id)) issues.add(SpotifyOccurrencePlanIssue.duplicateOwnership);
      actual[id]=entry;
      if(!prior.containsKey(id)) issues.add(SpotifyOccurrencePlanIssue.unknownOccurrence);
      else if(prior[id]!.recordingId!=entry.recordingId) issues.add(SpotifyOccurrencePlanIssue.destinationRecordingEdited);
    }
    final removed=prior.keys.where((id)=>!actual.containsKey(id)).toSet();
    final proposed=<SpotifySourceOccurrence>[];
    if(!targetExists) {
      if(destination.isNotEmpty || baseline!=null) issues.add(SpotifyOccurrencePlanIssue.destinationRemoved);
      proposed.addAll(occurrences);
    } else if(baseline==null || !baseline.verified) {
      issues.add(SpotifyOccurrencePlanIssue.unknownOwnership);
    } else {
      final changedSnapshot=baseline.sourceFingerprint!=projected.fingerprint;
      if(changedSnapshot && (occurrences.any((entry)=>!entry.hasReusableAnchor) || baseline.entries.any((entry)=>!entry.hasReusableAnchor))) {
        issues.add(SpotifyOccurrencePlanIssue.ambiguousIdentity);
      }
      final desiredIds=occurrences.map((entry)=>entry.id).toSet();
      final removedSourceUris=baseline.entries.where((entry)=>!desiredIds.contains(entry.id)).map((entry)=>entry.sourceRecordingUri).toSet();
      final manualRecordingIds=manual.map((entry)=>entry.recordingId).toSet();
      for(final entry in occurrences) {
        final old=prior[entry.id];
        if(old!=null) {
          if(old.recordingId!=entry.recordingId) issues.add(SpotifyOccurrencePlanIssue.sourceRecordingChoiceChanged);
          // A missing previously owned occurrence is an intentional removal.
          continue;
        }
        if(removedSourceUris.contains(entry.sourceRecordingUri)) issues.add(SpotifyOccurrencePlanIssue.ambiguousIdentity);
        if(changedSnapshot && !entry.hasReusableAnchor) issues.add(SpotifyOccurrencePlanIssue.ambiguousIdentity);
        if(manualRecordingIds.contains(entry.recordingId)) issues.add(SpotifyOccurrencePlanIssue.manualRecordingCollision);
        proposed.add(entry);
      }
    }
    if(destination.length+proposed.length>10000) issues.add(SpotifyOccurrencePlanIssue.destinationCapacityExceeded);
    final safe=issues.isEmpty?proposed:<SpotifySourceOccurrence>[];
    final futureIds=<String?>[...destination.map((entry)=>entry.occurrenceId),...safe.map((entry)=>entry.id)];
    final exact=issues.isEmpty && futureIds.length==occurrences.length &&
        Iterable<int>.generate(futureIds.length).every((index)=>futureIds[index]==occurrences[index].id);
    return SpotifySourceOccurrencePlan._(sourceKey:projected.scopeKey,sourceFingerprint:projected.fingerprint,
        occurrences:occurrences,appends:safe,issues:issues,retainedRemovals:removed,
        manualEntries:manual.length,unsupportedMembers:projected.unsupportedMembers,
        unresolvedMembers:projected.pendingMembers,wouldMatchSourceOrder:exact);
  }

  static String? _utcStamp(String? value) {
    if(value==null) return null;
    final match=RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?Z$').firstMatch(value);
    if(match==null) return null;
    final parsed=DateTime.tryParse(value);if(parsed==null) return null;
    final parts=[parsed.year,parsed.month,parsed.day,parsed.hour,parsed.minute,parsed.second];
    for(var index=0;index<parts.length;index++) {if(parts[index]!=int.parse(match.group(index+1)!)) return null;}
    return parsed.toUtc().toIso8601String();
  }
}