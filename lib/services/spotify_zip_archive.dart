import 'dart:typed_data';

import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_zip_importer.dart';

class SpotifyZipEntry {
  const SpotifyZipEntry._(
    this.name,
    this.decodedBytes,
    this._local,
    this._end,
    this._central,
    this._centralEnd,
  );
  final String name;
  final int decodedBytes;
  final int _local, _end, _central, _centralEnd;
}

/// Validated, privately owned archive bytes. Nothing is extracted or decoded
/// until the user explicitly selects an entry. This is not membership import.
class SpotifyZipArchive {
  SpotifyZipArchive._(this._bytes, this.entries);
  static const maxEntries = 32;
  final Uint8List _bytes;
  final List<SpotifyZipEntry> entries;

  static SpotifyZipArchive inspect(Uint8List input) {
    void require(bool condition) {
      if (!condition) {
        throw const SpotifyImportException(
          'Choose a ZIP with at most 32 safe root-level CSV, TSV or JSON files. Unsupported or damaged archive.',
        );
      }
    }

    require(input.length <= SpotifyZipImporter.maxBytes && input.length >= 22);
    final bytes = Uint8List.fromList(input);
    final data = ByteData.sublistView(bytes);
    int u16(int p) => data.getUint16(p, Endian.little);
    int u32(int p) => data.getUint32(p, Endian.little);
    final end = bytes.length - 22;
    require(
      u32(end) == 0x06054b50 &&
          u16(end + 4) == 0 &&
          u16(end + 6) == 0 &&
          u16(end + 20) == 0,
    );
    final count = u16(end + 10);
    require(count > 0 && count <= maxEntries && u16(end + 8) == count);
    final centralStart = u32(end + 16);
    require(
      centralStart >= 30 &&
          centralStart <= end &&
          u32(end + 12) == end - centralStart,
    );
    var central = centralStart;
    var local = 0;
    var totalDecoded = 0;
    final entries = <SpotifyZipEntry>[];
    final names = <String>{};
    for (var index = 0; index < count; index++) {
      require(
        central + 46 <= end &&
            u32(central) == 0x02014b50 &&
            u16(central + 6) <= 20,
      );
      final flags = u16(central + 8), method = u16(central + 10);
      require(
        (flags & ~0x806) == 0 &&
            (method == 0 || method == 8) &&
            (method == 8 || (flags & 6) == 0),
      );
      final compressed = u32(central + 20),
          decoded = u32(central + 24),
          nameLength = u16(central + 28);
      require(
        nameLength > 0 && nameLength <= 128 && central + 46 + nameLength <= end,
      );
      require(
        u16(central + 30) == 0 &&
            u16(central + 32) == 0 &&
            u16(central + 34) == 0 &&
            u32(central + 42) == local,
      );
      final external = u32(central + 38), unixType = (external >> 16) & 0xf000;
      require((external & 0x10) == 0 && (unixType == 0 || unixType == 0x8000));
      final nameBytes = bytes.sublist(central + 46, central + 46 + nameLength);
      require(nameBytes.every((b) => b >= 32 && b < 127));
      final name = String.fromCharCodes(nameBytes);
      require(
        RegExp(
              r'^[A-Za-z0-9][A-Za-z0-9 _.-]*\.(csv|tsv|json)$',
              caseSensitive: false,
            ).hasMatch(name) &&
            !name.contains('..'),
      );
      require(names.add(name.toLowerCase()));
      totalDecoded += decoded;
      require(totalDecoded <= SpotifyZipImporter.maxBytes);
      require(
        local + 30 <= centralStart &&
            u32(local) == 0x04034b50 &&
            u16(local + 4) <= 20,
      );
      require(
        u16(local + 6) == flags &&
            u16(local + 8) == method &&
            u32(local + 14) == u32(central + 16),
      );
      require(
        u32(local + 18) == compressed &&
            u32(local + 22) == decoded &&
            u16(local + 26) == nameLength &&
            u16(local + 28) == 0,
      );
      final payload = local + 30 + nameLength;
      require(
        payload <= centralStart &&
            compressed <= centralStart - payload &&
            (method != 0 || compressed == decoded),
      );
      for (var i = 0; i < nameLength; i++) {
        require(bytes[local + 30 + i] == nameBytes[i]);
      }
      final next = payload + compressed;
      entries.add(
        SpotifyZipEntry._(
          name,
          decoded,
          local,
          next,
          central,
          central + 46 + nameLength,
        ),
      );
      local = next;
      central += 46 + nameLength;
    }
    require(local == centralStart && central == end);
    return SpotifyZipArchive._(bytes, List.unmodifiable(entries));
  }

  Future<SpotifyImportPreview> parseEntry(
    String name, {
    required String fileName,
    Future<void>? cancelled,
    SpotifyDeflateDecoder? decodeDeflate,
  }) async {
    final matches = entries.where((entry) => entry.name == name);
    if (matches.length != 1) {
      throw const SpotifyImportException('Choose an entry from this archive.');
    }
    final entry = matches.single;
    // Reuse the already qualified single-entry decoder and CRC/row policy.
    // Offsets are rebased in an owned synthetic envelope, never a disk file.
    final local = _bytes.sublist(entry._local, entry._end);
    final central = _bytes.sublist(entry._central, entry._centralEnd);
    final bytes = Uint8List.fromList([
      ...local,
      ...central,
      ...List<int>.filled(22, 0),
    ]);
    final end = bytes.length - 22;
    ByteData.sublistView(bytes)
      ..setUint32(local.length + 42, 0, Endian.little)
      ..setUint32(end, 0x06054b50, Endian.little)
      ..setUint16(end + 8, 1, Endian.little)
      ..setUint16(end + 10, 1, Endian.little)
      ..setUint32(end + 12, central.length, Endian.little)
      ..setUint32(end + 16, local.length, Endian.little);
    final preview = await SpotifyZipImporter.parseBytes(
      bytes,
      fileName: fileName,
      cancelled: cancelled,
      decodeDeflate: decodeDeflate,
    );
    return SpotifyImportPreview(
      fileName: preview.fileName,
      format: preview.format,
      sourceEntryName: entry.name,
      sourcePlaylists: preview.sourcePlaylists,
      totalDataRows: preview.totalDataRows,
      tracks: preview.tracks,
      rejectedRows: preview.rejectedRows,
      notices: [
        ...preview.notices,
        if (entries.length > 1)
          '${entries.length - 1} other archive files were not imported. Choose them separately; playlist membership and synchronization are not supported.',
      ],
    );
  }
}
