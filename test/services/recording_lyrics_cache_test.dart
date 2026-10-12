import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/common_services.dart';

void main() {
  setUp(() {
    lastFetchedLyrics = null;
    lyrics.value = null;
  });

  test(
    'same recording reuses successful lyrics but alternate with same labels reloads',
    () async {
      var calls = 0;
      Future<String?> loader(String artist, String title) async =>
          'Owned ${++calls}';
      final first = await getSongLyrics(
        'Owned artist',
        'Same title',
        recordingId: 'A',
        loader: loader,
      );
      expect(
        await getSongLyrics(
          'Owned artist',
          'Same title',
          recordingId: 'A',
          loader: loader,
        ),
        first,
      );
      expect(
        await getSongLyrics(
          'Owned artist',
          'Same title',
          recordingId: 'B',
          loader: loader,
        ),
        'Owned 2',
      );
      expect(calls, 2);
    },
  );

  test(
    'late previous recording returns its own text without replacing current lyrics',
    () async {
      final previous = Completer<String?>();
      final old = getSongLyrics(
        'Owned artist',
        'Same title',
        recordingId: 'A',
        loader: (_, _) => previous.future,
      );
      expect(
        await getSongLyrics(
          'Owned artist',
          'Same title',
          recordingId: 'B',
          loader: (_, _) async => 'Owned B',
        ),
        'Owned B',
      );
      previous.complete('Owned A');
      expect(await old, 'Owned A');
      expect(lyrics.value, 'Owned B');
      expect(
        await getSongLyrics(
          'Owned artist',
          'Same title',
          recordingId: 'B',
          loader: (_, _) async => throw StateError('Must stay cached'),
        ),
        'Owned B',
      );
    },
  );

  test('same recording shares pending lookup and normalized result', () async {
    final pending = Completer<String?>();
    var calls = 0;
    Future<String?> loader(String artist, String title) {
      calls++;
      return pending.future;
    }

    final one = getSongLyrics(
      'Owned artist',
      'Same title',
      recordingId: 'A',
      loader: loader,
    );
    final two = getSongLyrics(
      'Owned artist',
      'Same title',
      recordingId: 'A',
      loader: loader,
    );
    pending.complete('Line one\n\nLine two');
    expect(await one, 'Line one\nLine two');
    expect(await two, 'Line one\nLine two');
    expect(calls, 1);
  });

  test('failed lookup can retry without publishing stale cache', () async {
    await expectLater(
      getSongLyrics(
        'Owned artist',
        'Same title',
        recordingId: 'A',
        loader: (_, _) async => throw StateError('Owned failure'),
      ),
      throwsStateError,
    );
    expect(lyrics.value, isNull);
    expect(
      await getSongLyrics(
        'Owned artist',
        'Same title',
        recordingId: 'A',
        loader: (_, _) async => 'Owned recovered',
      ),
      'Owned recovered',
    );
  });

  test('unavailable lyrics never reuse another recording text', () async {
    await getSongLyrics(
      'Owned artist',
      'Same title',
      recordingId: 'A',
      loader: (_, _) async => 'Owned A',
    );
    expect(
      await getSongLyrics(
        'Owned artist',
        'Same title',
        recordingId: 'B',
        loader: (_, _) async => null,
      ),
      isNull,
    );
    expect(lyrics.value, isNull);
    expect(lastFetchedLyrics, isNull);
  });
}
