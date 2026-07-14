import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/review_sprint_prefetch_cache.dart';

void main() {
  test('coalesces duplicate in-flight stream requests', () async {
    final cache = ReviewSprintPrefetchCache();
    final completer = Completer<String?>();
    var requests = 0;

    Future<String?> resolver(String songId) {
      requests++;
      return completer.future;
    }

    final first = cache.resolve('same-song', resolver);
    final second = cache.resolve('same-song', resolver);
    expect(requests, 1);

    completer.complete('https://stream.example/same-song');
    expect(await first, 'https://stream.example/same-song');
    expect(await second, 'https://stream.example/same-song');
    expect(cache.length, 1);
  });

  test('keeps recently used URLs and evicts the least recent', () async {
    final cache = ReviewSprintPrefetchCache(capacity: 2);

    Future<String?> resolver(String songId) async => 'url-$songId';

    await cache.resolve('a', resolver);
    await cache.resolve('b', resolver);
    await cache.resolve('a', resolver);
    await cache.resolve('c', resolver);

    expect(cache.contains('a'), isTrue);
    expect(cache.contains('b'), isFalse);
    expect(cache.contains('c'), isTrue);
  });

  test('prefetches upcoming streams concurrently', () async {
    final cache = ReviewSprintPrefetchCache();
    final started = <String>[];
    final gates = <String, Completer<String?>>{
      'a': Completer<String?>(),
      'b': Completer<String?>(),
      'c': Completer<String?>(),
    };

    final prefetch = cache.prefetch(['a', 'b', 'c'], (songId) {
      started.add(songId);
      return gates[songId]!.future;
    });
    await Future<void>.delayed(Duration.zero);

    expect(started, containsAll(<String>['a', 'b', 'c']));
    for (final entry in gates.entries) {
      entry.value.complete('url-${entry.key}');
    }
    await prefetch;
    expect(cache.length, 3);
  });
}
