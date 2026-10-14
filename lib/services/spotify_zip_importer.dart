import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:musify/services/spotify_csv_importer.dart';

/// A deliberately narrow, in-memory single song-list ZIP adapter.
/// Never extracts files, chooses among entries or infers memberships.
class SpotifyZipImporter {
  const SpotifyZipImporter._();
  static const maxBytes = 8 * 1024 * 1024;

  static Future<SpotifyImportPreview> parseBytes(
    Uint8List bytes, {
    required String fileName,
    Future<void>? cancelled,
  }) async {
    var stopped = false;
    if (cancelled != null) unawaited(cancelled.then((_) => stopped = true));
    await Future<void>.value();
    final clock = Stopwatch()..start();
    void checkCancelled() {
      if (stopped) _fail('File selection was cancelled.');
      if (clock.elapsed > const Duration(seconds: 20)) {
        _fail(
          'Reading this ZIP timed out. Choose a local song list and try again.',
        );
      }
    }

    checkCancelled();
    if (bytes.length > maxBytes)
      _fail('ZIP song lists must be 8 MiB or smaller.');
    final data = ByteData.sublistView(bytes);
    int u16(int p) => data.getUint16(p, Endian.little);
    int u32(int p) => data.getUint32(p, Endian.little);
    void require(bool ok) {
      if (!ok)
        _fail(
          'Choose a ZIP containing exactly one ordinary CSV, TSV or JSON song list. Unsupported or damaged ZIP.',
        );
    }

    // Fixed EOCD at the end: comments, split archives and ZIP64 are unsupported.
    require(bytes.length >= 22);
    final end = bytes.length - 22;
    require(u32(end) == 0x06054b50);
    require(u16(end + 4) == 0 && u16(end + 6) == 0);
    require(u16(end + 8) == 1 && u16(end + 10) == 1 && u16(end + 20) == 0);
    final central = u32(end + 16);
    final centralSize = u32(end + 12);
    require(centralSize >= 46 && central + centralSize == end);
    require(central >= 30 && central + 46 <= end);
    require(u32(central) == 0x02014b50 && u16(central + 6) <= 20);
    final flags = u16(central + 8);
    final method = u16(central + 10);
    // No encryption, data descriptors or other optional flag semantics.
    require(flags == 0 || flags == 0x800);
    require(method == 0 || method == 8);
    final crc = u32(central + 16);
    final compressedSize = u32(central + 20);
    final size = u32(central + 24);
    final nameSize = u16(central + 28);
    require(nameSize > 0 && nameSize <= 128);
    require(u16(central + 30) == 0 && u16(central + 32) == 0);
    require(u16(central + 34) == 0 && u32(central + 42) == 0);
    require(centralSize == 46 + nameSize);
    final external = u32(central + 38);
    final unixType = (external >> 16) & 0xf000;
    require((external & 0x10) == 0 && (unixType == 0 || unixType == 0x8000));
    if (size > maxBytes)
      _fail('The decoded ZIP song list must be 8 MiB or smaller.');
    final nameBytes = Uint8List.sublistView(bytes, central + 46, end);
    require(nameBytes.every((b) => b >= 32 && b < 127));
    final name = ascii.decode(nameBytes);
    require(
      RegExp(
        r'^[A-Za-z0-9][A-Za-z0-9 _.-]*\.(csv|tsv|json)$',
        caseSensitive: false,
      ).hasMatch(name),
    );
    require(!name.contains('..'));
    require(u32(0) == 0x04034b50 && u16(4) <= 20);
    require(u16(6) == flags && u16(8) == method);
    require(u32(14) == crc && u32(18) == compressedSize && u32(22) == size);
    require(u16(26) == nameSize && u16(28) == 0);
    final start = 30 + nameSize;
    require(start + compressedSize == central);
    require(start <= central);
    for (var i = 0; i < nameSize; i++) {
      require(bytes[30 + i] == nameBytes[i]);
    }
    final payload = Uint8List.sublistView(bytes, start, central);
    Uint8List decoded;
    if (method == 0) {
      require(compressedSize == size);
      decoded = payload;
    } else {
      final output = BytesBuilder(copy: false);
      // Small input chunks bound individual decoder output allocations too;
      // advertised lengths are never trusted to limit inflation.
      Stream<List<int>> chunks() async* {
        for (var p = 0; p < payload.length; p += 256) {
          if (p % 4096 == 0) await Future<void>.delayed(Duration.zero);
          checkCancelled();
          yield Uint8List.sublistView(
            payload,
            p,
            (p + 256).clamp(0, payload.length),
          );
        }
      }

      try {
        await for (final chunk in chunks().transform(ZLibDecoder(raw: true))) {
          checkCancelled();
          if (output.length + chunk.length > maxBytes ||
              output.length + chunk.length > size) {
            _fail('The decoded ZIP song list exceeds its allowed size.');
          }
          output.add(chunk);
        }
        decoded = output.takeBytes();
      } on SpotifyImportException {
        rethrow;
      } catch (_) {
        _fail('The ZIP compressed song list is damaged.');
      }
    }
    checkCancelled();
    require(decoded.length == size && _crc32(decoded) == crc);
    final preview = SpotifyCsvImporter.parseBytes(
      decoded,
      fileName: name,
      rejectPlaylistMembership: true,
    );
    if (preview.totalDataRows > SpotifyCsvImporter.maxJsonTracks) {
      _fail('ZIP song lists must contain at most 10,000 tracks.');
    }
    return SpotifyImportPreview(
      fileName: fileName,
      format: '${preview.format} in ZIP',
      totalDataRows: preview.totalDataRows,
      tracks: preview.tracks,
      rejectedRows: preview.rejectedRows,
      notices: [
        'ZIP entry: $name. One flat song list only; no playlist synchronization.',
        ...preview.notices,
      ],
    );
  }

  static Never _fail(String message) => throw SpotifyImportException(message);

  static int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ ((crc & 1) == 0 ? 0 : 0xedb88320);
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}
