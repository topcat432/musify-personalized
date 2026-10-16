import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_zip_importer.dart';

class SpotifyAndroidDeflateDecoder {
  const SpotifyAndroidDeflateDecoder._();
  static const channel = MethodChannel(
    'com.topcat432.musifypersonalized/strict_deflate',
  );
  static int _nextId = 0;

  static Future<SpotifyDeflateResult> decode(
    Uint8List bytes,
    int size,
    Future<void>? cancelled,
  ) async {
    if (bytes.length > SpotifyZipImporter.maxBytes ||
        size < 0 ||
        size > SpotifyZipImporter.maxBytes) {
      throw const SpotifyImportException('ZIP size limit exceeded.');
    }
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}-${Random.secure().nextInt(0x7fffffff)}';
    var done = false;
    var stopped = false;
    var cancelSent = false;
    Timer? deadline;
    final response = Completer<Map<String, dynamic>?>();
    Future<void> requestCancel() async {
      if (cancelSent) return;
      cancelSent = true;
      try {
        await channel
            .invokeMethod<void>('cancel', {'id': id})
            .timeout(const Duration(seconds: 1));
      } on Exception {
        // Engine cleanup/native deadline remain required if acknowledgment is lost.
      }
    }

    void endLocally(SpotifyImportException error) {
      if (done || response.isCompleted) return;
      stopped = true;
      unawaited(requestCancel());
      response.completeError(error);
    }

    try {
      final pending = channel.invokeMapMethod<String, dynamic>('inflate', {
        'id': id,
        'bytes': bytes,
        'size': size,
      });
      // Both paths remain observed after local completion. A late reply/error
      // belongs to the old engine request and cannot resume the import.
      unawaited(
        pending.then<void>(
          (value) {
            if (!done && !response.isCompleted) response.complete(value);
          },
          onError: (Object error, StackTrace stack) {
            if (!done && !response.isCompleted)
              response.completeError(error, stack);
          },
        ),
      );
      if (cancelled != null) {
        unawaited(
          cancelled.then(
            (_) => endLocally(
              const SpotifyImportException('File selection was cancelled.'),
            ),
          ),
        );
      }
      deadline = Timer(
        const Duration(seconds: 20),
        () => endLocally(
          const SpotifyImportException(
            'ZIP decoding timed out. Choose the song-list file directly and try again.',
          ),
        ),
      );
      final result = await response.future;
      if (stopped)
        throw const SpotifyImportException('File selection was cancelled.');
      if (result == null ||
          result['bytes'] is! Uint8List ||
          result['finished'] != true ||
          result['consumedBytes'] != bytes.length) {
        throw const SpotifyImportException(
          'The ZIP compressed stream could not be verified.',
        );
      }
      final decoded = result['bytes'] as Uint8List;
      if (decoded.length != size ||
          decoded.length > SpotifyZipImporter.maxBytes) {
        throw const SpotifyImportException(
          'The ZIP decoded size does not match.',
        );
      }
      return SpotifyDeflateResult(
        bytes: decoded,
        consumedBytes: bytes.length,
        finished: true,
      );
    } on MissingPluginException {
      throw const SpotifyImportException(
        'Compressed ZIP is unavailable on this platform. Choose an uncompressed (stored) ZIP or select its CSV, TSV or JSON file directly.',
      );
    } on PlatformException {
      throw const SpotifyImportException(
        'ZIP decoding was cancelled or could not be verified within its limits.',
      );
    } finally {
      done = true;
      deadline?.cancel();
    }
  }
}
