import 'dart:async';
import 'dart:collection';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../exceptions/exceptions.dart';
import '../../extensions/helpers_extension.dart';
import '../../retry.dart';
import '../../reverse_engineering/challenges/js_challenge.dart';
import '../../reverse_engineering/heuristics.dart';
import '../../reverse_engineering/models/stream_info_provider.dart';
import '../../reverse_engineering/pages/watch_page.dart';
import '../../reverse_engineering/youtube_http_client.dart';
import '../video_id.dart';
import '../youtube_api_client.dart';
import 'stream_controller.dart';
import 'streams.dart';

/// Queries related to media streams of YouTube videos.
class StreamClient {
  static final _logger = Logger('YoutubeExplode.StreamsClient');
  final YoutubeHttpClient _httpClient;
  final StreamController _controller;
  final BaseJSChallengeSolver? _jsChallengeSolver;
  // Weak object provenance survives passing a stream between extractor instances.
  static final _requestHeaders = Expando<Map<String, String>>();

  /// Media headers from the same request context that resolved this stream.
  /// Session cookies, visitor identifiers and authorization are never copied.
  Map<String, String>? requestHeadersFor(StreamInfo stream) =>
      _requestHeaders[stream];

  Map<String, String> _mediaHeaders(YoutubeApiClient client) {
    String? agent =
        client.payload['context']?['client']?['userAgent'] as String?;
    if (agent == null) {
      for (final header in _httpClient.headers.entries) {
        if (header.key.toLowerCase() == 'user-agent') agent = header.value;
      }
    }
    for (final header in client.headers.entries) {
      if (header.key.toLowerCase() == 'user-agent') {
        agent = header.value.toString();
      }
    }
    return Map.unmodifiable({if (agent != null) 'User-Agent': agent});
  }

  /// Initializes an instance of [StreamClient]
  StreamClient(this._httpClient, {BaseJSChallengeSolver? jsSolver})
      : _controller = StreamController(_httpClient),
        _jsChallengeSolver = jsSolver;

  /// Gets the manifest that contains information
  /// about available streams in the specified video.
  ///
  /// See [YoutubeApiClient] for all the possible clients that can be set using the [ytClients] parameter.
  /// If [ytClients] is null the library automatically manages the clients, otherwise only the clients provided are used.
  /// Currently by default the  [YoutubeApiClient.androidSdkless] client is used,
  /// and if a js solver is provided the [YoutubeApiClient.safari] is used additionally.
  ///
  ///
  /// Note: if using any android client youtube often prevents downloading the same stream multiple times or downloading more than one stream from the same manifest.
  /// Note: that age restricted videos are no longer support due to the changes in the YouTube API.
  ///
  /// If [requireWatchPage] (default: true) is set to false the watch page is not used to extract the streams (so the process can be faster) but
  /// it probably will be less reliable.
  /// If the extracted streams require signature decoding for which the watch page is required, the client will automatically fetch the watch page anyways (e.g. [YoutubeApiClient.tv]).
  ///
  /// If the extraction fails an exception is thrown, to diagnose the issue enable the logging from the `logging` package, and open an issue with the output.
  /// For example add at the beginning of your code:
  /// ```dart
  /// Logger.root.level = Level.FINER;
  /// Logger.root.onRecord.listen((e)  {
  ///   print(e);
  ///    if (e.error != null) {
  ///     print(e.error);
  ///     print(e.stackTrace);
  ///   }
  /// });
  /// ```
  Future<StreamManifest> getManifest(dynamic videoId,
          {@Deprecated(
              'Use the ytClient parameter instead passing the proper [YoutubeApiClient]s')
          bool fullManifest = false,
          List<YoutubeApiClient>? ytClients,
          bool requireWatchPage = true,
          StreamInfo? Function(List<StreamInfo>)? streamForValidation}) =>
      _getManifest(videoId,
          ytClients: ytClients,
          requireWatchPage: requireWatchPage,
          streamForValidation: streamForValidation);

