// Synthetic lyrics and owned local audio-session acceptance only.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';

class OwnedLyricsRehearsal extends StatefulWidget {
  const OwnedLyricsRehearsal({super.key});
  @override
  State<OwnedLyricsRehearsal> createState() => _OwnedLyricsRehearsalState();
}

class _OwnedLyricsRehearsalState extends State<OwnedLyricsRehearsal> {
  final controller = FlipCardController();
  String selected = 'A';
  int lookups = 0;
  bool refreshedRecordingB = false;
  String? proof;

  Future<String?> loadLyrics(String artist, String title) async {
    lookups++;
    final text = selected == 'C' ? null : 'Owned recording $selected lyric';
    return text;
  }

  Future<void> recordProof() async {
    final key = jsonDecode(lastFetchedLyrics!) as List;
    if (selected != 'B' ||
        !refreshedRecordingB ||
        lookups != 2 ||
        lyrics.value != 'Owned recording B lyric' ||
        key.first != 'owned-lyrics-B') {
      throw StateError('Owned recording cache verification failed');
    }
    final path = '$applicationDirPath/lyrics-native-proof.json';
    await File(path).writeAsString(
      jsonEncode({
        'sourceSha': const String.fromEnvironment('GIT_SHA'),
        'selectedRecording': 'owned-lyrics-B',
        'sameArtistTitleDifferentRecordingLookups': lookups,
        'cachedRebuildDidNotRefetch': true,
        'providerLyricsRequested': false,
        'providerRecordingProvenanceVerified': false,
      }),
      flush: true,
    );
    if (mounted) setState(() => proof = 'Owned lyrics cache PASS');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owned lyrics rehearsal')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Selected owned recording $selected'),
        const Text(
          'Shared owned title / Owned lyric artist. Synthetic content.',
        ),
        FilledButton(
          onPressed: () => setState(() => selected = 'B'),
          child: const Text('Use owned recording B'),
        ),
        FilledButton(
          onPressed: controller.flipcard,
          child: const Text('Show owned lyrics'),
        ),
        FilledButton(
          onPressed: () => setState(() {
            if (selected == 'B') refreshedRecordingB = true;
          }),
          child: const Text('Refresh owned artwork'),
        ),
        FilledButton(
          onPressed: recordProof,
          child: const Text('Record owned lyrics proof'),
        ),
        FilledButton(
          onPressed: () => setState(() => selected = 'C'),
          child: const Text('Use unavailable owned recording'),
        ),
        if (proof != null) Text(proof!),
        Center(
          child: NowPlayingArtwork(
            size: MediaQuery.sizeOf(context),
            metadata: MediaItem(
              id: 'owned-lyrics-$selected',
              title: 'Shared owned title',
              artist: 'Owned lyric artist',
              extras: {'ytid': 'owned-lyrics-$selected'},
            ),
            lyricsController: controller,
            lyricsLoader: loadLyrics,
          ),
        ),
      ],
    ),
  );
}

class OwnedEqualizerRehearsal extends StatefulWidget {
  const OwnedEqualizerRehearsal({super.key});
  @override
  State<OwnedEqualizerRehearsal> createState() =>
      _OwnedEqualizerRehearsalState();
}

class _OwnedEqualizerRehearsalState extends State<OwnedEqualizerRehearsal> {
  String state = 'No source loaded';
  Future<void> loadSource() async {
    const dataBytes = 16000;
    final bytes = ByteData(44 + dataBytes);
    void text(int offset, String value) {
      for (var i = 0; i < value.length; i++)
        bytes.setUint8(offset + i, value.codeUnitAt(i));
    }

    text(0, 'RIFF');
    bytes.setUint32(4, 36 + dataBytes, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, 8000, Endian.little);
    bytes.setUint32(28, 16000, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    text(36, 'data');
    bytes.setUint32(40, dataBytes, Endian.little);
    final file = File('$applicationDirPath/owned-equalizer.wav');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    final duration = await audioHandler.audioPlayer.setFilePath(file.path);
    if (duration == null || duration.inMilliseconds != 1000)
      throw StateError('Owned WAV did not load');
    if (mounted) setState(() => state = 'Owned audio session loaded: 1000 ms');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owned equalizer session')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(state),
        const Text(
          'Silent synthetic local WAV. No playback/provider/audibility claim.',
        ),
        FilledButton(
          onPressed: loadSource,
          child: const Text('Load owned audio session'),
        ),
        FilledButton(
          onPressed: () => context.push('/settings/equalizer'),
          child: const Text('Open owned equalizer'),
        ),
      ],
    ),
  );
}
