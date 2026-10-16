import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_file_reader.dart';

void main() {
  test('ZIP declared and actual limits apply before any preview', () async {
    var listened = false;
    final stream = Stream<List<int>>.multi((c) {
      listened = true;
      c.close();
    });
    await expectLater(
      SpotifyImportFileReader.read(
        PlatformFile(
          name: 'owned.ZIP',
          size: SpotifyCsvImporter.maxJsonBytes + 1,
          readStream: stream,
        ),
      ),
      throwsA(isA<SpotifyImportException>()),
    );
    expect(listened, isFalse);
    await expectLater(
      SpotifyImportFileReader.read(
        PlatformFile(
          name: 'owned.zip',
          size: 0,
          readStream: Stream.fromIterable([
            Uint8List(SpotifyCsvImporter.maxJsonBytes),
            [1],
          ]),
        ),
      ),
      throwsA(isA<SpotifyImportException>()),
    );
  });
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
  test(
    'a streamed I/O error cancels the subscription and never returns partial bytes',
    () async {
      var stopped = false;
      final source = StreamController<List<int>>(
        onCancel: () {
          stopped = true;
        },
      );
      final error = StateError('Owned read failure');
      final file = PlatformFile(
        name: 'owned.json',
        size: 10,
        readStream: source.stream,
      );
      final expectation = expectLater(
        SpotifyImportFileReader.read(file),
        throwsA(same(error)),
      );
      source.add([123]);
      source.addError(error);
      await expectation;
      expect(stopped, isTrue);
      await source.close();
    },
  );

  test(
    'the selected-path fallback reads only its owned file and leaves it unchanged',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'json-reader-selected-',
      );
      try {
        final file = File('${root.path}/selected.json');
        final contents = Uint8List.fromList([123, 34, 97, 34, 58, 49, 125]);
        await file.writeAsBytes(contents, flush: true);
        final selected = PlatformFile(
          name: 'selected.json',
          size: contents.length,
          path: file.path,
        );
        expect(await SpotifyImportFileReader.read(selected), contents);
        expect(await file.readAsBytes(), contents);
        expect(await root.list().length, 1);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'stalled onCancel cannot keep the read timeout pending indefinitely',
    () {
      fakeAsync((clock) {
        final cleanup = Completer<void>();
        var cancelCalls = 0;
        var ended = false;
        Object? error;
        final source = StreamController<List<int>>(
          onCancel: () {
            cancelCalls++;
            return cleanup.future;
          },
        );
        SpotifyImportFileReader.read(
          PlatformFile(name: 'owned.json', size: 1, readStream: source.stream),
        ).then<void>(
          (_) => fail('Stalled read returned bytes'),
          onError: (Object e) {
            ended = true;
            error = e;
          },
        );
        clock.flushMicrotasks();
        source.add([123]);
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 22));
        clock.flushMicrotasks();
        expect(cancelCalls, 1);
        expect(ended, isTrue);
        expect(error, isA<SpotifyImportException>());
        cleanup.completeError(StateError('Late owned cleanup failure'));
        clock.flushMicrotasks();
        source.close();
        clock.flushMicrotasks();
      });
    },
  );
}
