import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_file_reader.dart';

void main() {
  test('declared oversize JSON refuses a stream before reading', () async {
    var listened = false;
    final stream = Stream<List<int>>.multi((c) {
      listened = true;
      c.add([1]);
      c.close();
    });
    final file = PlatformFile(
      name: 'owned.json',
      size: SpotifyCsvImporter.maxJsonBytes + 1,
      readStream: stream,
    );
    await expectLater(
      SpotifyImportFileReader.read(file),
      throwsA(isA<SpotifyImportException>()),
    );
    expect(listened, isFalse);
  });
  test('actual overflow rejects despite a wrong declared size', () async {
    final file = PlatformFile(
      name: 'owned.json',
      size: 0,
      readStream: Stream.fromIterable([
        Uint8List(SpotifyCsvImporter.maxJsonBytes),
        [1],
      ]),
    );
    await expectLater(
      SpotifyImportFileReader.read(file),
      throwsA(isA<SpotifyImportException>()),
    );
  });
  test(
    'cancellation stops pending owned read and rejects partial bytes',
    () async {
      var stopped = false;
      final source = StreamController<List<int>>(
        onCancel: () {
          stopped = true;
        },
      );
      final cancel = Completer<void>();
      final file = PlatformFile(
        name: 'owned.json',
        size: 20,
        readStream: source.stream,
      );
      final expectation = expectLater(
        SpotifyImportFileReader.read(file, cancelled: cancel.future),
        throwsA(isA<SpotifyImportException>()),
      );
      source.add([123]);
      cancel.complete();
      await expectation;
      expect(stopped, isTrue);
      await source.close();
    },
  );
  test('CSV and TSV keep their byte semantics and size policy', () async {
    for (final name in ['owned.csv', 'owned.tsv']) {
      final file = PlatformFile(
        name: name,
        size: SpotifyCsvImporter.maxJsonBytes + 1,
        readStream: Stream.fromIterable([
          [65, 9],
          [66, 10],
        ]),
      );
      expect(await SpotifyImportFileReader.read(file), [65, 9, 66, 10]);
    }
  });
  test(
    'read deadline closes a stalled stream and gives retryable feedback',
    () async {
      var stopped = false;
      final source = StreamController<List<int>>(
        onCancel: () {
          stopped = true;
        },
      );
      final file = PlatformFile(
        name: 'owned.json',
        size: 20,
        readStream: source.stream,
      );
      await expectLater(
        SpotifyImportFileReader.read(file),
        throwsA(
          isA<SpotifyImportException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      expect(stopped, isTrue);
      await source.close();
    },
  );
}
