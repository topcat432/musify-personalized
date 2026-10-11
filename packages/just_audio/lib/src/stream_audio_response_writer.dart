// Copyright Musify Personalized contributors.
// Licensed under the Apache License, Version 2.0; see ../LICENSE.
import 'dart:async';
import 'dart:io';

/// Own both stream and HTTP completion, including a truncated or cancelled read.
/// A short response stays a failed response; no padding or success is invented.
Future<void> writeStreamAudioResponse(
    Stream<List<int>> stream, HttpResponse response) async {
  final ended = Completer<void>();
  void end() {
    if (!ended.isCompleted) ended.complete();
  }

  void fail(Object error, StackTrace stack) {
    if (!ended.isCompleted) ended.completeError(error, stack);
  }

  // Register the error consumer before writing: close() and done can both
  // report the same content-length mismatch or client disconnect.
  final responseDone = response.done.then<void>((_) => end(),
      onError: (Object error, StackTrace stack) => end());
  final subscription = stream.listen((bytes) {
    try {
      response.add(bytes);
    } catch (error, stack) {
      fail(error, stack);
    }
  }, onError: fail, onDone: end, cancelOnError: true);
  try {
    await ended.future;
    await response.close();
  } catch (_) {
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
