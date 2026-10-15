import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Reuses only an existing exact recording identity. Pending lookups are shared,
/// but neither successes nor failures create a new persistent metadata cache.
class SharedSongMetadataResolver {
  SharedSongMetadataResolver(this.load);

  final Future<Map> Function(String id) load;
  final Map<String, Future<Map>> _pending = {};

  Future<Map> resolve(
    String id, {
    Iterable<dynamic> knownSongs = const [],
  }) async {
    for (final candidate in knownSongs) {
      final known = _validated(id, candidate);
      if (known != null) return known;
    }

    final pending = _pending.putIfAbsent(id, () async {
      final result = _validated(id, await load(id));
      if (result == null) {
        throw const FormatException(
          'Selected recording metadata is incomplete',
        );
      }
      return result;
    });
    try {
      return Map<String, dynamic>.from(await pending);
    } finally {
      if (identical(_pending[id], pending)) unawaited(_pending.remove(id));
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
