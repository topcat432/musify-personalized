import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Reuses only an existing exact recording identity. Pending lookups are shared,
/// but neither successes nor failures create a new persistent metadata cache.
class SharedSongMetadataResolver {
  SharedSongMetadataResolver(
    this.load, {
    this.lookupLifetime = const Duration(seconds: 30),
  }) : assert(lookupLifetime > Duration.zero);

  final Future<Map> Function(String id) load;
  final Duration lookupLifetime;
  final Map<String, _SharedMetadataLookup> _pending = {};

  Future<Map> resolve(
    String id, {
    Iterable<dynamic> knownSongs = const [],
  }) async {
    for (final candidate in knownSongs) {
      final known = _validated(id, candidate);
      if (known != null) return known;
    }

    final pending = _pending[id] ?? _startLookup(id);
    return Map<String, dynamic>.from(await pending.result.future);
  }

  _SharedMetadataLookup _startLookup(String id) {
    final lookup = _SharedMetadataLookup();
    _pending[id] = lookup;
    lookup.deadline = Timer(lookupLifetime, () {
      _finish(
        id,
        lookup,
        error: TimeoutException(
          'Recording metadata lookup timed out',
          lookupLifetime,
        ),
      );
    });
    // The shared HTTP client cannot be closed to cancel just this lookup.
    // Expiry releases this logical slot without retrying; both late success
    // and error are consumed without touching any successor or playback owner.
    unawaited(
      Future<Map>.sync(() => load(id)).then<void>(
        (value) {
          if (lookup.result.isCompleted) return;
          try {
            final result = _validated(id, value);
            if (result == null) {
              throw const FormatException(
                'Selected recording metadata is incomplete',
              );
            }
            _finish(id, lookup, song: result);
          } catch (error, stack) {
            _finish(id, lookup, error: error, stack: stack);
          }
        },
        onError: (Object error, StackTrace stack) {
          _finish(id, lookup, error: error, stack: stack);
        },
      ),
    );
    return lookup;
  }

  void _finish(
    String id,
    _SharedMetadataLookup lookup, {
    Map? song,
    Object? error,
    StackTrace? stack,
  }) {
    if (lookup.result.isCompleted) return;
    lookup.deadline?.cancel();
    if (identical(_pending[id], lookup)) _pending.remove(id);
    if (error != null) {
      lookup.result.completeError(error, stack);
    } else {
      lookup.result.complete(song!);
    }
  }

  Map<String, dynamic>? _validated(String id, dynamic candidate) {
    if (candidate is! Map ||
        candidate.keys.any((key) => key is! String) ||
        candidate['ytid'] != id ||
        candidate['title'] is! String ||
        (candidate['title'] as String).trim().isEmpty)
      return null;
    for (final key in [
      'artist',
      'highResImage',
      'lowResImage',
      'image',
      'audioPath',
    ]) {
      if (candidate[key] != null && candidate[key] is! String) return null;
    }
    final duration = candidate['duration'];
    if (duration != null && (duration is! int || duration < 0)) return null;
    if (candidate['isLive'] != null && candidate['isLive'] is! bool)
      return null;
    final copy = Map<String, dynamic>.from(candidate);
    copy['highResImage'] ??= copy['image'] ?? copy['lowResImage'] ?? '';
    return copy;
  }
}

class _SharedMetadataLookup {
  final result = Completer<Map>();
  Timer? deadline;
}

String sharedSongFailureMessage(Object error) =>
    error is RequestLimitExceededException
    ? 'YouTube is limiting this request. Choose a saved track or try again later.'
    : 'Could not open this recording. Choose a saved track or another recording.';

String sharedSongFailureDiagnostic(
  Object error, {
  String phase = 'shared-song-resolution',
}) {
  final prefix = 'phase=$phase; type=${error.runtimeType}';
  if (error is RequestLimitExceededException) {
    return '$prefix; status=${error.statusCode ?? 'unknown'}; '
        'reason=${error.googleSorry ? 'google-sorry' : 'rate-limit'}; '
        'retry-after=${error.retryAfter ?? 'unspecified'}';
  }
  return prefix;
}
