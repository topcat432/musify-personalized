import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_zip_archive.dart';
import 'package:musify/services/spotify_zip_importer.dart';
import '../support/spotify_zip_fixtures.dart';

void main() {
  final rejected = throwsA(isA<SpotifyImportException>());
  test(
    'archive choice preserves central order and selected source rows',
    () async {
      final archive = SpotifyZipArchive.inspect(
        SpotifyZipFixtures.selectedLists(),
      );
      expect(archive.entries.map((e) => e.name), [
        'first.csv',
        'second.tsv',
        'Playlist.json',
      ]);
      final preview = await archive.parseEntry(
        'second.tsv',
        fileName: 'account.zip',
      );
      expect(preview.fileName, 'account.zip');
      expect(preview.tracks.single.title, 'Second');
      expect(preview.tracks.single.sourceRow, 2);
      expect(
        preview.notices.join(' '),
        contains('2 other archive files were not imported'),
      );
      await expectLater(
        archive.parseEntry('Playlist.json', fileName: 'account.zip'),
        rejected,
      );
      await expectLater(
        archive.parseEntry('invented.csv', fileName: 'account.zip'),
        rejected,
      );
    },
  );
  test('inspection privately owns bytes against caller mutation', () async {
    final input = SpotifyZipFixtures.selectedLists();
    final archive = SpotifyZipArchive.inspect(input);
    input.fillRange(0, input.length, 0);
    expect(
      (await archive.parseEntry(
        'first.csv',
        fileName: 'account.zip',
      )).tracks.single.title,
      'First',
    );
    expect(() => archive.entries.clear(), throwsUnsupportedError);
  });
  for (final fixture in [
    SpotifyZipFixtures.duplicateNames,
    SpotifyZipFixtures.tooManyEntries,
    SpotifyZipFixtures.unsafePath,
  ]) {
    test(
      'unsafe ambiguous or over-count archive rejects before choice ${fixture.toString()}',
      () {
        expect(() => SpotifyZipArchive.inspect(fixture()), rejected);
      },
    );
  }
  test('every truncation prefix fails closed', () {
    final b = SpotifyZipFixtures.selectedLists();
    for (var i = 0; i < b.length; i++) {
      expect(
        () => SpotifyZipArchive.inspect(Uint8List.sublistView(b, 0, i)),
        rejected,
        reason: 'prefix $i',
      );
    }
  });
  for (final corruption in [
    'offset',
    'name',
    'crc',
    'flags',
    'method',
    'size',
    'extra',
    'symlink',
    'decodedBudget',
    'centralTrailing',
    'comment',
    'disk',
    'count',
  ]) {
    test('archive rejects $corruption in an unselected entry', () {
      final b = SpotifyZipFixtures.selectedLists();
      final d = ByteData.sublistView(b);
      final end = b.length - 22;
      final c = d.getUint32(end + 16, Endian.little);
      final next = c + 46 + d.getUint16(c + 28, Endian.little);
      final local = d.getUint32(next + 42, Endian.little);
      switch (corruption) {
        case 'offset':
          d.setUint32(next + 42, local + 1, Endian.little);
        case 'name':
          b[next + 46] = 47;
        case 'crc':
          b[next + 16] ^= 1;
        case 'flags':
          d.setUint16(next + 8, 1, Endian.little);
        case 'method':
          d.setUint16(next + 10, 99, Endian.little);
        case 'size':
          d.setUint32(next + 20, 0xffffffff, Endian.little);
        case 'extra':
          d.setUint16(next + 30, 1, Endian.little);
        case 'symlink':
          d.setUint32(next + 38, 0xa0000000, Endian.little);
        case 'decodedBudget':
          d.setUint32(next + 24, SpotifyZipImporter.maxBytes, Endian.little);
        case 'centralTrailing':
          d.setUint32(
            end + 12,
            d.getUint32(end + 12, Endian.little) - 1,
            Endian.little,
          );
        case 'comment':
          d.setUint16(end + 20, 1, Endian.little);
        case 'disk':
          d.setUint16(end + 4, 1, Endian.little);
        case 'count':
          d.setUint16(end + 8, 2, Endian.little);
      }
      expect(() => SpotifyZipArchive.inspect(b), rejected);
    });
  }
  test(
    'payload corruption rejects selected CRC without decoding other entries',
    () async {
      final b = SpotifyZipFixtures.selectedLists();
      b[30 + 'first.csv'.length] ^= 1;
      final archive = SpotifyZipArchive.inspect(b);
      expect(
        (await archive.parseEntry(
          'second.tsv',
          fileName: 'account.zip',
        )).tracks.single.title,
        'Second',
      );
      await expectLater(
        archive.parseEntry('first.csv', fileName: 'account.zip'),
        rejected,
      );
    },
  );
  test('cancelled selection returns no preview', () async {
    final archive = SpotifyZipArchive.inspect(
      SpotifyZipFixtures.selectedLists(),
    );
    await expectLater(
      archive.parseEntry(
        'first.csv',
        fileName: 'account.zip',
        cancelled: Future.value(),
      ),
      rejected,
    );
  });
  test(
    'compressed entry uses strict decoder only for explicitly selected payload',
    () async {
      final archive = SpotifyZipArchive.inspect(
        SpotifyZipFixtures.compressedLists(),
      );
      var calls = 0;
      await expectLater(
        archive.parseEntry('second.csv', fileName: 'account.zip'),
        rejected,
      );
      await expectLater(
        archive.parseEntry(
          'second.csv',
          fileName: 'account.zip',
          decodeDeflate: (bytes, size, cancelled) async {
            calls++;
            return SpotifyDeflateResult(
              bytes: Uint8List(size),
              consumedBytes: bytes.length,
              finished: false,
            );
          },
        ),
        rejected,
      );
      expect(calls, 1);
    },
  );
}
