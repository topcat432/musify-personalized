/// Exact-URL provenance for a public transport User-Agent, never credentials.
/// Older URLs without provenance are not assigned a guessed client identity.
class StreamRequestContexts {
  final _contexts = <String, Map<String, String>>{};
  final _lengths = <String, int>{};

  static bool supports(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        uri.port == 443 &&
        (uri.host == 'googlevideo.com' ||
            uri.host.endsWith('.googlevideo.com'));
  }

  static Map<String, String>? mediaHeaders(Object? raw) {
    if (raw is! Map) return null;
    final result = <String, String>{};
    for (final entry in raw.entries) {
      if (entry.key is! String ||
          (entry.key as String).toLowerCase() != 'user-agent' ||
          entry.value is! String ||
          result.containsKey('User-Agent'))
        return null;
      final value = entry.value as String;
      if (value.isEmpty ||
          value.length > 1024 ||
          value.contains(RegExp(r'[\x00-\x1f\x7f]')))
        return null;
      result['User-Agent'] = value;
    }
    return Map.unmodifiable(result);
  }

  bool remember(String url, Map<String, String> headers, {int? sourceLength}) {
    final safe = mediaHeaders(headers);
    if (!supports(url) || safe == null) return false;
    final hint = int.tryParse(Uri.parse(url).queryParameters['clen'] ?? '');
    if (sourceLength != null &&
        (sourceLength <= 0 ||
            sourceLength > 2 * 1024 * 1024 * 1024 ||
            (hint != null && hint != sourceLength)))
      return false;
    _contexts.remove(url);
    _contexts[url] = safe;
    _lengths.remove(url);
    if (sourceLength != null) _lengths[url] = sourceLength;
    if (_contexts.length > 128) {
      final oldest = _contexts.keys.first;
      _contexts.remove(oldest);
      _lengths.remove(oldest);
    }
    return true;
  }

  Map<String, String>? forUrl(String url) => _contexts[url];
  int? lengthForUrl(String url) => _lengths[url];

  Map<String, Object>? snapshot(String url) {
    final headers = forUrl(url);
    return headers == null
        ? null
        : {
            'version': 1,
            'url': url,
            'headers': headers,
            if (_lengths[url] != null) 'sourceLength': _lengths[url]!,
          };
  }

  bool restore(String url, Object? raw) {
    if (raw is! Map || raw['version'] != 1 || raw['url'] != url) return false;
    final headers = mediaHeaders(raw['headers']);
    final length = raw['sourceLength'];
    if (length != null && length is! int) return false;
    return headers != null &&
        remember(url, headers, sourceLength: length as int?);
  }
}

final streamRequestContexts = StreamRequestContexts();