  /// Discover only the chosen progressive format's length with one bounded GET.
  /// A size of zero exists only in the selection callback, never the result.
  Future<StreamManifest> getManifestWithSelectedLength(
    dynamic videoId, {
    required List<YoutubeApiClient> ytClients,
    bool requireWatchPage = false,
    required StreamInfo? Function(List<StreamInfo>) streamForValidation,
    int maximumStreamBytes = 2 * 1024 * 1024 * 1024,
    Duration probeTimeout = const Duration(seconds: 10),
  }) =>
      _getManifest(videoId,
          ytClients: ytClients,
          requireWatchPage: requireWatchPage,
          streamForValidation: streamForValidation,
          selectedLengthDiscovery: true,
          maximumStreamBytes: maximumStreamBytes,
          probeTimeout: probeTimeout);

  Future<StreamManifest> _getManifest(
    dynamic videoId, {
    List<YoutubeApiClient>? ytClients,
    bool requireWatchPage = true,
    StreamInfo? Function(List<StreamInfo>)? streamForValidation,
    bool selectedLengthDiscovery = false,
    int maximumStreamBytes = 2 * 1024 * 1024 * 1024,
    Duration probeTimeout = const Duration(seconds: 10),
  }) async {
    assert(ytClients == null || ytClients.isNotEmpty,
        'ytClients cannot be an empty list');

    videoId = VideoId.fromString(videoId);
    final clients = ytClients ?? [YoutubeApiClient.androidSdkless];
    if (selectedLengthDiscovery &&
        (clients.length != 1 ||
            maximumStreamBytes <= 0 ||
            probeTimeout <= Duration.zero)) {
      throw ArgumentError(
          'Selected discovery requires one client and positive limits.');
    }

    if (_jsChallengeSolver != null && ytClients == null) {
      clients.add(YoutubeApiClient.safari);
    }

    final uniqueStreams = LinkedHashSet<StreamInfo>(
      equals: (a, b) {
        if (a.runtimeType != b.runtimeType) return false;
        if (a is AudioStreamInfo && b is AudioStreamInfo) {
          return a.tag == b.tag && a.audioTrack == b.audioTrack;
        }
        return a.tag == b.tag;
      },
      hashCode: (e) {
        if (e is AudioStreamInfo) {
          return e.tag.hashCode ^ e.audioTrack.hashCode;
        }
        return e.tag.hashCode;
      },
    );

    Object? lastException;
    StreamInfo? validatedStream;

    for (final client in clients) {
      _logger.fine(
          'Getting stream manifest for video $videoId with client: ${client.payload['context']['client']['clientName']}');
      try {
        await retry(_httpClient, () async {
          final streams = await _getStreams(
            videoId,
            ytClient: client,
            requireWatchPage: requireWatchPage,
            selectedLengthDiscovery: selectedLengthDiscovery,
          ).toList();
          if (streams.isEmpty) {
            throw VideoUnavailableException(
              'Video "$videoId" does not contain any playable streams.',
            );
          }

          // Validate the format the caller intends to use before playback.
          // This is selection before any media request, never a denial retry.
          final probe = streamForValidation == null
              ? streams.first
              : streamForValidation(List.unmodifiable(streams));
          if (probe == null || !streams.any((s) => identical(s, probe))) {
            if (selectedLengthDiscovery) {
              throw FatalFailureException('No eligible selected format.', 0,
                  terminal: true);
            }
            throw VideoUnavailableException('No eligible stream to validate.');
          }
          if (selectedLengthDiscovery) {
            final resolved = await _discoverSelected(
                probe, maximumStreamBytes, probeTimeout);
            _requestHeaders[resolved] = requestHeadersFor(probe) ?? const {};
            uniqueStreams.addAll(streams.where((stream) =>
                !identical(stream, probe) && stream.size.totalBytes > 0));
            uniqueStreams.add(resolved);
            validatedStream = resolved;
            return;
          }
          // Some media servers reject HEAD while accepting playback GETs.
          // Probe one byte with the same signed URI, then cancel the body even
          // when the server ignores Range. Availability is not full playback.
          final response = await _httpClient.send(
            http.Request('GET', probe.url)
              ..followRedirects = false
              ..headers.addAll(requestHeadersFor(probe) ?? const {})
              ..headers['Range'] = 'bytes=0-0',
          );
          await response.stream.listen(null).cancel();
          if (response.statusCode == 403) {
            throw FatalFailureException(
              'Video $videoId returned 403 (stream: ${probe.tag})',
              403,
            );
          }
          if (response.statusCode != 200 && response.statusCode != 206) {
            if (response.statusCode >= 500) {
              throw TransientFailureException.httpRequest(response);
            }
            throw FatalFailureException.httpRequest(response);
          }
          uniqueStreams.addAll(streams);
        });
      } catch (e, s) {
        // A denied request cannot be repaired by repeating it or changing
        // client identity. Preserve that failure rather than falling back.
        if (e is RequestLimitExceededException) rethrow;
        if (e is FatalFailureException && (e.statusCode == 403 || e.terminal))
          rethrow;
        _logger.severe(
            'Failed to get stream manifest for video $videoId with client: ${client.payload['context']['client']['clientName']}. Reason: $e\n',
            e,
            s);
        lastException = e;
      }
    }

    // If the user has not provided any client retry with the tv which work also in some restricted videos.
    if (uniqueStreams.isEmpty &&
        ytClients == null &&
        !selectedLengthDiscovery) {
      return getManifest(videoId,
          ytClients: [YoutubeApiClient.tv],
          streamForValidation: streamForValidation);
    }
    if (uniqueStreams.isEmpty) {
      if (lastException is Error && lastException.stackTrace != null) {
        throw Error.throwWithStackTrace(
            lastException, lastException.stackTrace!);
      }
      throw lastException ??
          VideoUnavailableException(
              'Video "$videoId" has no available streams');
    }
    return StreamManifest(uniqueStreams.toList(),
        validatedStream: validatedStream);
  }

