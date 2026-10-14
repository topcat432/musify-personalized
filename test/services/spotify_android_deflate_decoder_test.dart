import 'dart:async';
import 'dart:typed_data';
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
}
