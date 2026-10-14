import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_zip_importer.dart';

void main() {
  final fixtures = <String, String>{
    'csv':
        'UEsDBBQAAAAAALwETl1mdiMFMwAAADMAAAAJAAAAc29uZ3MuY3N2VHJhY2sgTmFtZSxBcnRpc3QgTmFtZShzKQpGaXJzdCxPd25lcgpTZWNvbmQsT3duZXIKUEsBAhQAFAAAAAAAvAROXWZ2IwUzAAAAMwAAAAkAAAAAAAAAAAAAAIABAAAAAHNvbmdzLmNzdlBLBQYAAAAAAQABADcAAABaAAAAAAA=',
    'stored':
        'UEsDBBQAAAAAALwETl2bt5EZGQAAABkAAAAJAAAAc29uZ3MudHN2VGl0bGUJQXJ0aXN0CkZpcnN0CU93bmVyClBLAQIUABQAAAAAALwETl2bt5EZGQAAABkAAAAJAAAAAAAAAAAAAACAAQAAAABzb25ncy50c3ZQSwUGAAAAAAEAAQA3AAAAQAAAAAAA',
    'json':
        'UEsDBBQAAAAAALwETl2+xEO+VQAAAFUAAAAQAAAAWW91ckxpYnJhcnkuSlNPTnsidHJhY2tzIjogW3sidHJhY2siOiAiRmlyc3QiLCAiYXJ0aXN0IjogIk93bmVyIn1dLCAiYWxidW1zIjogW3siYWxidW0iOiAiSWdub3JlZCJ9XX1QSwECFAAUAAAAAAC8BE5dvsRDvlUAAABVAAAAEAAAAAAAAAAAAAAAgAEAAAAAWW91ckxpYnJhcnkuSlNPTlBLBQYAAAAAAQABAD4AAACDAAAAAAA=',
    'membership':
        'UEsDBBQAAAAAALwETl2LXu/eLwAAAC8AAAAJAAAAc29uZ3MuY3N2VGl0bGUsQXJ0aXN0LFBsYXlsaXN0IE5hbWUKRmlyc3QsT3duZXIsUHJpdmF0ZQpQSwECFAAUAAAAAAC8BE5di17v3i8AAAAvAAAACQAAAAAAAAAAAAAAgAEAAAAAc29uZ3MuY3N2UEsFBgAAAAABAAEANwAAAFYAAAAAAA==',
    'path':
        'UEsDBBQAAAAAALwETl20IWK1GQAAABkAAAAMAAAALi4vc29uZ3MuY3N2VGl0bGUsQXJ0aXN0CkZpcnN0LE93bmVyClBLAQIUABQAAAAAALwETl20IWK1GQAAABkAAAAMAAAAAAAAAAAAAACAAQAAAAAuLi9zb25ncy5jc3ZQSwUGAAAAAAEAAQA6AAAAQwAAAAAA',
    'nested':
        'UEsDBBQAAAAAALwETl20IWK1GQAAABkAAAAQAAAAZm9sZGVyL3NvbmdzLmNzdlRpdGxlLEFydGlzdApGaXJzdCxPd25lcgpQSwECFAAUAAAAAAC8BE5dtCFitRkAAAAZAAAAEAAAAAAAAAAAAAAAgAEAAAAAZm9sZGVyL3NvbmdzLmNzdlBLBQYAAAAAAQABAD4AAABHAAAAAAA=',
    'badjson':
        'UEsDBBQAAAAAALwETl2CBAZoCwAAAAsAAAAQAAAAWW91ckxpYnJhcnkuanNvbnsidHJhY2tzIjpbUEsBAhQAFAAAAAAAvAROXYIEBmgLAAAACwAAABAAAAAAAAAAAAAAAIABAAAAAFlvdXJMaWJyYXJ5Lmpzb25QSwUGAAAAAAEAAQA+AAAAOQAAAAAA',
    'unknown':
        'UEsDBBQAAAAAALwETl20IWK1GQAAABkAAAAJAAAAb3RoZXIudHh0VGl0bGUsQXJ0aXN0CkZpcnN0LE93bmVyClBLAQIUABQAAAAAALwETl20IWK1GQAAABkAAAAJAAAAAAAAAAAAAACAAQAAAABvdGhlci50eHRQSwUGAAAAAAEAAQA3AAAAQAAAAAAA',
    'truncated':
        'UEsDBBQAAAAIAAEETl20IWK1GgAAABkAAAAJAAAAc29uZ3MuY3N2C8ksyUnVcSwqySwu4XLLLCou0fEvz0st4gJQSwECFAAUAAAACAABBE5dtCFitRoAAAAZAAAACQAAAAAAAAAAAAAAgAEAAAAAc29uZ3MuY3N2UEsFBgAAAAABAAEANwAAAEEAAAAAAA==',
    'trailing':
        'UEsDBBQAAAAIAAEETl20IWK1LgAAABkAAAAJAAAAc29uZ3MuY3N2C8ksyUnVcSwqySwu4XLLLCou0fEvz0st4gIAb3duZWQgdHJhaWxpbmcgZGF0YVBLAQIUABQAAAAIAAEETl20IWK1LgAAABkAAAAJAAAAAAAAAAAAAACAAQAAAABzb25ncy5jc3ZQSwUGAAAAAAEAAQA3AAAAVQAAAAAA',
    'fixed':
        'UEsDBBQAAAAIALwETl20IWK1GwAAABkAAAAJAAAAc29uZ3MuY3N2C8ksyUnVcSwqySwu4XLLLCou0fEvz0st4gIAUEsBAhQAFAAAAAgAvAROXbQhYrUbAAAAGQAAAAkAAAAAAAAAAAAAAIABAAAAAHNvbmdzLmNzdlBLBQYAAAAAAQABADcAAABCAAAAAAA=',
    'dynamic':
        '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',
  };
  Uint8List fixture(String key) => base64Decode(fixtures[key]!);
  Future<SpotifyImportPreview> parse(Uint8List bytes) =>
      SpotifyZipImporter.parseBytes(bytes, fileName: 'owned.ZIP');
  final rejected = throwsA(isA<SpotifyImportException>());
  int central(Uint8List b) =>
      ByteData.sublistView(b).getUint32(b.length - 6, Endian.little);
  // Resize independent Python-produced stored fixtures; expected CRC constants
  // come from Python zlib, rather than sharing the production CRC algorithm.
  Uint8List stored(List<int> payload, int crc, {String template = 'csv'}) {
    final b = fixture(template);
    final c = central(b);
    final start = 30 + ByteData.sublistView(b).getUint16(26, Endian.little);
    final a = Uint8List.fromList([
      ...b.sublist(0, start),
      ...payload,
      ...b.sublist(c),
    ]);
    final nc = start + payload.length;
    final d = ByteData.sublistView(a);
    for (final offset in [14, nc + 16]) {
      d.setUint32(offset, crc, Endian.little);
    }
    for (final offset in [18, 22, nc + 20, nc + 24]) {
      d.setUint32(offset, payload.length, Endian.little);
    }
    d.setUint32(a.length - 6, nc, Endian.little);
    return a;
  }

  test(
    'stored CSV preserves row order and outer filename with visible entry',
    () async {
      final p = await parse(fixture('csv'));
      expect(p.fileName, 'owned.ZIP');
      expect(p.tracks.map((t) => t.title), ['First', 'Second']);
      expect(p.tracks.map((t) => t.sourceRow), [2, 3]);
      expect(p.notices.single, contains('songs.csv'));
    },
  );
  test('stored TSV uses existing tab parser', () async {
    expect((await parse(fixture('stored'))).tracks.single.title, 'First');
  });
  test('stored saved-track JSON retains non-track disclosure', () async {
    final p = await parse(fixture('json'));
    expect(p.tracks.single.title, 'First');
    expect(p.notices.length, greaterThan(1));
  });
  for (final key in ['membership', 'path', 'nested', 'badjson', 'unknown']) {
    test('rejects $key without partial preview', () async {
      await expectLater(parse(fixture(key)), rejected);
    });
  }
  for (final length in [0, 10, 21]) {
    test('rejects short archive $length', () async {
      await expectLater(parse(Uint8List(length)), rejected);
    });
  }
  test('rejects oversized input before parsing', () async {
    await expectLater(
      parse(Uint8List(SpotifyZipImporter.maxBytes + 1)),
      rejected,
    );
  });
  test('rejects archive comments and trailing records', () async {
    await expectLater(
      parse(Uint8List.fromList([...fixture('csv'), 0])),
      rejected,
    );
  });
  for (final mutation in [
    'count',
    'encryption',
    'descriptor',
    'method',
    'crc',
    'size',
    'centralName',
    'localName',
    'offset',
    'disk',
    'extra',
    'symlink',
    'compressedSize',
    'declaredOversize',
  ]) {
    test('rejects inconsistent or unsupported $mutation', () async {
      final b = fixture('csv');
      final d = ByteData.sublistView(b);
      final c = central(b);
      final e = b.length - 22;
      switch (mutation) {
        case 'count':
          d.setUint16(e + 10, 2, Endian.little);
          break;
        case 'encryption':
          d.setUint16(c + 8, 1, Endian.little);
          break;
        case 'descriptor':
          d.setUint16(c + 8, 8, Endian.little);
          break;
        case 'method':
          d.setUint16(c + 10, 99, Endian.little);
          break;
        case 'crc':
          d.setUint32(c + 16, 0, Endian.little);
          d.setUint32(14, 0, Endian.little);
          break;
        case 'size':
          d.setUint32(c + 24, 1, Endian.little);
          d.setUint32(22, 1, Endian.little);
          break;
        case 'centralName':
          b[c + 46] = 120;
          break;
        case 'localName':
          b[30] = 120;
          break;
        case 'offset':
          d.setUint32(c + 42, 1, Endian.little);
          break;
        case 'disk':
          d.setUint16(e + 4, 1, Endian.little);
          break;
        case 'extra':
          d.setUint16(28, 1, Endian.little);
          break;
        case 'symlink':
          d.setUint32(c + 38, 0xa0000000, Endian.little);
          break;
        case 'compressedSize':
          d.setUint32(c + 20, 0, Endian.little);
          d.setUint32(18, 0, Endian.little);
          break;
        case 'declaredOversize':
          d.setUint32(c + 24, SpotifyZipImporter.maxBytes + 1, Endian.little);
          break;
      }
      await expectLater(parse(b), rejected);
    });
  }
  for (final key in ['fixed', 'dynamic', 'truncated', 'trailing']) {
    test('raw DEFLATE $key input fails closed before decoding', () async {
      await expectLater(
        parse(fixture(key)),
        throwsA(
          isA<SpotifyImportException>().having(
            (e) => e.message,
            'guidance',
            contains('uncompressed (stored) ZIP'),
          ),
        ),
      );
    });
  }
  test('all truncated stored archive prefixes reject', () async {
    final b = fixture('csv');
    for (var i = 0; i < b.length; i++) {
      await expectLater(parse(Uint8List.sublistView(b, 0, i)), rejected);
    }
  });
  test('input archive stays byte-exact', () async {
    final b = fixture('csv');
    final before = Uint8List.fromList(b);
    await parse(b);
    expect(b, before);
  });
  test('already cancelled stored input never returns preview', () async {
    final cancel = Completer<void>()..complete();
    await expectLater(
      SpotifyZipImporter.parseBytes(
        fixture('csv'),
        fileName: 'owned.zip',
        cancelled: cancel.future,
      ),
      rejected,
    );
  });
  test('event-loop cancellation runs before stored CRC and preview', () async {
    final cancel = Completer<void>();
    Timer.run(cancel.complete);
    await expectLater(
      SpotifyZipImporter.parseBytes(
        fixture('csv'),
        fileName: 'owned.zip',
        cancelled: cancel.future,
      ),
      rejected,
    );
  });
  test('ZIP64 required version rejects without size sentinels', () async {
    final b = fixture('csv');
    ByteData.sublistView(b).setUint16(central(b) + 6, 45, Endian.little);
    await expectLater(parse(b), rejected);
  });
  test('strict flat CSV rejects unrecognized playlist-prefixed columns', () {
    expect(
      () => SpotifyCsvImporter.parseBytes(
        Uint8List.fromList(
          utf8.encode('Title,Artist,PlaylistURL\nFirst,Owner,Private\n'),
        ),
        fileName: 'songs.csv',
        rejectPlaylistMembership: true,
      ),
      rejected,
    );
  });
  test('valid stored JSON archive exactly at 8 MiB is accepted', () async {
    final prefix = '{"tracks":[{"track":"First","artist":"Owner"}]}';
    final payload = utf8.encode(
      prefix + ' ' * (SpotifyZipImporter.maxBytes - 130 - prefix.length),
    );
    final b = stored(payload, 2176009465, template: 'json');
    expect(b.length, SpotifyZipImporter.maxBytes);
    expect((await parse(b)).tracks.single.title, 'First');
  });
  test('stored CSV 10000 row boundary', () async {
    final payload = utf8.encode(
      'Title,Artist\n' + List.filled(10000, 'A,Owner\n').join(),
    );
    final b = stored(payload, 958047907);
    expect((await parse(b)).tracks.length, 10000);
  });
  test('stored CSV 10001 row boundary', () async {
    final payload = utf8.encode(
      'Title,Artist\n' + List.filled(10001, 'A,Owner\n').join(),
    );
    final b = stored(payload, 1527270452);
    await expectLater(parse(b), rejected);
  });
  Uint8List compressedEnvelope() => base64Decode(
    'UEsDBBQAAAAIACAKTl1mdiMFLAAAADMAAAAJAAAAc29uZ3MuY3N2CylKTM5W8EvMTdVxLCrJLC4BszWKNbncMouKS3T8y/NSi7iCU5Pz81KgHABQSwECFAAUAAAACAAgCk5dZnYjBSwAAAAzAAAACQAAAAAAAAAAAAAAgAEAAAAAc29uZ3MuY3N2UEsFBgAAAAABAAEANwAAAFMAAAAAAA==',
  );
  Uint8List csvPayload() => Uint8List.fromList(
    utf8.encode('Track Name,Artist Name(s)\nFirst,Owner\nSecond,Owner\n'),
  );
  test('verified decoder response reuses CSV order and CRC policy', () async {
    final p = await SpotifyZipImporter.parseBytes(
      compressedEnvelope(),
      fileName: 'owned.zip',
      decodeDeflate: (bytes, size, cancelled) async => SpotifyDeflateResult(
        bytes: csvPayload(),
        consumedBytes: bytes.length,
        finished: true,
      ),
    );
    expect(p.tracks.map((t) => t.title), ['First', 'Second']);
    expect(p.tracks.map((t) => t.sourceRow), [2, 3]);
  });
  for (final corruption in ['unfinished', 'unused', 'wrongCRC', 'oversize']) {
    test('ZIP verifies $corruption even after native returns', () async {
      await expectLater(
        SpotifyZipImporter.parseBytes(
          compressedEnvelope(),
          fileName: 'owned.zip',
          decodeDeflate: (bytes, size, cancelled) async => SpotifyDeflateResult(
            bytes: corruption == 'wrongCRC'
                ? Uint8List(size)
                : corruption == 'oversize'
                ? Uint8List(SpotifyZipImporter.maxBytes + 1)
                : csvPayload(),
            consumedBytes: bytes.length - (corruption == 'unused' ? 1 : 0),
            finished: corruption != 'unfinished',
          ),
        ),
        rejected,
      );
    });
  }
}
