import 'package:http/http.dart';

import 'youtube_explode_exception.dart';

/// Exception thrown when a fatal failure occurs.
class RequestLimitExceededException extends YoutubeExplodeException {
  final int? statusCode;
  final String? retryAfter;
  final bool googleSorry;

  /// Initializes an instance of [RequestLimitExceededException]
  RequestLimitExceededException(super.message)
      : statusCode = null,
        retryAfter = null,
        googleSorry = false;

  /// Initializes an instance of [RequestLimitExceeded] with a [Response]
  RequestLimitExceededException.httpRequest(BaseResponse response)
      : statusCode = response.statusCode,
        retryAfter = _safeRetryAfter(response.headers['retry-after']),
        googleSorry = _isGoogleSorry(response),
        super('YouTube request denied: status=${response.statusCode}; '
            'reason=${_isGoogleSorry(response) ? 'google-sorry' : 'rate-limit'}; '
            'retry-after=${_safeRetryAfter(response.headers['retry-after']) ?? 'unspecified'}.');

  static bool _isGoogleSorry(BaseResponse response) {
    final url = response.request?.url;
    return url != null &&
        url.host.endsWith('.google.com') &&
        url.path.startsWith('/sorry/');
  }

  // Retain normal seconds/date values without logging arbitrary header content,
  // request URLs, cookies, query parameters or response bodies.
  static String? _safeRetryAfter(String? value) {
    if (value == null) return null;
    final text = value.trim();
    if (RegExp(r'^\d{1,10}$').hasMatch(text) ||
        RegExp(r'^[A-Za-z]{3}, \d{2} [A-Za-z]{3} \d{4} \d{2}:\d{2}:\d{2} GMT$')
            .hasMatch(text)) return text;
    return null;
  }
}
