import 'dart:async';

import 'package:logging/logging.dart';

import '../youtube_explode_dart.dart';

final _logger = Logger('YoutubeExplode.Retry');

/// Run the [function] each time an exception is thrown until the retryCount
/// is 0.
Future<T> retry<T>(
  YoutubeHttpClient? client,
  FutureOr<T> Function() function,
) async {
  var retryCount = 5;

  // ignore: literal_only_boolean_expressions
  while (true) {
    try {
      return await function();
      // ignore: avoid_catches_without_on_clauses
    } on Exception catch (e, s) {
      if (client != null && client.closed) {
        throw HttpClientClosedException();
      }
      retryCount -= getExceptionCost(e);
      if (retryCount <= 0) {
        rethrow;
      }
      _logger.warning('Retrying after exception: $e', e, s);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}

/// Get "retry" cost of each YoutubeExplode exception.
int getExceptionCost(Exception e) {
  if (e is RequestLimitExceededException) {
    // A rate-limit or Google sorry response is a denial, not a transient
    // transport failure. Stop this operation without repeating the request.
    return 5;
  }
  if (e is FatalFailureException) {
    if (e.statusCode == 403 || e.terminal) return 5;
    return 3;
  }
  if (e is VideoUnplayableException) {
    return 5;
  }
  return 1;
}
