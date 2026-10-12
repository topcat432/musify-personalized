// Isolated synthetic data with the real Musify router, shell and mini-player.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show Musify, audioHandler;
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() => runOwnedShellRehearsal();

Future<void> runOwnedShellRehearsal({
  String namespace = 'acceptance_mini_v1',
  Map<String, dynamic> initialPreferences = const {},
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw StateError('Owned Android rehearsal only');
  final normal = await getApplicationDocumentsDirectory();
  if (!RegExp(r'^acceptance_[a-z_]+_v1$').hasMatch(namespace))
    throw StateError('Invalid owned namespace');
  final scratch = Directory('${normal.path}/$namespace');
  await scratch.create(recursive: true);
  Hive.init(scratch.path);
  for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.openBox(name);
  }
  applicationDirPath = scratch.path;
  await FilePaths.ensureDirectoriesExist();
  final art = File('${scratch.path}/owned-mini-art.png');
  if (!await art.exists()) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFF9B4F2A),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await art.writeAsBytes(png!.buffer.asUint8List(), flush: true);
    image.dispose();
    picture.dispose();
  }
  final records = <Map<String, dynamic>>[];
  for (final seconds in [70, 8]) {
    final file = File('${scratch.path}/owned-mini-$seconds.wav');
    if (!await file.exists()) {
      final dataBytes = 16000 * seconds;
      final bytes = ByteData(44 + dataBytes);
      void text(int offset, String value) {
        for (var i = 0; i < value.length; i++) {
          bytes.setUint8(offset + i, value.codeUnitAt(i));
        }
      }

      text(0, 'RIFF');
      bytes.setUint32(4, 36 + dataBytes, Endian.little);
      text(8, 'WAVE');
      text(12, 'fmt ');
      bytes
        ..setUint32(16, 16, Endian.little)
        ..setUint16(20, 1, Endian.little)
        ..setUint16(22, 1, Endian.little)
        ..setUint32(24, 8000, Endian.little)
        ..setUint32(28, 16000, Endian.little)
        ..setUint16(32, 2, Endian.little)
        ..setUint16(34, 16, Endian.little);
      text(36, 'data');
      bytes.setUint32(40, dataBytes, Endian.little);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    records.add({
      'ytid': 'owned-mini-$seconds',
      'title': 'Owned miniature recording $seconds',
      'artist': 'Synthetic layout fixture',
      'duration': seconds,
      'audioPath': file.path,
      'artworkPath': art.path,
      'image': Uri.file(art.path).toString(),
      'sourceType': 'owned_fixture',
    });
  }
  final user = Hive.box('user');
  if (!user.containsKey('miniSeeded')) {
    final lists = [
      for (var i = 1; i <= 8; i++)
        {
          'ytid': 'custom_owned_mini_$i',
          'title': 'Owned mini playlist $i',
          'list': records,
          'source': 'owned_fixture',
        },
    ];
    await Hive.box('settings').putAll({
      'offlineMode': true,
      'wrappedEnabled': false,
      'shouldWeCheckUpdates': true,
      'themeIndex': 2,
      'useSystemColor': false,
      'usePureBlackColor': false,
      'predictiveBack': true,
      'languageCode': 'en',
      'playNextSongAutomatically': false,
      ...initialPreferences,
    });
    await user.putAll({'miniSeeded': true, 'likedSongs': records});
    await Hive.box(
      'userNoBackup',
    ).putAll({'offlineSongs': records, 'offlinePlaylists': lists});
  }
  reloadSongLibraryStateFromStorage();
  reloadPlaylistLibraryStateFromStorage();
  audioHandler = await AudioService.init(
    builder: MusifyAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.gokadzev.musify',
      androidNotificationChannelName: 'Musify',
      androidNotificationIcon: 'drawable/ic_launcher_foreground',
    ),
  );
  final queueLoad = audioHandler.addPlaylistToQueue(
    records,
    replace: true,
    startIndex: 0,
  );
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!audioHandler.audioPlayer.playing &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (!audioHandler.audioPlayer.playing)
    throw StateError('Owned local queue did not load');
  await audioHandler.pause();
  await queueLoad;
  await File('${scratch.path}/mini-native-proof.json').writeAsString(
    jsonEncode({
      'sourceSha': const String.fromEnvironment('GIT_SHA'),
      'description': 'Owned production-shell mini rehearsal',
      'nativeQueueSize': audioHandler.queue.value.length,
      'paused': !audioHandler.audioPlayer.playing,
      'durationMs': audioHandler.audioPlayer.duration?.inMilliseconds,
      'localSyntheticFilesOnly': true,
      'physicalOutputVerified': false,
    }),
    flush: true,
  );
  NavigationManager.instance;
  NavigationManager.router.go('/library');
  runApp(const Musify());
}
