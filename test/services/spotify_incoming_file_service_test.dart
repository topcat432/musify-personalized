import 'dart:async';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_incoming_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('owned-incoming-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Map<String, dynamic> file(String id) => {
    'id': id,
    'uri': 'content://owned/$id',
    'name': '$id.csv',
    'size': null,
    'readGrantVerified': true,
  };
  late SpotifyIncomingFileService service;
  late List<Map<String, dynamic>> catalog;
  late List<MethodCall> calls;
  Map<String, dynamic>? nativeActive;
  setUp(() {
    service = SpotifyIncomingFileService(channel: channel);
    catalog = [file('a')];
    calls = [];
    nativeActive = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'list') return {'files': catalog, 'notice': null};
      if (call.method == 'read') {
        final id = call.arguments['id'];
        final index = catalog.indexWhere((file) => file['id'] == id);
        if (nativeActive?['id'] != id) {
          if (nativeActive != null || index < 0) throw PlatformException(code: 'INCOMING_BUSY');
          nativeActive = catalog.removeAt(index);
        }
        return Uint8List.fromList([1, 2, 3]);
      }
      if (call.method == 'finish') {
        final id = call.arguments['id'];
        if (nativeActive?['id'] == id) nativeActive = null;
        catalog.removeWhere((file) => file['id'] == id);
      }
      if (call.method == 'dismiss') catalog.removeWhere((file) => file['id'] == call.arguments['id']);
      return null;
    });
  });
  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'cold/warm catalog reconciliation preserves order; duplicate refresh never reads',
    () async {
      await service.start();
      expect(service.inbox.pending.map((f) => f.id), ['a']);
      catalog.add(file('b'));
      await service.refresh();
      await service.refresh();
      expect(service.inbox.pending.map((f) => f.id), ['a', 'b']);
      expect(calls.where((c) => c.method == 'read'), isEmpty);
      final lease = service.inbox.begin('a');
      expect(await service.openStream(lease.file).first, [1, 2, 3]);
      expect(calls.singleWhere((c) => c.method == 'read').arguments['id'], 'a');
      await service.finish(lease);
      expect(service.inbox.pending.single.id, 'b');
    },
  );
  test(
    'malformed grant duplicate IDs and identity changes preserve prior catalog',
    () async {
      await service.start();
      for (final malformed in [
        [
          file('a'),
          {...file('b'), 'readGrantVerified': false},
        ],
        [file('b'), file('b')],
        [
          {...file('a'), 'uri': 'content://owned/changed'},
        ],
        [
          {...file('a'), 'size': 1.5},
        ],
      ]) {
        catalog = malformed;
        await service.refresh();
        expect(service.inbox.pending.single.id, 'a');
        expect(
          service.inbox.pending.single.uri.toString(),
          'content://owned/a',
        );
        expect(service.notice, isNotNull);
      }
    },
  );
  test('stale finish cannot cancel the successor native request', () async {
    await service.start();
    final old = service.inbox.begin('a');
    await service.finish(old);
    catalog.add(file('b'));
    await service.refresh();
    final current = service.inbox.begin('b');
    final before = calls.length;
    await service.finish(old);
    expect(calls.length, before);
    expect(service.inbox.active!.id, 'b');
    expect(await service.openStream(current.file).first, [1, 2, 3]);
    await service.finish(current);
  });
  test('cancel settles missing reply and observes its late error', () async {
    final pending = Completer<Object>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'list') return {'files': catalog, 'notice': null};
      if (call.method == 'read') return pending.future;
      return null;
    });
    await service.start();
    final lease = service.inbox.begin('a');
    final result = service.openStream(lease.file).first;
    final assertion = expectLater(
      result,
      throwsA(isA<SpotifyImportException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await service.finish(lease);
    await assertion;
    pending.completeError(StateError('late native error'));
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c.method == 'cancel').length, 1);
  });
  test(
    'missing reply deadline settles even if cancellation acknowledgment stalls',
    () {
      fakeAsync((clock) {
        final pending = Completer<Object>();
        final ack = Completer<void>();
        var rejected = false;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'list') return {'files': catalog, 'notice': null};
          if (call.method == 'read') return pending.future;
          if (call.method == 'cancel') {
            await ack.future;
            return null;
          }
          return null;
        });
        service.start();
        clock.flushMicrotasks();
        final lease = service.inbox.begin('a');
        service
            .openStream(lease.file)
            .first
            .then<void>(
              (_) => fail('Late success was accepted'),
              onError: (Object error) {
                rejected = error is SpotifyImportException;
              },
            );
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 21));
        clock.flushMicrotasks();
        expect(rejected, isTrue);
        expect(calls.where((c) => c.method == 'cancel').length, 1);
        pending.complete(Uint8List.fromList([1]));
        clock.flushMicrotasks();
      });
    },
  );
  test('malformed and oversized native replies never publish bytes', () async {
    await service.start();
    final lease = service.inbox.begin('a');
    for (final reply in [
      null,
      [1, 2],
      Uint8List(SpotifyCsvImporter.maxJsonBytes + 1),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => reply);
      await expectLater(
        service.openStream(lease.file).first,
        throwsA(isA<SpotifyImportException>()),
      );
    }
  });
  test('subscription cancellation targets only its exact pending native request', () async {
    final pending = Completer<Object>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'list') return {'files': catalog, 'notice': null};
      if (call.method == 'read') return pending.future;
      return null;
    });
    await service.start(); final lease = service.inbox.begin('a');
    final subscription = service.openStream(lease.file).listen((_) => fail('Cancelled bytes published'));
    await Future<void>.delayed(Duration.zero);
    final request = calls.singleWhere((call) => call.method == 'read').arguments['request'];
    await subscription.cancel(); await Future<void>.delayed(Duration.zero);
    expect(calls.singleWhere((call) => call.method == 'cancel').arguments['request'], request);
    pending.complete(Uint8List.fromList([1])); await Future<void>.delayed(Duration.zero);
    await service.finish(lease);
  });
  test('acknowledging notice retains every pending descriptor without reads', () async {
    await service.start(); service.notice = 'Owned unsupported-file notice';
    await service.acknowledgeNotice();
    expect(service.notice, isNull); expect(service.inbox.pending.single.id, 'a');
    expect(calls.last.method, 'ackNotice');
    expect(calls.where((call) => call.method == 'read'), isEmpty);
  });
}
