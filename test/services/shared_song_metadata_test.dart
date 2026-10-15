import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/shared_song_metadata.dart';

void main() {
  const id = 'fixture1234';
  Map song(String value) => {'ytid': value, 'title': 'Synthetic recording'};

  test(
    'valid exact-ID metadata is copied without calling the loader',
    () async {
      var calls = 0;
      final resolver = SharedSongMetadataResolver((id) async {
        calls++;
        throw StateError('Network metadata must not be requested');
      });
      final original = song(id)..['audioPath'] = '/owned/synthetic.wav';
      final result = await resolver.resolve(id, knownSongs: [original]);
      result['title'] = 'Changed copy';
      expect(calls, 0);
      expect(original['title'], 'Synthetic recording');
      expect(result['audioPath'], '/owned/synthetic.wav');
    },
  );

  test(
    'wrong-ID and partial legacy metadata cannot invent a recording',
    () async {
      var calls = 0;
      final resolver = SharedSongMetadataResolver((value) async {
        calls++;
        return song(value);
      });
      final result = await resolver.resolve(
        id,
        knownSongs: [
          song('different12'),
          {'ytid': id},
          {...song(id), 'duration': 'invalid'},
          {...song(id), 'isLive': 'invalid'},
          {...song(id), 'audioPath': 1},
        ],
      );
      expect(calls, 1);
      expect(result['ytid'], id);
      expect(result['title'], 'Synthetic recording');
    },
  );

  test(
    'concurrent resolution shares one lookup and returns separate maps',
    () async {
      var calls = 0;
      final pending = Completer<Map>();
      final resolver = SharedSongMetadataResolver((_) {
        calls++;
        return pending.future;
      });
      final first = resolver.resolve(id);
      final second = resolver.resolve(id);
      pending.complete(song(id));
      final results = await Future.wait([first, second]);
      results.first['title'] = 'Changed copy';
      expect(calls, 1);
      expect(results.last['title'], 'Synthetic recording');
    },
  );

  test(
    'wrong fetched identity is rejected and failure is not retained',
    () async {
      var calls = 0;
      final resolver = SharedSongMetadataResolver((value) async {
        calls++;
        return song(calls == 1 ? 'different12' : value);
      });
      await expectLater(resolver.resolve(id), throwsFormatException);
      expect((await resolver.resolve(id))['ytid'], id);
      expect(calls, 2);
    },
  );
}
