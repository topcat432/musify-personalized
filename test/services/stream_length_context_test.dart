import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/online_audio_source.dart';
import 'package:musify/services/stream_request_context.dart';

const _url = 'https://r1.fixture.googlevideo.com/owned?sig=owned%2Ffixture';
const _headers = {'User-Agent': 'Owned-Length-Fixture/1.0'};
void main() {
  test(
    'learned length and exact public headers survive a fresh context restart',
    () {
      final original = StreamRequestContexts();
      expect(original.remember(_url, _headers, sourceLength: 100), true);
      final saved = jsonDecode(jsonEncode(original.snapshot(_url)));
      final restarted = StreamRequestContexts();
      expect(restarted.restore(_url, saved), true);
      expect(restarted.lengthForUrl(_url), 100);
      expect(restarted.forUrl(_url), _headers);
    },
  );
  test(
    'legacy and partial header-only states remain readable without invented length',
    () {
      for (final state in [
        {'version': 1, 'url': _url, 'headers': _headers},
        {'version': 1, 'url': _url, 'headers': _headers, 'sourceLength': null},
      ]) {
        final context = StreamRequestContexts();
        expect(context.restore(_url, state), true);
        expect(context.lengthForUrl(_url), isNull);
      }
    },
  );
  test(
    'invalid/conflicting length restores preserve the previous exact context',
    () {
      final context = StreamRequestContexts();
      context.remember(_url, _headers, sourceLength: 100);
      final before = jsonEncode(context.snapshot(_url));
      for (final length in [-1, 0, 2147483649, '100', 1.5]) {
        expect(
          context.restore(_url, {
            'version': 1,
            'url': _url,
            'headers': {'User-Agent': 'Other'},
            'sourceLength': length,
          }),
          false,
        );
        expect(jsonEncode(context.snapshot(_url)), before);
      }
      const hint = 'https://r1.fixture.googlevideo.com/owned?clen=100';
      expect(context.remember(hint, _headers, sourceLength: 101), false);
    },
  );
  test(
    'learned size enables finite production source without changing signed URI',
    () {
      streamRequestContexts.remember(_url, _headers, sourceLength: 100);
      final source = onlineAudioSource(_url, enableBoundedTransport: true);
      expect(source, isA<GoogleVideoByteSource>());
      final finite = source as GoogleVideoByteSource;
      expect(finite.uri.toString(), _url);
      expect(finite.sourceLength, 100);
      expect(finite.requestHeaders, _headers);
    },
  );
}
