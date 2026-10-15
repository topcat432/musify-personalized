import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/utilities/sharing_intent.dart';

void main() {
  test('launch share reaches the existing consumer once', () async {
    final consumed = <String?>[];
    await consumeInitialSharedTextIntent(
      readInitialText: () async => 'https://youtu.be/synthetic01',
      stillCurrent: () => true,
      consume: (value) async => consumed.add(value),
      onError: (error, stack) => fail('$error'),
    );
    expect(consumed, ['https://youtu.be/synthetic01']);
  });

  for (final value in <String?>[null, '', '  \n ']) {
    test('empty initial text does not invoke playback: $value', () async {
      await consumeInitialSharedTextIntent(
        readInitialText: () async => value,
        stillCurrent: () => true,
        consume: (_) async => fail('Empty text consumed'),
        onError: (error, stack) => fail('$error'),
      );
    });
  }

  for (final reason in ['newer share', 'disposed owner']) {
    test('pending launch share yields to $reason', () async {
      final platformRead = Completer<String?>();
      var current = true;
      final pending = consumeInitialSharedTextIntent(
        readInitialText: () => platformRead.future,
        stillCurrent: () => current,
        consume: (_) async => fail('Stale launch share consumed'),
        onError: (error, stack) => fail('$error'),
      );
      current = false;
      platformRead.complete('https://youtu.be/synthetic01');
      await pending;
    });
  }

  test('platform read failure reaches the error handler once', () async {
    final failure = StateError('synthetic platform failure');
    final errors = <Object>[];
    await consumeInitialSharedTextIntent(
      readInitialText: () async => throw failure,
      stillCurrent: () => true,
      consume: (_) async => fail('Failed platform read consumed'),
      onError: (error, stack) => errors.add(error),
    );
    expect(errors, [same(failure)]);
  });

  test('consumer failure is reported without retry', () async {
    final failure = StateError('synthetic playback failure');
    final errors = <Object>[];
    var attempts = 0;
    await consumeInitialSharedTextIntent(
      readInitialText: () async => 'https://youtu.be/synthetic01',
      stillCurrent: () => true,
      consume: (_) async {
        attempts++;
        throw failure;
      },
      onError: (error, stack) => errors.add(error),
    );
    expect(attempts, 1);
    expect(errors, [same(failure)]);
  });

  test('disposed owner does not receive a late platform error', () async {
    final platformRead = Completer<String?>();
    var current = true;
    final pending = consumeInitialSharedTextIntent(
      readInitialText: () => platformRead.future,
      stillCurrent: () => current,
      consume: (_) async => fail('Disposed owner consumed text'),
      onError: (_, stack) => fail('Disposed owner received platform error'),
    );
    current = false;
    platformRead.completeError(StateError('synthetic late failure'));
    await pending;
  });
}
