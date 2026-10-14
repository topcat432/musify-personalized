import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:rxdart/rxdart.dart';

class SpotifyImportFileReader {
  const SpotifyImportFileReader._();
  static const readTimeout = Duration(seconds: 20);
  static const cleanupTimeout = Duration(seconds: 1);

  static Future<Uint8List> read(
    PlatformFile file, {
    Future<void>? cancelled,
    int? maxBytes,
  }) async {
    final limit =
        maxBytes ??
        ((file.name.toLowerCase().endsWith('.json') ||
                file.name.toLowerCase().endsWith('.zip'))
            ? SpotifyCsvImporter.maxJsonBytes
            : null);
    void check(int size) {
      if (limit != null && size > limit) {
        throw SpotifyImportException(
          maxBytes == null
              ? 'JSON and ZIP song lists must be 8 MiB or smaller.'
              : 'The incoming song list must be 8 MiB or smaller.',
        );
      }
    }

    check(file.size);
    if (file.bytes != null) {
      check(file.bytes!.length);
      return file.bytes!;
    }
    var stream =
        file.readStream ??
        (file.path == null ? null : File(file.path!).openRead());
    if (stream == null)
      throw const SpotifyImportException(
        'Musify could not read the selected file.',
      );
    var wasCancelled = false;
    if (cancelled != null) {
      stream = stream.takeUntil(
        cancelled.asStream().map((_) {
          wasCancelled = true;
          return true;
        }),
      );
    }
    final iterator = StreamIterator<List<int>>(stream);
    final bytes = BytesBuilder(copy: false);
    final clock = Stopwatch()..start();
    var completedRead = false;
    try {
      while (true) {
        final remaining = readTimeout - clock.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('Read deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        check(bytes.length + iterator.current.length);
        bytes.add(iterator.current);
      }
      if (wasCancelled)
        throw const SpotifyImportException('File selection was cancelled.');
      completedRead = true;
      return bytes.takeBytes();
    } on TimeoutException {
      throw const SpotifyImportException(
        'Reading this file timed out. Choose a local song list and try again.',
      );
    } finally {
      try {
        // cancel detaches this subscription immediately; provider cleanup can
        // finish later. timeout observes late errors without adopting its work.
        await iterator.cancel().timeout(cleanupTimeout);
      } on TimeoutException {
        if (completedRead) {
          throw const SpotifyImportException(
            'Stopping this file read timed out. Choose a local song list and try again.',
          );
        }
      } catch (error, stack) {
        // Do not replace the original read/timeout/cancellation failure.
        if (completedRead) Error.throwWithStackTrace(error, stack);
      }
    }
  }
}
