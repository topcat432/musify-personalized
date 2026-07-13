/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:just_audio/just_audio.dart';

class ReviewSprintAudioState {
  const ReviewSprintAudioState({
    required this.playing,
    required this.completed,
  });

  final bool playing;
  final bool completed;
}

abstract interface class ReviewSprintAudioPlayer {
  Stream<ReviewSprintAudioState> get stateStream;

  Future<void> setUrl(String url);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> dispose();
}

class JustAudioReviewSprintPlayer implements ReviewSprintAudioPlayer {
  JustAudioReviewSprintPlayer({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<ReviewSprintAudioState> get stateStream =>
      _player.playerStateStream.map(
        (state) => ReviewSprintAudioState(
          playing: state.playing,
          completed: state.processingState == ProcessingState.completed,
        ),
      );

  @override
  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
