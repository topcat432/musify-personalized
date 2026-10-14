import 'dart:async';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_android_deflate_decoder.dart';
import 'package:musify/services/spotify_csv_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = SpotifyAndroidDeflateDecoder.channel;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final input = Uint8List.fromList([1, 2]);
  Map<String, Object> proof() => {
    'bytes': Uint8List.fromList([4, 5, 6]),
    'finished': true,
    'consumedBytes': 2,
  };
  final rejected = throwsA(isA<SpotifyImportException>());
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'bridge requires native finished/consumption proof and passes bounded payload',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'inflate');
        expect(call.arguments['bytes'], input);
        expect(call.arguments['size'], 3);
        return proof();
      });
      expect(
        (await SpotifyAndroidDeflateDecoder.decode(input, 3, null)).bytes,
        [4, 5, 6],
      );
    },
  );
  for (final corruption in [
    'unfinished',
    'unusedInput',
    'overconsumed',
    'size',
    'type',
    'missing',
  ]) {
    test('bridge rejects $corruption without partial output', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        final p = proof();
        switch (corruption) {
          case 'unfinished':
            p['finished'] = false;
            break;
          case 'unusedInput':
            p['consumedBytes'] = 1;
            break;
          case 'overconsumed':
            p['consumedBytes'] = 3;
            break;
          case 'size':
            p['bytes'] = Uint8List(4);
            break;
          case 'type':
            p['bytes'] = [4, 5, 6];
            break;
          case 'missing':
            return null;
        }
        return p;
      });
      await expectLater(
        SpotifyAndroidDeflateDecoder.decode(input, 3, null),
        rejected,
      );
    });
  }
  test('unavailable platform fails closed with direct-file guidance', () async {
    await expectLater(
      SpotifyAndroidDeflateDecoder.decode(input, 3, null),
      throwsA(
        isA<SpotifyImportException>().having(
          (e) => e.message,
          'guidance',
          contains('uncompressed (stored) ZIP'),
        ),
      ),
    );
  });
  test('declared/request input limits reject before invoking native', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      return proof();
    });
    await expectLater(
      SpotifyAndroidDeflateDecoder.decode(input, -1, null),
      rejected,
    );
    await expectLater(
      SpotifyAndroidDeflateDecoder.decode(input, 8 * 1024 * 1024 + 1, null),
      rejected,
    );
    await expectLater(
      SpotifyAndroidDeflateDecoder.decode(
        Uint8List(8 * 1024 * 1024 + 1),
        1,
        null,
      ),
      rejected,
    );
    expect(calls, 0);
  });
  test('busy native worker is a retryable rejection', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'ZIP_BUSY');
    });
    await expectLater(
      SpotifyAndroidDeflateDecoder.decode(input, 3, null),
      rejected,
    );
  });
  test(
    'cancellation targets its request and late success stays rejected',
    () async {
      final pending = Completer<Map<String, Object>>();
      final cancel = Completer<void>();
      String? id;
      String? cancelledId;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cancel') {
          cancelledId = call.arguments['id'];
          return null;
        }
        id = call.arguments['id'];
        return pending.future;
      });
      final result = SpotifyAndroidDeflateDecoder.decode(
        input,
        3,
        cancel.future,
      );
      final expected = expectLater(result, rejected);
      await Future<void>.delayed(Duration.zero);
      cancel.complete();
      await Future<void>.delayed(Duration.zero);
      pending.complete(proof());
      await expected;
      expect(cancelledId, id);
    },
  );
  test('completed old request cannot cancel the successor', () async {
    final oldCancel = Completer<void>();
    final pending = Completer<Map<String, Object>>();
    final ids = <String>[];
    var cancels = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'cancel') {
        cancels++;
        return null;
      }
      ids.add(call.arguments['id']);
      return ids.length == 1 ? proof() : pending.future;
    });
    await SpotifyAndroidDeflateDecoder.decode(input, 3, oldCancel.future);
    final next = SpotifyAndroidDeflateDecoder.decode(input, 3, null);
    oldCancel.complete();
    await Future<void>.delayed(Duration.zero);
    pending.complete(proof());
    await next;
    expect(cancels, 0);
    expect(ids.toSet().length, 2);
  });
  test(
    'missing reply times out at 20 seconds despite stalled cancel acknowledgment',
    () {
      fakeAsync((clock) {
        final pending = Completer<Map<String, Object>>();
        final acknowledgment = Completer<void>();
        final cancelledIds = <String>[];
        String? oldId;
        var ended = false;
        Object? error;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancel') {
            cancelledIds.add(call.arguments['id']);
            await acknowledgment.future;
            return null;
          }
          oldId = call.arguments['id'];
          return pending.future;
        });
        SpotifyAndroidDeflateDecoder.decode(input, 3, null).then<void>(
          (_) => ended = true,
          onError: (Object e) {
            ended = true;
            error = e;
          },
        );
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 19));
        expect(ended, isFalse);
        clock.elapse(const Duration(seconds: 1));
        clock.flushMicrotasks();
        expect(ended, isTrue);
        expect(error, isA<SpotifyImportException>());
        expect(cancelledIds, [oldId]);
        clock.elapse(const Duration(seconds: 2));
        clock.flushMicrotasks();
        pending.complete(proof());
        acknowledgment.complete();
        clock.flushMicrotasks();
        expect(cancelledIds, [oldId]);
      });
    },
  );
  test(
    'disposal cancellation settles without waiting for platform reply or acknowledgment',
    () {
      fakeAsync((clock) {
        final pending = Completer<Map<String, Object>>();
        final acknowledgment = Completer<void>();
        final disposed = Completer<void>();
        var ended = false;
        Object? error;
        var cancellations = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancel') {
            cancellations++;
            await acknowledgment.future;
            return null;
          }
          return pending.future;
        });
        SpotifyAndroidDeflateDecoder.decode(
          input,
          3,
          disposed.future,
        ).then<void>(
          (_) => ended = true,
          onError: (Object e) {
            ended = true;
            error = e;
          },
        );
        clock.flushMicrotasks();
        disposed.complete();
        clock.flushMicrotasks();
        expect(ended, isTrue);
        expect(error, isA<SpotifyImportException>());
        expect(cancellations, 1);
        clock.elapse(const Duration(seconds: 2));
        clock.flushMicrotasks();
        pending.complete(proof());
        acknowledgment.complete();
        clock.flushMicrotasks();
        expect(cancellations, 1);
      });
    },
  );
  test(
    'timeout ownership ends before a successor and ignores delayed acknowledgments and errors',
    () {
      fakeAsync((clock) {
        final oldReply = Completer<Map<String, Object>>();
        final oldAck = Completer<void>();
        final oldCancel = Completer<void>();
        final ids = <String>[];
        final cancellations = <String>[];
        Object? oldError;
        var nextSucceeded = false;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancel') {
            cancellations.add(call.arguments['id']);
            await oldAck.future;
            return null;
          }
          ids.add(call.arguments['id']);
          return ids.length == 1 ? oldReply.future : proof();
        });
        SpotifyAndroidDeflateDecoder.decode(
          input,
          3,
          oldCancel.future,
        ).then<void>(
          (_) => fail('Expired reply accepted'),
          onError: (Object error) {
            oldError = error;
          },
        );
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 20));
        clock.flushMicrotasks();
        expect(oldError, isA<SpotifyImportException>());
        SpotifyAndroidDeflateDecoder.decode(
          input,
          3,
          null,
        ).then<void>((_) => nextSucceeded = true);
        clock.flushMicrotasks();
        expect(nextSucceeded, isTrue);
        expect(ids.toSet().length, 2);
        clock.elapse(const Duration(seconds: 2));
        oldReply.completeError(PlatformException(code: 'OLD_ERROR'));
        oldAck.complete();
        oldCancel.complete();
        clock.flushMicrotasks();
        expect(cancellations, [ids.first]);
        expect(nextSucceeded, isTrue);
        expect(clock.pendingTimers, isEmpty);
      });
    },
  );
}
