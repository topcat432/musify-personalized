import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/utilities/queue_retry_utils.dart';

void main() {
  group('nextRetryQueueIndex', () {
    test('targets the song after the one that just failed', () {
      final result = nextRetryQueueIndex(
        failedIndex: 1,
        queueLength: 4,
        repeatMode: AudioServiceRepeatMode.none,
      );

      expect(result, 2);
    });

    test(
      'never returns the index that just failed, regardless of repeat mode',
      () {
        for (final mode in AudioServiceRepeatMode.values) {
          final result = nextRetryQueueIndex(
            failedIndex: 1,
            queueLength: 4,
            repeatMode: mode,
          );

          expect(
            result,
            isNot(1),
            reason: 'retry must not target the failed index under $mode',
          );
        }
      },
    );

    test('wraps to the first song when repeat-all is active at queue end', () {
      final result = nextRetryQueueIndex(
        failedIndex: 3,
        queueLength: 4,
        repeatMode: AudioServiceRepeatMode.all,
      );

      expect(result, 0);
    });

    test('gives up at the end of the queue without repeat-all', () {
      final result = nextRetryQueueIndex(
        failedIndex: 3,
        queueLength: 4,
        repeatMode: AudioServiceRepeatMode.none,
      );

      expect(result, isNull);
    });

    test('gives up on an empty queue', () {
      final result = nextRetryQueueIndex(
        failedIndex: 0,
        queueLength: 0,
        repeatMode: AudioServiceRepeatMode.all,
      );

      expect(result, isNull);
    });
  });
}
