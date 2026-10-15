import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_playlist_copy_proof.dart';

void main() {
  const ids = ['selected-alternative', 'selected-B', 'selected-alternative'];
  SpotifyPlaylistCopyProof proof() => SpotifyPlaylistCopyProof.create(
    operationId: 'operation', destinationId: 'customId-copy', sessionId: 'session',
    sourceKey: 'spotify:playlist:${'P' * 22}', sourceFingerprint: 'a' * 64,
    recordingIds: ids,
  );
  Map<String, dynamic> target() => {'ytid': 'customId-copy', 'source': 'user-created',
    'title': 'Synthetic', 'list': [for (final id in ids) {'ytid': id}],
    SpotifyPlaylistCopyProof.markerKey: proof().encode()};
  SpotifyPlaylistCopyRecovery classify({List<Map>? targets, bool completed = false,
    String session = 'session', String? source, String? fingerprint, List<String> selected = ids}) =>
      classifySpotifyPlaylistCopy(proof: proof(), completed: completed,
        destinations: targets ?? [target()], sessionId: session,
        sourceKey: source ?? proof().sourceKey, sourceFingerprint: fingerprint ?? 'a' * 64,
        recordingFingerprint: SpotifyPlaylistCopyProof.fingerprint(selected));

  test('version1 round trip has distinct slot/unique counts and detached encoding', () {
    final value = proof(); final encoded = value.encode();
    expect(value.slotCount, 3); expect(value.uniqueRecordingCount, 2);
    expect(SpotifyPlaylistCopyProof.decode(jsonDecode(jsonEncode(encoded))).matches(value), isTrue);
    encoded['destinationId'] = 'owner-edit'; expect(value.destinationId, 'customId-copy');
    expect(SpotifyPlaylistCopyProof.fingerprint(ids), isNot(SpotifyPlaylistCopyProof.fingerprint(ids.reversed.toList().sublist(1))));
  });
  for (final field in ['version', 'operationId', 'destinationId', 'sessionId', 'sourceKey',
    'sourceFingerprint', 'recordingFingerprint', 'slotCount', 'uniqueRecordingCount']) {
    test('missing $field refuses without changing partial evidence', () {
      final raw = proof().encode()..remove(field); final before = jsonEncode(raw);
      expect(() => SpotifyPlaylistCopyProof.decode(raw), throwsFormatException);
      expect(jsonEncode(raw), before);
    });
  }
  for (final version in [0, 2, 1.0, '1', null]) {
    test('legacy/future/malformed version $version is not adopted', () {
      final raw = proof().encode()..['version'] = version;
      expect(() => SpotifyPlaylistCopyProof.decode(raw), throwsFormatException);
    });
  }
  for (final change in [
    {'slotCount': 0}, {'slotCount': 10001}, {'slotCount': 3.0},
    {'uniqueRecordingCount': 0}, {'uniqueRecordingCount': 4},
    {'operationId': ''}, {'destinationId': 'x' * 2049}, {'sessionId': ' bad '},
    {'sourceKey': 'x' * 4097}, {'sourceFingerprint': 'not-a-hash'},
    {'recordingFingerprint': 'A' * 64}, {'futureField': true},
  ]) {
    test('invalid descriptor $change remains unknown', () {
      expect(() => SpotifyPlaylistCopyProof.decode({...proof().encode(), ...change}), throwsFormatException);
    });
  }
  test('bounded recording fingerprint preserves order, alternatives and repeats', () {
    expect(SpotifyPlaylistCopyProof.fingerprint(ids), isNot(SpotifyPlaylistCopyProof.fingerprint([ids[0], ids[0], ids[1]])));
    for (final bad in [<String>[], [''], ['line\nbreak'], List.filled(10001, 'id')]) {
      expect(() => SpotifyPlaylistCopyProof.fingerprint(bad), throwsFormatException);
    }
    expect(SpotifyPlaylistCopyProof.fingerprint(List.filled(10000, 'id')), hasLength(64));
  });
  test('pending exact source/marker/slots allows audit only; completed is no-op', () {
    expect(classify(), SpotifyPlaylistCopyRecovery.recoverAuditOnly);
    expect(classify(completed: true), SpotifyPlaylistCopyRecovery.completedNoOp);
  });
  test('missing target never authorizes recreation before or after completion', () {
    for (final completed in [false, true]) expect(classify(targets: [], completed: completed), SpotifyPlaylistCopyRecovery.targetMissing);
  });
  test('legacy equal songs/count/name without marker remain unknown', () {
    final legacy = target()..remove(SpotifyPlaylistCopyProof.markerKey);
    expect(classify(targets: [legacy]), SpotifyPlaylistCopyRecovery.unknownOwnership);
  });
  test('null, partial, future and mismatched marker proof is retained/refused', () {
    for (final marker in [null, {}, {...proof().encode(), 'version': 2}]) {
      final value = target()..[SpotifyPlaylistCopyProof.markerKey] = marker;
      final before = jsonEncode(value); expect(classify(targets: [value]), SpotifyPlaylistCopyRecovery.invalidProof);
      expect(jsonEncode(value), before);
    }
    final other = target()..[SpotifyPlaylistCopyProof.markerKey] = {...proof().encode(), 'operationId': 'other'};
    expect(classify(targets: [other]), SpotifyPlaylistCopyRecovery.ambiguousOwnership);
  });
  test('duplicate IDs and copied operation markers cannot establish ownership', () {
    expect(classify(targets: [target(), target()]), SpotifyPlaylistCopyRecovery.ambiguousOwnership);
    final copied = target()..['ytid'] = 'customId-copied';
    expect(classify(targets: [target(), copied]), SpotifyPlaylistCopyRecovery.ambiguousOwnership);
    expect(classify(targets: [copied]), SpotifyPlaylistCopyRecovery.ambiguousOwnership);
    final wrongKind = target()..['source'] = 'youtube';
    expect(classify(targets: [wrongKind]), SpotifyPlaylistCopyRecovery.ambiguousOwnership);
  });
  test('source/session/selected-choice changes cannot complete a pending audit', () {
    expect(classify(session: 'new'), SpotifyPlaylistCopyRecovery.sourceChanged);
    expect(classify(source: 'other'), SpotifyPlaylistCopyRecovery.sourceChanged);
    expect(classify(fingerprint: 'b' * 64), SpotifyPlaylistCopyRecovery.sourceChanged);
    expect(classify(selected: ['owner-changed-choice', 'selected-B', 'selected-alternative']), SpotifyPlaylistCopyRecovery.sourceChanged);
  });
  test('pending reordered/removed/added slots stay saved but unverified', () {
    for (final list in [[], [{'ytid': 'selected-alternative'}],
      [for (final id in ['selected-alternative', 'selected-alternative', 'selected-B']) {'ytid': id}],
      [for (final id in [...ids, 'manual']) {'ytid': id}]]) {
      final value = target()..['list'] = list; final before = jsonEncode(value);
      expect(classify(targets: [value]), SpotifyPlaylistCopyRecovery.editedPendingDestination);
      expect(jsonEncode(value), before);
      expect(classify(targets: [value], completed: true), SpotifyPlaylistCopyRecovery.completedNoOp);
    }
  });
  test('completed retry preserves names/location metadata/manual song values unchanged', () {
    final value = target()..['title'] = 'Owner renamed'..['folder'] = 'owner-folder'
      ..['list'] = [{'ytid': 'manual', 'title': 'Owner edit'}];
    final before = jsonEncode(value); expect(classify(targets: [value], completed: true), SpotifyPlaylistCopyRecovery.completedNoOp);
    expect(jsonEncode(value), before);
  });
  test('unrelated markers are not adopted, and oversized evidence refuses', () {
    final unrelated = target()..['ytid'] = 'other'..[SpotifyPlaylistCopyProof.markerKey] = null;
    expect(classify(targets: [unrelated, target()]), SpotifyPlaylistCopyRecovery.recoverAuditOnly);
    expect(classify(targets: List.generate(10001, (_) => target())), SpotifyPlaylistCopyRecovery.invalidProof);
  });
}
