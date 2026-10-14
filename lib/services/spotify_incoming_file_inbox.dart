import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_file_reader.dart';
import 'package:musify/services/spotify_song_list_importer.dart';
import 'package:musify/services/spotify_zip_archive.dart';
import 'package:musify/services/spotify_zip_importer.dart';

class SpotifyIncomingFile {
  SpotifyIncomingFile({
    required this.id,
    required this.uri,
    required this.name,
    required bool readGrantVerified,
    this.size,
  }) {
    if (!readGrantVerified ||
        id.isEmpty ||
        id.length > 128 ||
        uri.scheme != 'content' ||
        uri.authority.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.toString().length > 8192 ||
        name.isEmpty ||
        name.length > 255 ||
        name.contains('/') ||
        name.contains('\\') ||
        name.codeUnits.any((c) => c < 32 || c == 127) ||
        !RegExp(
          r'\.(csv|tsv|json|zip)$',
          caseSensitive: false,
        ).hasMatch(name) ||
        (size != null &&
            (size! < 0 || size! > SpotifyCsvImporter.maxJsonBytes))) {
      throw const SpotifyImportException(
        'Choose a supported local song-list file with a verified read grant. Nothing was imported.',
      );
    }
  }
  final String id, name;
  final Uri uri;
  final int? size;
}

class SpotifyIncomingFileLease {
  SpotifyIncomingFileLease._(this.file);
  final SpotifyIncomingFile file;
  final _cancelled = Completer<void>();
  bool _reading = false;
}

enum SpotifyIncomingFileOffer { queued, duplicate, full }

/// Bounded share/open preview intake. Offers do not read or persist URIs;
/// begin/readPreview is explicit and native grant verification is mandatory.
class SpotifyIncomingFileInbox {
  static const maxPending = 4;
  final _pending = <SpotifyIncomingFile>[];
  SpotifyIncomingFileLease? _active;
  List<SpotifyIncomingFile> get pending => List.unmodifiable(_pending);
  SpotifyIncomingFile? get active => _active?.file;
  SpotifyIncomingFileOffer offer(SpotifyIncomingFile file) {
    final existing = [if (_active != null) _active!.file, ..._pending];
    if (existing.any((entry) => entry.id == file.id && entry.uri != file.uri))
      throw StateError(
        'Incoming request identity changed. Existing requests were retained.',
      );
    if (existing.any((entry) => entry.id == file.id || entry.uri == file.uri))
      return SpotifyIncomingFileOffer.duplicate;
    if (_pending.length >= maxPending) return SpotifyIncomingFileOffer.full;
    _pending.add(file);
    return SpotifyIncomingFileOffer.queued;
  }

  SpotifyIncomingFileLease begin(String id) {
    if (_active != null)
      throw StateError(
        'Finish or cancel the active preview before opening another shared file.',
      );
    final index = _pending.indexWhere((entry) => entry.id == id);
    if (index < 0) throw StateError('This incoming file is no longer pending.');
    return _active = SpotifyIncomingFileLease._(_pending.removeAt(index));
  }

  bool finish(SpotifyIncomingFileLease lease) {
    if (!identical(_active, lease)) return false;
    lease._cancelled.complete();
    _active = null;
    return true;
  }

  /// Called only after begin. No bytes are opened by offer and no import is
  /// saved here. The caller supplies the actual verified native content stream.
  Future<SpotifyImportPreview> readPreview(
    SpotifyIncomingFileLease lease, {
    required Stream<List<int>> Function(SpotifyIncomingFile file) openStream,
    SpotifyDeflateDecoder? decodeDeflate,
    Future<String?> Function(List<String> entries)? chooseArchiveEntry,
  }) async {
    void requireCurrent() {
      if (!identical(_active, lease) || lease._cancelled.isCompleted)
        throw const SpotifyImportException('File selection was cancelled.');
    }

    requireCurrent();
    if (lease._reading) throw StateError('This file is already being read.');
    lease._reading = true;
    try {
      final file = lease.file;
      final bytes = await SpotifyImportFileReader.read(
        PlatformFile(
          name: file.name,
          size: file.size ?? 0,
          readStream: openStream(file),
        ),
        cancelled: lease._cancelled.future,
        maxBytes: SpotifyCsvImporter.maxJsonBytes,
      );
      requireCurrent();
      if (!file.name.toLowerCase().endsWith('.zip')) {
        return SpotifySongListImporter.parseBytes(bytes, fileName: file.name);
      }
      final archive = SpotifyZipArchive.inspect(bytes);
      final String? entry;
      if (archive.entries.length == 1) {
        entry = archive.entries.single.name;
      } else {
        if (chooseArchiveEntry == null)
          throw const SpotifyImportException(
            'Choose one song list from this ZIP.',
          );
        entry = await Future.any<String?>([
          chooseArchiveEntry(
            List.unmodifiable(archive.entries.map((e) => e.name)),
          ),
          lease._cancelled.future.then((_) => null),
        ]);
      }
      requireCurrent();
      if (entry == null)
        throw const SpotifyImportException('File selection was cancelled.');
      final preview = await archive.parseEntry(
        entry,
        fileName: file.name,
        cancelled: lease._cancelled.future,
        decodeDeflate: decodeDeflate,
      );
      requireCurrent();
      return preview;
    } finally {
      lease._reading = false;
    }
  }

  bool dismiss(String id) {
    final index = _pending.indexWhere((entry) => entry.id == id);
    if (index < 0) return false;
    _pending.removeAt(index);
    return true;
  }
}
