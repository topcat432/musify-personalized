/// Exact-URL provenance for a public transport User-Agent, never credentials.
/// Older URLs without provenance are not assigned a guessed client identity.
class StreamRequestContexts {
  final _contexts = <String, Map<String, String>>{};

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

  bool remember(String url, Map<String, String> headers) {
    final safe = mediaHeaders(headers);
    if (!supports(url) || safe == null) return false;
    _contexts.remove(url);
    _contexts[url] = safe;
    if (_contexts.length > 128) _contexts.remove(_contexts.keys.first);
    return true;
  }

  Map<String, String>? forUrl(String url) => _contexts[url];

  Map<String, Object>? snapshot(String url) {
    final headers = forUrl(url);
    return headers == null
        ? null
        : {'version': 1, 'url': url, 'headers': headers};
  }

  bool restore(String url, Object? raw) {
    if (raw is! Map || raw['version'] != 1 || raw['url'] != url) return false;
    final headers = mediaHeaders(raw['headers']);
    return headers != null && remember(url, headers);
  }
}

final streamRequestContexts = StreamRequestContexts();
