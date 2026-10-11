// Copyright Musify Personalized contributors.
// Licensed under the Apache License, Version 2.0; see ../LICENSE.
import 'dart:async';
import 'dart:io';

/// Preserves a response failure's cause without serializing exception messages,
/// URLs, response headers or bodies. A close failure can retain its predecessor.
class StreamAudioResponseFailure {
  StreamAudioResponseFailure({
    required this.phase,
    required this.cause,
    required this.originStack,
    required this.writtenBytes,
    required this.expectedBytes,
    this.preceding,
  });
  final String phase;
  final Object cause;
  final StackTrace originStack;
  final int writtenBytes;
  final int? expectedBytes;
  final StreamAudioResponseFailure? preceding;

  Map<String, Object?> get diagnostic => {
        'phase': phase,
        'writtenBytes': writtenBytes,
        'expectedBytes': expectedBytes,
        'causeType': cause.runtimeType.toString(),
        if (preceding != null) 'preceding': preceding!.diagnostic,
      };

  @override
  String toString() => 'StreamAudioResponseFailure $diagnostic';
}

/// Own both stream and HTTP completion, including a truncated or cancelled read.
/// A short response stays a failed response; no padding or success is invented.
Future<void> writeStreamAudioResponse(
    Stream<List<int>> stream, HttpResponse response,
    {void Function(StreamAudioResponseFailure)? onFailure}) async {
  final ended = Completer<void>();
  var written = 0;
  StreamAudioResponseFailure? firstFailure;
  final expected = response.contentLength < 0 ? null : response.contentLength;
  void report(String phase, Object error, StackTrace stack) {
    final failure = StreamAudioResponseFailure(
      phase: phase,
      cause: error,
      originStack: stack,
      writtenBytes: written,
      expectedBytes: expected,
      preceding: firstFailure,
    );
    firstFailure ??= failure;
    try {
      onFailure?.call(failure);
    } catch (_) {
      // Reporting must not replace the original stream/HTTP failure.
    }
  }

  void end() {
    if (!ended.isCompleted) ended.complete();
  }

  void fail(String phase, Object error, StackTrace stack) {
    report(phase, error, stack);
    if (!ended.isCompleted) ended.completeError(error, stack);
  }

  // Register the error consumer before writing: close() and done can both
  // report the same content-length mismatch or client disconnect.
  final responseDone = response.done.then<void>((_) => end(),
      onError: (Object error, StackTrace stack) {
    report('responseDone', error, stack);
    end();
  });
  final subscription = stream.listen((bytes) {
    try {
      response.add(bytes);
      written += bytes.length;
    } catch (error, stack) {
      fail('write', error, stack);
    }
  },
      onError: (Object error, StackTrace stack) => fail('source', error, stack),
      onDone: end,
      cancelOnError: true);
  try {
    await ended.future;
    await response.close();
  } catch (error, stack) {
    if (firstFailure == null || !identical(firstFailure!.cause, error)) {
      report('close', error, stack);
    }
    // The native client must observe the incomplete response. Closing can
    // itself throw when fewer bytes were written than promised; consume it.
    try {
      await response.close();
    } catch (_) {}
  } finally {
    await subscription.cancel();
    await responseDone;
  }
}
