// Owned process-stop probes. Never imported by normal startup.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:path_provider/path_provider.dart';

final ownedBody = List<int>.generate(8192, (index) => index % 251);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw StateError('Owned Android rehearsal only');
  final normal = await getApplicationDocumentsDirectory();
  final root = Directory('${normal.path}/acceptance_offline_boundaries_v1');
  await root.create(recursive: true);
  Hive.init(root.path);
  for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.openBox(name);
  }
  applicationDirPath = root.path;
  await FilePaths.ensureDirectoriesExist();
  final user = Hive.box('user');
  if (!user.containsKey('ownedBoundarySeeded')) {
    final keeper = {
      'ytid': 'owned-boundary-keeper',
      'title': 'Owned retained download',
      'audioPath': FilePaths.getAudioPath('owned-boundary-keeper'),
    };
    await File(keeper['audioPath']!).writeAsBytes([7, 8, 9], flush: true);
    await File(
      FilePaths.getAudioPath('owned-boundary-unknown'),
    ).writeAsBytes([5, 4, 3, 2], flush: true);
    await Hive.box('userNoBackup').putAll({
      'offlineSongs': [keeper],
      'unrelatedOffline': {'keep': true},
    });
    await Hive.box('settings').put('ownedPreference', 'retained');
    await Hive.box('cache').put('ownedCache', {
      'retain': [1, 2, 3],
    });
    await user.putAll({
      'ownedBoundarySeeded': true,
      'likedSongs': [
        {'ytid': 'owned-boundary-like'},
      ],
      'playlistMemberships': ['owned-boundary-member'],
    });
    for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
      await Hive.box(name).flush();
    }
  }
  userOfflineSongs.value = List<dynamic>.from(
    Hive.box('userNoBackup').get('offlineSongs'),
  );
  runApp(const MaterialApp(home: OwnedBoundaryPage()));
}

class OwnedBoundaryPage extends StatefulWidget {
  const OwnedBoundaryPage({super.key});
  @override
  State<OwnedBoundaryPage> createState() => _OwnedBoundaryPageState();
}

class _OwnedBoundaryPageState extends State<OwnedBoundaryPage> {
  String status = 'Ready';
  @override
  void initState() {
    super.initState();
    unawaited(runCommand());
  }

  Future<void> proof(
    Map<String, dynamic> command,
    String state, {
    bool? success,
  }) async {
    final files = <String, int>{};
    final audio = Directory(FilePaths.getAudioPath('owned-placeholder')).parent;
    for (final file in audio.listSync().whereType<File>()) {
      files[file.uri.pathSegments.last] = await file.length();
    }
    final record = {
      'sourceSha': const String.fromEnvironment('GIT_SHA'),
      'command': command,
      'state': state,
      'success': success,
      'registry': Hive.box('userNoBackup').get('offlineSongs'),
      'notifierIds': userOfflineSongs.value.map((row) => row['ytid']).toList(),
      'completionMarkers': Hive.box(
        'user',
      ).get('boundaryCompletions', defaultValue: <String>[]),
      'files': files,
      'namespace': 'acceptance_offline_boundaries_v1',
      'providerRequested': false,
    };
    await File(
      '$applicationDirPath/proof-${command['nonce']}-$state.json',
    ).writeAsString(jsonEncode(record), flush: true);
    if (mounted) setState(() => status = '$state ${command['id']}');
  }

  Future<void> runCommand() async {
    final file = File('$applicationDirPath/command.json');
    if (!await file.exists()) return;
    final command = Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
    final id = command['id'] as String;
    final nonce = command['nonce'] as String;
    if (!RegExp(r'^owned-boundary-[a-zA-Z]+$').hasMatch(id) ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(nonce))
      throw StateError('Invalid owned command');
    await file.rename('$applicationDirPath/consumed-$nonce.json');
    await proof(command, 'reopened');
    if (command['mode'] == 'reopen') return;
    final boundary = OfflineCommitBoundary.values.byName(
      command['boundary'] as String,
    );
    final success = await makeSongOffline(
      {
        'ytid': id,
        'title': 'Owned boundary body',
        'sourceType': 'owned_fixture',
      },
      audioLoader: (_) async => OfflineAudioDownload(
        Stream.value(ownedBody),
        expectedBytes: ownedBody.length,
      ),
      commitProbe: command['mode'] == 'crash'
          ? (current) async {
              if (current == boundary) {
                await proof(command, 'boundary');
                await Completer<void>().future;
              }
            }
          : null,
    );
    if (success) {
      final completions = List<String>.from(
        Hive.box('user').get('boundaryCompletions', defaultValue: <String>[]),
      );
      if (!completions.contains(id)) completions.add(id);
      await Hive.box('user').put('boundaryCompletions', completions);
      await Hive.box('user').flush();
    }
    await proof(command, 'returned', success: success);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owned offline boundaries')),
    body: Text(status),
  );
}