  static bool _trustedMediaHost(Uri uri) {
    final host = uri.host.toLowerCase();
    final label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
    return uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.authority.contains('@') &&
        uri.fragment.isEmpty &&
        uri.port == 443 &&
        host.length <= 253 &&
        host.endsWith('.googlevideo.com') &&
        host
            .split('.')
            .every((part) => label.hasMatch(part) && part != 'localhost') &&
        !RegExp(r'^(?:[0-9]+\.)+[0-9]+\.googlevideo\.com$').hasMatch(host);
  }

  Future<StreamInfo> _discoverSelected(
      StreamInfo stream, int cap, Duration timeout) async {
    Never fail(String reason, [int status = 0]) =>
        throw FatalFailureException('Selected format probe: $reason', status,
            terminal: true);
    if (stream is! MuxedStreamInfo &&
        stream is! AudioOnlyStreamInfo &&
        stream is! VideoOnlyStreamInfo) fail('unsupported-format');
    if (stream.size.totalBytes > cap || stream.size.totalBytes < 0)
      fail('size-cap');
    if (!_trustedMediaHost(stream.url)) fail('unapproved-source');
    var abort = Completer<void>();
    http.StreamedResponse? response;
    StreamIterator<List<int>>? body;
    var resolvedUri = stream.url;
    final visited = <Uri>{resolvedUri};
    final clock = Stopwatch()..start();
    Duration remaining() {
      final left = timeout - clock.elapsed;
      if (left <= Duration.zero) fail('probe-deadline');
      return left;
    }

    try {
      for (var hop = 0;; hop++) {
        response = await _httpClient
            .sendMedia(http.AbortableRequest('GET', resolvedUri,
                abortTrigger: abort.future)
              ..followRedirects = false
              ..headers.addAll(requestHeadersFor(stream) ?? const {})
              ..headers['Range'] = 'bytes=0-0')
            .timeout(remaining());
        final status = response.statusCode;
        if (status == 206) break;
        if (!const [301, 302, 303, 307, 308].contains(status)) {
          fail('http-status', status);
        }
        if (hop >= 2) fail('redirect-hop-cap', status);
        final location = response.headers['location'];
        if (location == null || location.isEmpty || location.length > 8192) {
          fail('redirect-location', status);
        }
        late Uri target;
        try {
          target = resolvedUri.resolve(location);
        } catch (_) {
          fail('redirect-location', status);
        }
        if (!_trustedMediaHost(target) || target.path != stream.url.path) {
          fail('unapproved-redirect-target', status);
        }
        // Authoritative provider redirect may change delivery server/signature,
        // but must retain offered recording/format identity and declared length.
        for (final key in ['id', 'itag', 'mime', 'lmt', 'clen']) {
          final original = stream.url.queryParameters[key];
          if (original != null && target.queryParameters[key] != original) {
            fail('redirect-identity', status);
          }
        }
        final tag = target.queryParameters['itag'];
        if (tag != null && int.tryParse(tag) != stream.tag) {
          fail('redirect-format', status);
        }
        if (!visited.add(target)) fail('redirect-loop', status);
        if (!abort.isCompleted) abort.complete();
        await response.stream
            .listen(null, onError: (Object _) {})
            .cancel()
            .timeout(remaining() < const Duration(seconds: 2)
                ? remaining()
                : const Duration(seconds: 2));
        response = null;
        abort = Completer<void>();
        resolvedUri = target;
      }
      final range = RegExp(r'^bytes 0-0/([1-9][0-9]*)$', caseSensitive: false)
          .firstMatch(response.headers['content-range']?.trim() ?? '');
      final total = int.tryParse(range?.group(1) ?? '');
      if (total == null || total > cap) fail('range-or-size-cap');
      final redirectedLength =
          int.tryParse(resolvedUri.queryParameters['clen'] ?? '');
      if (redirectedLength != null && redirectedLength != total)
        fail('redirect-length-mismatch');
      if (stream.size.totalBytes > 0 && stream.size.totalBytes != total)
        fail('declared-length-mismatch');
      if (response.contentLength != 1) fail('response-length');
      final type = (response.headers['content-type'] ?? '')
          .split(';')
          .first
          .trim()
          .toLowerCase();
      if (type != stream.codec.mimeType.toLowerCase()) fail('content-type');
      body = StreamIterator(response.stream);
      if (!await body.moveNext().timeout(remaining()) ||
          body.current.length != 1) fail('one-byte-body');
      if (stream.size.totalBytes > 0 && resolvedUri == stream.url)
        return stream;
      final size = FileSize(total);
      if (stream is MuxedStreamInfo)
        return MuxedStreamInfo(
            stream.videoId,
            stream.tag,
            resolvedUri,
            stream.container,
            size,
            stream.bitrate,
            stream.audioCodec,
            stream.videoCodec,
            stream.qualityLabel,
            stream.videoQuality,
            stream.videoResolution,
            stream.framerate,
            stream.codec);
      if (stream is AudioOnlyStreamInfo)
        return AudioOnlyStreamInfo(
            stream.videoId,
            stream.tag,
            resolvedUri,
            stream.container,
            size,
            stream.bitrate,
            stream.audioCodec,
            stream.qualityLabel,
            stream.fragments,
            stream.codec,
            stream.audioTrack);
      final video = stream as VideoOnlyStreamInfo;
      return VideoOnlyStreamInfo(
          video.videoId,
          video.tag,
          resolvedUri,
          video.container,
          size,
          video.bitrate,
          video.videoCodec,
          video.qualityLabel,
          video.videoQuality,
          video.videoResolution,
          video.framerate,
          video.fragments,
          video.codec);
    } on FatalFailureException {
      rethrow;
    } catch (_) {
      fail('timeout-or-transport');
    } finally {
      if (!abort.isCompleted) abort.complete();
      try {
        final cancel = body?.cancel() ??
            response?.stream.listen(null, onError: (Object _) {}).cancel();
        if (cancel != null)
          await cancel.timeout(timeout < const Duration(seconds: 2)
              ? timeout
              : const Duration(seconds: 2));
      } catch (_) {
        fail('cancellation-timeout');
      }
    }
  }

