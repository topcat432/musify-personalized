import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_incoming_file_inbox.dart';

/// Native catalog is authoritative; the inbox mirrors its granted descriptors.
class SpotifyIncomingFileService extends ChangeNotifier {
  SpotifyIncomingFileService({
    this.channel = const MethodChannel(
      'com.topcat432.musifypersonalized/incoming_files',
    ),
    SpotifyIncomingFileInbox? inbox,
  }) : inbox = inbox ?? SpotifyIncomingFileInbox();
  static final instance = SpotifyIncomingFileService();
  final MethodChannel channel;
  final SpotifyIncomingFileInbox inbox;
  String? notice;
  bool _closed = false, _refreshing = false, _again = false;
  int _sequence = 0;
  final _reads = <String, void Function()>{};
  Future<void> start() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await refresh();
    });
    await refresh();
  }

  Future<void> refresh() async {
    if (_closed) return;
    if (_refreshing) {
      _again = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _again = false;
        final result = await channel
            .invokeMapMethod<String, dynamic>('list')
            .timeout(const Duration(seconds: 2));
        if (_closed) return;
        if (result == null ||
            result['files'] is! List ||
            (result['files'] as List).length > 4)
          throw const FormatException();
        final files = <SpotifyIncomingFile>[];
        for (final value in result['files'] as List) {
          if (value is! Map ||
              value['id'] is! String ||
              value['uri'] is! String ||
              value['name'] is! String ||
              (value['size'] != null && value['size'] is! int))
            throw const FormatException();
          files.add(
            SpotifyIncomingFile(
              id: value['id'] as String,
              uri: Uri.parse(value['uri'] as String),
              name: value['name'] as String,
              size: value['size'] as int?,
              readGrantVerified: value['readGrantVerified'] == true,
            ),
          );
        }
        final ids = files.map((file) => file.id).toSet();
        if (ids.length != files.length ||
            files.map((file) => file.uri).toSet().length != files.length)
          throw const FormatException();
        final known = [
          if (inbox.active != null) inbox.active!,
          ...inbox.pending,
        ];
        for (final file in files) {
          if (known.any(
            (prior) => prior.id == file.id && prior.uri != file.uri,
          ))
            throw const FormatException();
        }
        for (final file in inbox.pending.toList())
          if (!ids.contains(file.id)) inbox.dismiss(file.id);
        for (final file in files) inbox.offer(file);
        notice = result['notice'] is String ? result['notice'] as String : null;
        notifyListeners();
      } while (_again && !_closed);
    } on MissingPluginException {
      // Other platforms retain the ordinary picker and do not show a false inbox.
    } catch (_) {
      if (!_closed) {
        notice =
            'The incoming-file inbox could not be verified. Try sharing a local file again.';
        notifyListeners();
      }
    } finally {
      _refreshing = false;
    }
  }

  Stream<List<int>> openStream(SpotifyIncomingFile file) {
    String? request;
    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        request = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}-${Random.secure().nextInt(0x7fffffff)}';
        unawaited(_readBytes(file, request!).then<void>((bytes) {
          if (controller.hasListener && !_closed && identical(inbox.active, file)) controller.add(bytes);
          unawaited(controller.close());
        }, onError: (Object error, StackTrace stack) {
          if (controller.hasListener) controller.addError(error, stack);
          unawaited(controller.close());
        }));
      },
      onCancel: () { if (request != null) _reads[request]?.call(); },
    );
    return controller.stream;
  }

  Future<Uint8List> _readBytes(SpotifyIncomingFile file, String request) async {
    if (_closed || !identical(inbox.active, file)) {
      throw const SpotifyImportException('File selection was cancelled.');
    }
    if (_reads.isNotEmpty) throw StateError('A native file read is already active.');
    final response = Completer<Uint8List>();
    var done = false, cancelSent = false;
    Future<void> cancel() async {
      if (cancelSent) return;
      cancelSent = true;
      try {
        await channel
            .invokeMethod<void>('cancel', {'request': request})
            .timeout(const Duration(seconds: 1));
      } catch (_) {
        /* Owned native worker remains busy until actual exit. */
      }
    }

    void stop() {
      if (done || response.isCompleted) return;
      unawaited(cancel());
      response.completeError(
        const SpotifyImportException('File selection was cancelled.'),
      );
    }

    _reads[request] = stop;
    final timer = Timer(const Duration(seconds: 20), stop);
    try {
      unawaited(
        channel
            .invokeMethod<Object>('read', {'id': file.id, 'request': request})
            .then<void>(
              (value) {
                if (done || response.isCompleted) return;
                if (value is! Uint8List ||
                    value.length > SpotifyCsvImporter.maxJsonBytes) {
                  response.completeError(
                    const SpotifyImportException(
                      'The incoming file exceeded its limits or could not be verified.',
                    ),
                  );
                } else {
                  response.complete(value);
                }
              },
              onError: (Object error, StackTrace stack) {
                if (!done && !response.isCompleted)
                  response.completeError(
                    const SpotifyImportException(
                      'The file read was unavailable, changed or could not be verified.',
                    ),
                  );
              },
            ),
      );
      final bytes = await response.future;
      if (_closed || !identical(inbox.active, file))
        throw const SpotifyImportException('File selection was cancelled.');
      return bytes;
    } finally {
      done = true;
      timer.cancel();
      _reads.remove(request);
      if (!response.isCompleted || cancelSent) unawaited(cancel());
    }
  }

  SpotifyIncomingFileLease begin(String id) {
    final lease = inbox.begin(id);
    if (!_closed) notifyListeners();
    return lease;
  }
  Future<void> finish(SpotifyIncomingFileLease lease) async {
    if (!inbox.finish(lease)) return;
    for (final stop in _reads.values.toList()) stop();
    try {
      await channel
          .invokeMethod<void>('finish', {'id': lease.file.id})
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
    await refresh();
    if (!_closed) notifyListeners();
  }

  Future<void> acknowledgeNotice() async {
    notice = null;
    if (!_closed) notifyListeners();
    try { await channel.invokeMethod<void>('ackNotice').timeout(const Duration(seconds: 1)); } catch (_) {}
  }
  Future<void> dismiss(String id) async {
    if (!inbox.dismiss(id)) return;
    try {
      await channel
          .invokeMethod<void>('dismiss', {'id': id})
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
    await refresh();
  }

  @override
  void dispose() {
    _closed = true;
    final active = inbox.active;
    if (active != null)
      unawaited(
        channel
            .invokeMethod<void>('finish', {'id': active.id})
            .timeout(const Duration(seconds: 1))
            .catchError((Object _) {}),
      );
    channel.setMethodCallHandler(null);
    for (final stop in _reads.values.toList()) stop();
    super.dispose();
  }
}
