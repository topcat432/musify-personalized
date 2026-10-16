// Synthetic loopback acceptance; never imported by normal startup.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';

class OwnedOfflineRehearsal extends StatefulWidget {
  const OwnedOfflineRehearsal({super.key});
  @override
  State<OwnedOfflineRehearsal> createState() => _OwnedOfflineRehearsalState();
}

class _OwnedOfflineRehearsalState extends State<OwnedOfflineRehearsal> {
  String status = 'Ready';
  bool busy = false;
  bool cancelled = false;
  final bytes = List<int>.generate(8192, (index) => index % 251);

  Future<void> transfer(String id, {bool slow = false}) async {
    setState(() {
      busy = true;
      cancelled = false;
      status = 'Transferring $id';
    });
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = HttpClient();
    server.listen((request) async {
      request.response.contentLength = bytes.length;
      try {
        for (var offset = 0; offset < bytes.length; offset += 256) {
          request.response.add(bytes.sublist(offset, offset + 256));
          await request.response.flush();
          await Future<void>.delayed(Duration(milliseconds: slow ? 1000 : 20));
        }
        await request.response.close();
      } catch (_) {
        // Cancellation closes the owned client; the server is closed below.
      }
    });
    try {
      final success = await makeSongOffline(
        {
          'ytid': id,
          'title': 'Owned loopback body',
          'sourceType': 'owned_fixture',
        },
        audioLoader: (_) async {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:${server.port}/owned'),
          );
          final response = await request.close();
          return OfflineAudioDownload(
            response,
            expectedBytes: response.contentLength,
          );
        },
        shouldCancel: () => cancelled,
      );
      final file = File(FilePaths.getAudioPath(id));
      final registry =
          Hive.box('userNoBackup').get('offlineSongs', defaultValue: [])
              as List;
      final content = await file.exists() ? await file.readAsBytes() : <int>[];
      final proof = {
        'sourceSha': const String.fromEnvironment('GIT_SHA'),
        'id': id,
        'success': success,
        'cancelled': cancelled,
        'fileBytes': content.length,
        'completeBytesExact':
            content.length == bytes.length &&
            List.generate(
              bytes.length,
              (i) => content[i] == bytes[i],
            ).every((v) => v),
        'registered': registry.whereType<Map>().any((row) => row['ytid'] == id),
        'registryIds': registry
            .whereType<Map>()
            .map((row) => row['ytid'])
            .toList(),
        'loopbackOnly': true,
      };
      await File(
        '$applicationDirPath/offline-native-$id.json',
      ).writeAsString(jsonEncode(proof), flush: true);
      if (mounted)
        setState(
          () => status =
              '${success ? 'Complete' : 'Rejected'} $id ${content.length} bytes',
        );
    } finally {
      client.close(force: true);
      await server.close(force: true);
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owned offline transfer')),
    body: ListView(
      children: [
        Text(status),
        FilledButton(
          onPressed: busy
              ? null
              : () => unawaited(transfer('owned-native-complete')),
          child: const Text('Complete owned transfer'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () => unawaited(transfer('owned-native-cancel', slow: true)),
          child: const Text('Start cancellable transfer'),
        ),
        FilledButton(
          onPressed: busy ? () => setState(() => cancelled = true) : null,
          child: const Text('Cancel owned transfer'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () => unawaited(transfer('owned-native-restart', slow: true)),
          child: const Text('Start interrupted transfer'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () => unawaited(transfer('owned-native-restart')),
          child: const Text('Retry interrupted transfer'),
        ),
      ],
    ),
  );
}