  /// Gets the HTTP Live Stream (HLS) manifest URL
  /// for the specified video (if it's a live video stream).
  Future<String> getHttpLiveStreamUrl(VideoId videoId) async {
    final watchPage = await WatchPage.get(_httpClient, videoId.value);

    final playerResponse = watchPage.playerResponse;

    if (playerResponse == null) {
      throw TransientFailureException(
        "Couldn't extract the playerResponse from the Watch Page!",
      );
    }

    if (!playerResponse.isVideoPlayable) {
      throw VideoUnplayableException.unplayable(
        videoId,
        reason: playerResponse.videoPlayabilityError ?? '',
      );
    }

    final hlsManifest = playerResponse.hlsManifestUrl;
    if (hlsManifest == null) {
      throw VideoUnplayableException.notLiveStream(videoId);
    }
    return hlsManifest;
  }

  /// Gets the actual stream which is identified by the specified metadata.
  /// Usually this downloads the bytes of the stream.
  /// For HLS streams all the fragments are concatenated into a single stream.
  Stream<List<int>> get(StreamInfo streamInfo) =>
      _httpClient.getStream(streamInfo,
          streamClient: this,
          headers: requestHeadersFor(streamInfo) ?? const {});

  Stream<StreamInfo> _getStreams(VideoId videoId,
      {required YoutubeApiClient ytClient,
      bool requireWatchPage = true,
      bool selectedLengthDiscovery = false}) async* {
    // Use await for instead of yield* to catch exceptions
    await for (final stream in _getStream(videoId, ytClient,
        requireWatchPage: requireWatchPage,
        selectedLengthDiscovery: selectedLengthDiscovery)) {
      _requestHeaders[stream] = _mediaHeaders(ytClient);
      yield stream;
    }
  }

