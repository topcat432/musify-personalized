// Native rehearsal only. Build this entrypoint explicitly on an owned debug AVD.
// It never opens the normal app's Hive directory or contacts a provider.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:musify/main.dart' as app;
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/online_audio_source.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:path_provider/path_provider.dart';

const _agent = 'Musify-Owned-Native-Fixture/1.0';
const _longId = 'owned-transport-long';
const _nextId = 'owned-transport-next';
const _runId = String.fromEnvironment('OWNED_RUN_ID', defaultValue: '54c3ed85');
const _sourceSha = String.fromEnvironment(
  'GIT_SHA',
  defaultValue: 'unattributed',
);
final _events = <Map<String, Object?>>[];
final _ranges = <Map<String, Object?>>[];
final _sources = <_ObservedSource>[];
Object? _failure;
String _phase = 'bootstrap';

void _event(String event, Map<String, Object?> details) {
  final record = <String, Object?>{
    'event': event,
    'phase': _phase,
    'utc': DateTime.now().toUtc().toIso8601String(),
    ...details,
  };
  _events.add(record);
  debugPrint('OWNED_TRANSPORT ${jsonEncode(record)}');
}

Future<void> _until(
  bool Function() predicate,
  String step, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final clock = Stopwatch()..start();
  while (!predicate()) {
    if (_failure != null)
      throw StateError('Native owned transport failed: $_failure');
    if (clock.elapsed > timeout)
      throw TimeoutException('Owned step timed out: $step');
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  if (_failure != null)
    throw StateError('Native owned transport failed: $_failure');
}

class _OwnedClient extends http.BaseClient {
  _OwnedClient(this.file, this.label, this.length);
  final File file;
  final String label;
  final int length;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final match = RegExp(
      r'^bytes=(\d+)-(\d+)$',
    ).firstMatch(request.headers['Range'] ?? '');
    if (closed ||
        request.method != 'GET' ||
        request.followRedirects ||
        request.headers['User-Agent'] != _agent ||
        match == null ||
        request.headers.length != 2 ||
        request.url.host != 'owned.fixture.googlevideo.com') {
      throw StateError('Owned request contract changed.');
    }
    final from = int.parse(match[1]!);
    final last = int.parse(match[2]!);
    if (from < 0 ||
        last >= length ||
        last < from ||
        last - from + 1 > 256 * 1024) {
      throw StateError('Owned finite range is invalid.');
    }
    final record = <String, Object?>{
      'source': label,
      'phase': _phase,
      'from': from,
      'lastInclusive': last,
      'expected': last - from + 1,
      'delivered': 0,
      'complete': false,
    };
    _ranges.add(record);
    Stream<List<int>> bytes() async* {
      final reader = await file.open();
      try {
        await reader.setPosition(from);
        var left = last - from + 1;
        while (left > 0 && !closed) {
          final chunk = await reader.read(min(left, 8192));
          if (chunk.isEmpty)
            throw StateError('Owned fixture truncated on disk.');
          left -= chunk.length;
          record['delivered'] = (record['delivered'] as int) + chunk.length;
          yield chunk;
        }
        record['complete'] = left == 0;
      } finally {
        await reader.close();
      }
    }

    return http.StreamedResponse(
      bytes(),
      206,
      contentLength: last - from + 1,
      headers: {
        'content-range': 'bytes $from-$last/$length',
        'content-type': 'audio/webm',
      },
    );
  }

  @override
  void close() {
    closed = true;
  }
}

class _ObservedSource extends GoogleVideoByteSource {
  _ObservedSource(
    super.uri, {
    required super.sourceLength,
    required this.label,
    required super.clientFactory,
    super.tag,
    super.onUnavailable,
  }) : super(
         requestHeaders: const {'User-Agent': _agent},
         onDiagnostic: (diagnostic) {
           _event('diagnostic', diagnostic);
           if (diagnostic['stage'] == 'origin') _failure = diagnostic;
         },
       );
  final String label;
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final response = await super.request(start, end);
    _event('native-request', {
      'source': label,
      'start': start,
      'endExclusive': end,
      'offset': response.offset,
      'contentLength': response.contentLength,
      'sourceLength': response.sourceLength,
    });
    return response;
  }
}

