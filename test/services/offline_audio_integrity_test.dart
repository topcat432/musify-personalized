import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/offline_audio_integrity.dart';
import 'package:musify/services/offline_file_publication.dart';

void main() {
  late Directory root;
  late File audio;
  const payload = [1, 2, 3, 4];
  Map<String, dynamic> row({bool proof = true}) => {
    'ytid': 'synthetic',
    'audioPath': audio.path,
    if (proof) 'offlineAudioBytes': payload.length,
    if (proof) 'offlineAudioSha256': sha256.convert(payload).toString(),
  };
  Future<File> marker({int bytes = 4, String? digest}) async {
    final partial = '${audio.path}.download-123.part';
    return File('$partial.owner.json').writeAsString(
      jsonEncode({
        'schema': 1,
        'ytid': 'synthetic',
        'audioPath': audio.path,
        'partialPath': partial,
        'expectedBytes': bytes,
        'sha256': digest ?? sha256.convert(payload).toString(),
      }),
      flush: true,
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('offline-integrity-');
    audio = File('${root.path}/synthetic.m4a');
    await audio.writeAsBytes(payload, flush: true);
  });
  tearDown(() async {
    final resolved = await root.resolveSymbolicLinks();
    final temporary = await Directory.systemTemp.resolveSymbolicLinks();
    if (!resolved.startsWith(
      '$temporary${Platform.pathSeparator}offline-integrity-',
    )) {
      throw StateError('Outside owned synthetic root');
    }
    await root.delete(recursive: true);
  });
  test(
    'legacy positive payload remains usable with unknown integrity',
    () async {
      final check = await checkOfflineAudio(row(proof: false));
      expect(check.playable, isTrue);
      expect(check.hasProof, isFalse);
      expect(await audio.readAsBytes(), payload);
    },
  );
  for (final kind in ['missing', 'empty', 'short', 'tampered']) {
    for (final retained in [false, true]) {
      test(
        '$kind rejected with ${retained ? 'retained marker' : 'row proof'} without mutation',
        () async {
          File? proof;
          if (retained) proof = await marker();
          if (kind == 'missing') {
            await audio.delete();
          } else {
            await audio.writeAsBytes(
              kind == 'empty'
                  ? []
                  : kind == 'short'
                  ? [1]
                  : [9, 9, 9, 9],
              flush: true,
            );
          }
          final snapshot = await audio.exists()
              ? await audio.readAsBytes()
              : null;
          final check = await checkOfflineAudio(row(proof: !retained));
          expect(check.playable, isFalse);
          expect(
            check.state,
            {
              'missing': OfflineAudioState.missing,
              'empty': OfflineAudioState.empty,
              'short': OfflineAudioState.wrongLength,
              'tampered': OfflineAudioState.wrongChecksum,
            }[kind],
          );
          expect(
            await audio.exists() ? await audio.readAsBytes() : null,
            snapshot,
          );
          if (proof != null) expect(await proof.exists(), isTrue);
        },
      );
    }
  }
  test(
    'complete file with stale matching marker stays intact and playable',
    () async {
      final proof = await marker();
      final before = await proof.readAsBytes();
      expect((await checkOfflineAudio(row(proof: false))).playable, isTrue);
      expect(await proof.readAsBytes(), before);
      expect(await audio.readAsBytes(), payload);
    },
  );
  test('partial integrity metadata fails closed', () async {
    final entry = row()..remove('offlineAudioSha256');
    expect(
      (await checkOfflineAudio(entry)).state,
      OfflineAudioState.invalidProof,
    );
  });
  test('conflicting retained proofs fail closed', () async {
    final first = await marker();
    final data = jsonDecode(await first.readAsString()) as Map;
    data['partialPath'] = '${audio.path}.download-124.part';
    data['expectedBytes'] = 7;
    await File(
      '${data['partialPath']}.owner.json',
    ).writeAsString(jsonEncode(data));
    expect(
      (await checkOfflineAudio(row(proof: false))).state,
      OfflineAudioState.invalidProof,
    );
  });
  test('unrelated malformed marker does not invalidate legacy file', () async {
    await File('${audio.path}.download-123.part.owner.json').writeAsString('{');
    expect((await checkOfflineAudio(row(proof: false))).playable, isTrue);
  });
  test('shared path has independent row integrity and no mutation', () async {
    expect(
      (await checkOfflineAudio({...row(), 'ytid': 'alias'})).playable,
      isTrue,
    );
    expect(
      (await checkOfflineAudio({...row(), 'offlineAudioBytes': 9})).playable,
      isFalse,
    );
    expect(await audio.readAsBytes(), payload);
  });
  test('file-level flush uses a nontruncating handle', () async {
    await flushOfflineFile(audio);
    expect(await audio.readAsBytes(), payload);
  });
  test(
    'atomic publication retains source ownership and refuses collision',
    () async {
      final destination = File('${root.path}/published.m4a');
      publishOfflineFile(audio, destination);
      expect(
        await FileSystemEntity.identical(audio.path, destination.path),
        isTrue,
      );
      expect(
        () => publishOfflineFile(audio, destination),
        throwsA(isA<FileSystemException>()),
      );
      expect(await audio.readAsBytes(), payload);
      expect(await destination.readAsBytes(), payload);
    },
  );
}