  Stream<StreamInfo> _getStream(VideoId videoId, YoutubeApiClient ytClient,
      {bool requireWatchPage = true,
      bool selectedLengthDiscovery = false}) async* {
    WatchPage? watchPage;
    if (requireWatchPage) {
      watchPage = await WatchPage.get(_httpClient, videoId.value);
    }
    final playerResponse = await _controller
        .getPlayerResponse(videoId, ytClient, watchPage: watchPage);

    if (!playerResponse.previewVideoId.isNullOrWhiteSpace) {
      throw VideoRequiresPurchaseException.preview(
        videoId,
        VideoId(playerResponse.previewVideoId!),
      );
    }

    if (playerResponse.videoPlayabilityError?.contains('payment') ?? false) {
      throw VideoRequiresPurchaseException(videoId);
    }

    if (!playerResponse.isVideoPlayable) {
      throw VideoUnplayableException.unplayable(
        videoId,
        reason: playerResponse.videoPlayabilityError ?? '',
      );
    }
    yield* _parseStreamInfo(playerResponse.streams,
        watchPage: watchPage,
        videoId: videoId,
        headers: _mediaHeaders(ytClient),
        selectedLengthDiscovery: selectedLengthDiscovery);

    if (!playerResponse.dashManifestUrl.isNullOrWhiteSpace) {
      final dashManifest =
          await _controller.getDashManifest(playerResponse.dashManifestUrl!);
      yield* _parseStreamInfo(dashManifest.streams,
          watchPage: watchPage,
          videoId: videoId,
          headers: _mediaHeaders(ytClient),
          selectedLengthDiscovery: selectedLengthDiscovery);
    }
    if (!playerResponse.hlsManifestUrl.isNullOrWhiteSpace) {
      final hlsManifest =
          await _controller.getHlsManifest(playerResponse.hlsManifestUrl!);
      yield* _parseStreamInfo(hlsManifest.streams,
          watchPage: watchPage,
          videoId: videoId,
          headers: _mediaHeaders(ytClient),
          selectedLengthDiscovery: selectedLengthDiscovery);
    }
  }