class _OwnedHandler extends MusifyAudioHandler {
  _OwnedHandler(this.inputs)
    : super(
        sourceFactory: (url, {tag, onUnavailable}) {
          final uri = Uri.parse(url);
          final label = uri.queryParameters['fixture']!;
          final input = inputs[label]!;
          final source = _ObservedSource(
            uri,
            sourceLength: input.lengthSync(),
            label: label,
            tag: tag,
            onUnavailable: onUnavailable,
            clientFactory: () => _OwnedClient(input, label, input.lengthSync()),
          );
          _sources.add(source);
          _event('source-loaded', {
            'source': label,
            'bytes': input.lengthSync(),
          });
          return source;
        },
      );
  final Map<String, File> inputs;
  @override
  Future<AudioSource?> buildAudioSource(Map song, String url, bool isOffline) {
    final label = song['ytid'].toString();
    final length = inputs[label]!.lengthSync();
    return super.buildAudioSource(
      song,
      'https://owned.fixture.googlevideo.com/media?fixture=$label&clen=$length&mime=audio%2Fwebm',
      false,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Owned native transport rehearsal')),
      ),
    ),
  );
  final documents = await getApplicationDocumentsDirectory();
  final scratch = Directory('${documents.path}/native-owned-transport-$_runId');
  await scratch.create(recursive: true);
  final report = File('${scratch.path}/report.json');
  _OwnedHandler? handler;
  Timer? ticker;
  final subscriptions = <StreamSubscription<dynamic>>[];
  var success = false;
  final inputProofs = <String, Object?>{};
  try {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(_runId))
      throw StateError('Invalid owned run ID.');
    final inputs = <String, File>{
      _longId: File(
        '${documents.path}/native-owned-inputs/owned-long-opus.webm',
      ),
      _nextId: File(
        '${documents.path}/native-owned-inputs/owned-next-opus.webm',
      ),
    };
    for (final entry in inputs.entries) {
      if (!await entry.value.exists())
        throw StateError('Owned fixture missing: ${entry.key}');
      inputProofs[entry.key] = {
        'bytes': await entry.value.length(),
        'sha256': (await sha256.bind(entry.value.openRead()).first).toString(),
      };
    }
    if (inputs[_longId]!.lengthSync() <= 1024 * 1024)
      throw StateError('Long fixture must exceed 1 MiB.');
    Hive.init('${scratch.path}/hive');
    for (final name in ['user', 'settings', 'userNoBackup', 'cache']) {
      await Hive.openBox(name);
    }
    await Hive.box('settings').putAll({
      'offlineMode': true,
      'sponsorBlockSupport': false,
      'playNextSongAutomatically': false,
      'wrappedEnabled': false,
      'shuffleEnabled': false,
      'repeatMode': AudioServiceRepeatMode.none.index,
    });
    applicationDirPath = scratch.path;
    reloadSettingsStateFromStorage();
    app.audioHandler = handler = _OwnedHandler(inputs);
    final player = handler.audioPlayer;
    await player.setVolume(
      0,
    ); // Decoding/AudioTrack remain real; audibility is not asserted.
    subscriptions.addAll([
      player.errorStream.listen((error) {
        _failure = {'nativeCode': error.code};
        _event('native-error', {'nativeCode': error.code});
      }),
      player.processingStateStream.listen((state) {
        _event('processing-state', {
          'state': state.name,
          'source': handler!.currentSong?['ytid'],
          'positionMs': player.position.inMilliseconds,
        });
      }),
    ]);
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _event('progress', {
        'source': handler!.currentSong?['ytid'],
        'positionMs': player.position.inMilliseconds,
        'bufferedMs': player.bufferedPosition.inMilliseconds,
        'durationMs': player.duration?.inMilliseconds,
        'playing': player.playing,
        'state': player.processingState.name,
      });
    });
    Map<String, dynamic> song(String id, int seconds) => {
      'id': id,
      'ytid': id,
      'title': id,
      'artist': 'Owned generated fixture',
      'audioPath': inputs[id]!.path,
      'highResImage': '',
      'lowResImage': '',
      'duration': seconds,
      'isLive': false,
    };
    _phase = 'seek-tail';
    await handler.addPlaylistToQueue(
      [song(_longId, 70)],
      replace: true,
      startIndex: 0,
    );
    await _until(
      () => player.playing && player.position >= const Duration(seconds: 2),
      'initial decode',
    );
    await handler.pause();
    await handler.seek(const Duration(seconds: 35));
    await handler.play();
    await _until(
      () => player.position >= const Duration(seconds: 37),
      'mid seek',
    );
    _event('seek-verified', {
      'targetSeconds': 35,
      'positionMs': player.position.inMilliseconds,
    });
    await handler.pause();
    await handler.seek(const Duration(seconds: 68));
    await handler.play();
    await _until(
      () => player.processingState == ProcessingState.completed,
      'tail completion',
    );
    _event('tail-completed', {
      'positionMs': player.position.inMilliseconds,
      'durationMs': player.duration?.inMilliseconds,
    });
    await handler.stop();

    _phase = 'full-natural-advance';
    await handler.addPlaylistToQueue(
      [song(_longId, 70), song(_nextId, 8)],
      replace: true,
      startIndex: 0,
    );
    await _until(
      () => player.playing && player.position >= const Duration(seconds: 2),
      'full first decode',
    );
    await _until(
      () => handler!.currentSong?['ytid'] == _nextId,
      'natural next source',
      timeout: const Duration(seconds: 90),
    );
    await _until(
      () => player.playing && player.position >= const Duration(seconds: 1),
      'next decode',
    );
    _event('natural-next-verified', {
      'source': handler.currentSong?['ytid'],
      'positionMs': player.position.inMilliseconds,
    });
    await _until(
      () => player.processingState == ProcessingState.completed,
      'next completion',
    );
    _event('next-completed', {
      'positionMs': player.position.inMilliseconds,
      'durationMs': player.duration?.inMilliseconds,
    });
    if (_sources.any((source) => source.failure != null))
      throw StateError('Owned source failed.');
    final fullRanges = _ranges
        .where(
          (row) =>
              row['phase'] == 'full-natural-advance' &&
              row['source'] == _longId,
        )
        .toList();
    if (!fullRanges.any((row) => (row['from'] as int) >= 1024 * 1024) ||
        !fullRanges.any(
          (row) =>
              row['lastInclusive'] == inputs[_longId]!.lengthSync() - 1 &&
              row['complete'] == true,
        )) {
      throw StateError('No completed finite tail beyond 1 MiB.');
    }
    success = true;
    _event('pass', {
      'fullFirstDurationSeconds': 70,
      'fullNextDurationSeconds': 8,
      'naturalAdvancement': true,
      'providerRequests': 0,
      'audibilityAsserted': false,
    });
  } catch (error) {
    _failure ??= {
      'type': error.runtimeType.toString(),
      if (error is StateError) 'reason': error.message,
      if (error is TimeoutException) 'reason': error.message,
    };
    _event('fail', {'failure': _failure});
  } finally {
    ticker?.cancel();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    if (handler != null) {
      await handler.stop();
      await handler.audioPlayer.dispose();
    }
    await Hive.close();
    await report.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'sourceSha': _sourceSha,
        'runId': _runId,
        'success': success,
        'failure': _failure,
        'inputs': inputProofs,
        'events': _events,
        'ranges': _ranges,
        'providerRequests': 0,
        'hiveIsolation': true,
        'audibilityAsserted': false,
      }),
    );
    _event('report-saved', {'success': success, 'runId': _runId});
  }
}
