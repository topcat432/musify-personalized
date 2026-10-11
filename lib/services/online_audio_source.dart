// just_audio 0.10.6's experimental byte-source contract is covered by focused
// range, cancellation and boundary tests before native playback acceptance.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/stream_request_context.dart';

typedef OnlineSourceFactory =
    AudioSource Function(
      String url, {
      dynamic tag,
      VoidCallback? onUnavailable,
    });

/// Only the GitHub Android flavor allows the player's IPv4 loopback transport.
AudioSource onlineAudioSource(
  String url, {
  dynamic tag,
  bool? enableBoundedTransport,
  VoidCallback? onUnavailable,
}) {
  final uri = Uri.parse(url);
  final enabled =
      enableBoundedTransport ??
      (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          appFlavor == 'github');
  final length = int.tryParse(uri.queryParameters['clen'] ?? '');
  if (enabled && GoogleVideoByteSource.accepts(uri, length)) {
    return GoogleVideoByteSource(
      uri,
      sourceLength: length!,
      tag: tag,
      requestHeaders: streamRequestContexts.forUrl(url) ?? const {},
      onUnavailable: onUnavailable,
    );
  }
  return AudioSource.uri(
    uri,
    tag: tag,
    headers: streamRequestContexts.forUrl(url),
  );
}

/// Supplies native open-ended reads as finite HTTPS ranges, without caching.
/// just_audio serves this source at a fresh UUID-v4 path on IPv4 loopback.
class GoogleVideoByteSource extends StreamAudioSource {
  GoogleVideoByteSource(
    this.uri, {
    required this.sourceLength,
    super.tag,
    http.Client Function()? clientFactory,
    this.chunkSize = 256 * 1024,
    this.timeout = const Duration(seconds: 10),
    this.onUnavailable,
    Map<String, String> requestHeaders = const {},
  }) : requestHeaders =
           StreamRequestContexts.mediaHeaders(requestHeaders) ??
           (throw ArgumentError('Unsupported media request headers.')),
       _clientFactory = clientFactory ?? http.Client.new {
    if (!accepts(uri, sourceLength) ||
        chunkSize <= 0 ||
        chunkSize > 256 * 1024 ||
        timeout <= Duration.zero) {
      throw ArgumentError('Unsupported bounded audio source.');
    }
  }

  final Uri uri;
  final Map<String, String> requestHeaders;
  final int sourceLength;
  final int chunkSize;
  final Duration timeout;
  final http.Client Function() _clientFactory;
  final VoidCallback? onUnavailable;
  final Set<http.Client> _clients = {};
  final Set<Future<void> Function()> _cancellations = {};
  StateError? _terminalError;
  bool _cancelled = false;
  bool get isUnavailable => _terminalError != null;

  Future<void> cancelRequests() async {
    _cancelled = true;
    await Future.wait(_cancellations.toList().map((cancel) => cancel()));
  }

  static bool accepts(Uri uri, int? length) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (uri.host == 'googlevideo.com' ||
          uri.host.endsWith('.googlevideo.com')) &&
      (uri.port == 443) &&
      length != null &&
      length > 0 &&
      length <= 2 * 1024 * 1024 * 1024;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    if (_terminalError != null) throw _terminalError!;
    if (_cancelled) throw StateError('Audio byte source was cancelled.');
    final offset = start ?? 0;
    final limit = end == null || end > sourceLength ? sourceLength : end;
    if (offset < 0 || offset >= sourceLength || limit <= offset) {
      throw RangeError('Invalid audio byte range.');
    }
    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: limit - offset,
      offset: offset,
      contentType: uri.queryParameters['mime'] == 'audio/webm'
          ? 'audio/webm'
          : 'audio/mp4',
      stream: _rangeStream(offset, limit),
    );
  }

  Stream<List<int>> _rangeStream(int start, int end) {
    http.Client? client;
    StreamSubscription<List<int>>? subscription;
    late final Future<void> Function() cancel;
    late final StreamController<List<int>> controller;
    var closed = false;
    void close() {
      if (closed) return;
      closed = true;
      _cancellations.remove(cancel);
      if (client != null) {
        _clients.remove(client);
        client!.close();
      }
    }

    cancel = () async {
      // Closing the HTTP client first aborts a pending header/body read.
      close();
      await subscription?.cancel();
      if (!controller.isClosed) unawaited(controller.close());
    };
    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        if (_cancelled || isUnavailable) {
          controller.addError(StateError('Audio byte source is unavailable.'));
          unawaited(controller.close());
          return;
        }
        if (_clients.length >= 4) {
          controller.addError(StateError('Too many audio byte requests.'));
          unawaited(controller.close());
          return;
        }
        client = _clientFactory();
        _clients.add(client!);
        _cancellations.add(cancel);
        subscription = _fetchRanges(client!, start, end, () => closed).listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            close();
            unawaited(controller.close());
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: cancel,
    );
    return controller.stream;
  }

  Stream<List<int>> _fetchRanges(
    http.Client client,
    int start,
    int end,
    bool Function() cancelled,
  ) async* {
    try {
      for (var cursor = start; cursor < end;) {
        if (cancelled() || _cancelled) return;
        if (_terminalError != null) throw _terminalError!;
        final last = (cursor + chunkSize < end ? cursor + chunkSize : end) - 1;
        final expected = last - cursor + 1;
        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers.addAll(requestHeaders)
          ..headers['Range'] = 'bytes=$cursor-$last';
        final response = await client.send(request).timeout(timeout);
        if (response.statusCode != 206 ||
            response.headers['content-range'] !=
                'bytes $cursor-$last/$sourceLength' ||
            (response.contentLength != null &&
                response.contentLength != expected)) {
          throw StateError(
            'Audio source did not return the requested byte range '
            '(HTTP ${response.statusCode}).',
          );
        }
        var received = 0;
        await for (final bytes in response.stream.timeout(timeout)) {
          received += bytes.length;
          if (received > expected) {
            throw StateError('Audio source exceeded the requested byte range.');
          }
          yield bytes;
        }
        if (received != expected) {
          throw StateError(
            'Audio source ended before the requested byte range.',
          );
        }
        cursor = last + 1;
      }
    } catch (_) {
      if (!cancelled()) {
        // Native retries may ask the same source again after a denied or
        // damaged range. Fail before local response headers, without another
        // upstream request, a partial-success claim or access fallback.
        final firstFailure = _terminalError == null;
        _terminalError = StateError(
          'Audio byte source is unavailable after a failed range request.',
        );
        if (firstFailure && onUnavailable != null) {
          scheduleMicrotask(onUnavailable!);
        }
        rethrow;
      }
    }
  }
}