  Stream<StreamInfo> _parseStreamInfo(Iterable<StreamInfoProvider> streams,
      {WatchPage? watchPage,
      VideoId? videoId,
      Map<String, String> headers = const {},
      bool selectedLengthDiscovery = false}) async* {
    // First pass: collect all unique challenges
    final nChallenges = <String>{};
    final sigChallenges = <String>{};

    final solver = _jsChallengeSolver;
    if (solver != null) {
      for (final stream in streams) {
        try {
          final url = Uri.parse(stream.url);
          if (url.queryParameters.containsKey('n')) {
            nChallenges.add(url.queryParameters['n']!);
          }
          if (stream.signatureParameter != null) {
            sigChallenges.add(stream.signature!);
          }
        } catch (e) {
          // Skip invalid URLs, will be handled in second pass
        }
      }
    }

    // Bulk solve all challenges
    final solvedChallenges = <String, String?>{};
    if (watchPage != null &&
        solver != null &&
        (nChallenges.isNotEmpty || sigChallenges.isNotEmpty)) {
      final requests = <JSChallengeType, List<String>>{};
      if (nChallenges.isNotEmpty) {
        requests[JSChallengeType.n] = nChallenges.toList();
      }
      if (sigChallenges.isNotEmpty) {
        requests[JSChallengeType.sig] = sigChallenges.toList();
      }

      try {
        solvedChallenges
            .addAll(await solver.solveBulk(watchPage.sourceUrl!, requests));
      } catch (e) {
        _logger.warning('Could not bulk solve challenges: $e');
        // Fall back to individual solving if bulk fails
      }
    }

    // Second pass: process streams with solved challenges
    for (final stream in streams) {
      final itag = stream.tag;
      late Uri url;
      try {
        url = Uri.parse(stream.url);
      } catch (e) {
        continue;
      }

      if (solver != null && watchPage != null) {
        if (url.queryParameters.containsKey('n')) {
          final nParam = url.queryParameters['n']!;
          final decoded = solvedChallenges[nParam];
          if (decoded != null) {
            url = url.setQueryParam('n', decoded);
            _logger.fine(
                'Decoded n-sig for stream itag $itag. $nParam -> $decoded}');
          } else {
            // Fallback to individual solving if bulk solving didn't provide result
            try {
              final individualDecoded = await solver.solve(
                  watchPage.sourceUrl!, JSChallengeType.n, nParam);
              url = url.setQueryParam('n', individualDecoded);
              _logger.fine(
                  'Decoded n-sig for stream itag $itag (individual). $nParam -> $individualDecoded}');
            } catch (e) {
              _logger.warning('Could not decipher n-sig using JS solver: $e');
            }
          }
        }
        if (stream.signatureParameter != null) {
          final sigParam = stream.signatureParameter!;
          final sig = stream.signature!;
          final decoded = solvedChallenges[sig];
          if (decoded != null) {
            url = url.setQueryParam(sigParam, decoded);
            _logger.fine(
                'Decoded signature for stream itag $itag. $sigParam -> $decoded}');
          } else {
            // Fallback to individual solving if bulk solving didn't provide result
            try {
              final individualDecoded = await solver.solve(
                  watchPage.sourceUrl!, JSChallengeType.sig, sig);
              url = url.setQueryParam(sigParam, individualDecoded);
              _logger.fine(
                  'Decoded signature for stream itag $itag (individual). $sigParam -> $individualDecoded}');
            } catch (e) {
              _logger
                  .warning('Could not decipher signature using JS solver: $e');
            }
          }
        }
      }

      final contentLength = stream.contentLength ??
          (selectedLengthDiscovery
              ? 0
              : await _httpClient.getContentLength(url,
                  headers: headers, validate: false)) ??
          0;

      if (contentLength <= 0 &&
          !(selectedLengthDiscovery &&
              (stream.source == StreamSource.muxed ||
                  stream.source == StreamSource.adaptive))) {
        continue;
      }

      final container = StreamContainer.parse(stream.container!);
      final fileSize = FileSize(contentLength);
      final bitrate = Bitrate(stream.bitrate!);

      final audioCodec = stream.audioCodec;
      final videoCodec = stream.videoCodec;

      // HLS
      if (stream.source == StreamSource.hls) {
        if (stream.audioOnly) {
          yield HlsAudioStreamInfo(
            videoId ?? watchPage!.videoId,
            itag,
            url,
            container,
            fileSize,
            bitrate,
            '',
            '',
            stream.codec,
          );
          continue;
        }

        final framerate = Framerate(stream.framerate ?? 24);
        // TODO: Implement quality from itag
        final videoQuality = VideoQualityUtil.fromLabel(stream.qualityLabel);
        final videoWidth = stream.videoWidth;
        final videoHeight = stream.videoHeight;
        final videoResolution = videoWidth != null && videoHeight != null
            ? VideoResolution(videoWidth, videoHeight)
            : videoQuality.toVideoResolution();

        if (stream.videoOnly) {
          yield HlsVideoStreamInfo(
            videoId ?? watchPage!.videoId,
            itag,
            url,
            container,
            fileSize,
            bitrate,
            videoCodec ?? '',
            videoQuality.qualityString,
            videoQuality,
            videoResolution,
            framerate,
            stream.codec,
            stream.audioItag,
          );
        } else {
          yield HlsMuxedStreamInfo(
            videoId ?? watchPage!.videoId,
            itag,
            url,
            container,
            fileSize,
            bitrate,
            audioCodec!,
            videoCodec!,
            videoQuality.qualityString,
            videoQuality,
            videoResolution,
            framerate,
            stream.codec,
          );
        }
        continue;
      }

      // Muxed or Video-only
      if (!videoCodec.isNullOrWhiteSpace) {
        final framerate = Framerate(stream.framerate ?? 24);
        // TODO: Implement quality from itag
        final videoQuality = VideoQualityUtil.fromLabel(stream.qualityLabel);

        final videoWidth = stream.videoWidth;
        final videoHeight = stream.videoHeight;
        final videoResolution = videoWidth != null && videoHeight != null
            ? VideoResolution(videoWidth, videoHeight)
            : videoQuality.toVideoResolution();

        // Muxed
        if (!audioCodec.isNullOrWhiteSpace &&
            stream.source != StreamSource.adaptive) {
          assert(stream.audioTrack == null);
          yield MuxedStreamInfo(
            videoId ?? watchPage!.videoId,
            itag,
            url,
            container,
            fileSize,
            bitrate,
            audioCodec!,
            videoCodec!,
            videoQuality.qualityString,
            videoQuality,
            videoResolution,
            framerate,
            stream.codec,
          );
          continue;
        }

        // Video only
        yield VideoOnlyStreamInfo(
          videoId ?? watchPage!.videoId,
          itag,
          url,
          container,
          fileSize,
          bitrate,
          videoCodec!,
          videoQuality.qualityString,
          videoQuality,
          videoResolution,
          framerate,
          stream.fragments ?? const [],
          stream.codec,
        );
        continue;
        // Audio-only
      } else if (!audioCodec.isNullOrWhiteSpace) {
        yield AudioOnlyStreamInfo(
            videoId ?? watchPage!.videoId,
            itag,
            url,
            container,
            fileSize,
            bitrate,
            audioCodec!,
            stream.qualityLabel!,
            stream.fragments ?? const [],
            stream.codec,
            stream.audioTrack);
      } else {
        throw YoutubeExplodeException('Could not extract stream codec');
      }
    }
  }
}
