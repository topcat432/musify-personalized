import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../support/spotify_zip_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_incoming_file_inbox.dart';

void main() {
  SpotifyIncomingFile file(
    String id, {
    Uri? uri,
    String name = 'songs.csv',
    bool grant = true,
    int? size,
  }) => SpotifyIncomingFile(
    id: id,
    uri: uri ?? Uri.parse('content://owned.provider/$id'),
    name: name,
    readGrantVerified: grant,
    size: size,
  );
  test('supported metadata requires content URI and verified read grant', () {
    expect(
      () => file('a', grant: false),
      throwsA(isA<SpotifyImportException>()),
    );
    for (final uri in [
      Uri.parse('https://example.invalid/file.csv'),
      Uri.parse('file:///private/file.csv'),
      Uri.parse('content://user@provider/file'),
    ]) {
      expect(() => file('a', uri: uri), throwsA(isA<SpotifyImportException>()));
    }
    for (final name in ['../songs.csv', 'song\n.csv', 'private.apk']) {
      expect(
        () => file('a', name: name),
        throwsA(isA<SpotifyImportException>()),
      );
    }
    expect(file('a', name: '曲.JSON').name, '曲.JSON');
  });
  test(
    'declared size boundaries reject before a read; unknown size is explicit',
    () {
      expect(file('a').size, isNull);
      expect(
        file('a', size: SpotifyCsvImporter.maxJsonBytes).size,
        SpotifyCsvImporter.maxJsonBytes,
      );
      expect(
        () => file('a', size: SpotifyCsvImporter.maxJsonBytes + 1),
        throwsA(isA<SpotifyImportException>()),
      );
      expect(() => file('a', size: -1), throwsA(isA<SpotifyImportException>()));
    },
  );
  test(
    'one explicit active read preserves pending arrival order and duplicate offers',
    () {
      final inbox = SpotifyIncomingFileInbox();
      expect(inbox.offer(file('a')), SpotifyIncomingFileOffer.queued);
      inbox.offer(file('b'));
      final first = inbox.begin('a');
      expect(first.file.id, 'a');
      expect(
        inbox.offer(file('again', uri: file('a').uri)),
        SpotifyIncomingFileOffer.duplicate,
      );
      expect(() => inbox.begin('b'), throwsStateError);
      expect(inbox.pending.map((e) => e.id), ['b']);
      expect(inbox.finish(first), isTrue);
      expect(inbox.begin('b').file.id, 'b');
    },
  );
  test(
    'late prior completion cannot release or replace a newer active request',
    () {
      final inbox = SpotifyIncomingFileInbox();
      inbox.offer(file('a'));
      inbox.offer(file('b'));
      final prior = inbox.begin('a');
      inbox.finish(prior);
      inbox.begin('b');
      expect(inbox.finish(prior), isFalse);
      expect(inbox.active!.id, 'b');
    },
  );
  test('full queue and identity conflict retain every current request', () {
    final inbox = SpotifyIncomingFileInbox();
    for (var i = 0; i < 4; i++) {
      inbox.offer(file('$i'));
    }
    expect(inbox.offer(file('extra')), SpotifyIncomingFileOffer.full);
    expect(
      () => inbox.offer(
        file('0', uri: Uri.parse('content://owned.provider/different')),
      ),
      throwsStateError,
    );
    expect(inbox.pending.map((e) => e.id), ['0', '1', '2', '3']);
    expect(() => inbox.pending.clear(), throwsUnsupportedError);
  });
  test('explicit dismissal only removes its selected pending request', () {
    final inbox = SpotifyIncomingFileInbox();
    inbox.offer(file('a'));
    inbox.offer(file('b'));
    expect(inbox.dismiss('a'), isTrue);
    expect(inbox.pending.single.id, 'b');
    expect(inbox.dismiss('missing'), isFalse);
    expect(() => inbox.begin('a'), throwsStateError);
  });
  test(
    'a reused request label cannot let its older completion release the new lease',
    () {
      final inbox = SpotifyIncomingFileInbox();
      inbox.offer(file('same'));
      final old = inbox.begin('same');
      inbox.finish(old);
      inbox.offer(file('same', uri: Uri.parse('content://owned.provider/new')));
      final current = inbox.begin('same');
      expect(inbox.finish(old), isFalse);
      expect(inbox.active!.uri, current.file.uri);
      expect(inbox.finish(current), isTrue);
    },
  );
  test(
    'offers never open bytes; only the active explicit lease can preview',
    () async {
      final inbox = SpotifyIncomingFileInbox();
      var opened = 0;
      Stream<List<int>> open(SpotifyIncomingFile file) {
        opened++;
        return Stream.value(utf8.encode('Title,Artist\nOwned,Artist\n'));
      }

      inbox.offer(file('a'));
      expect(opened, 0);
      final lease = inbox.begin('a');
      final preview = await inbox.readPreview(lease, openStream: open);
      expect(preview.tracks.single.title, 'Owned');
      expect(inbox.active!.id, 'a');
      expect(opened, 1);
      inbox.finish(lease);
      await expectLater(
        inbox.readPreview(lease, openStream: open),
        throwsA(isA<SpotifyImportException>()),
      );
      expect(opened, 1);
    },
  );
  test(
    'unknown-size incoming CSV is bounded and its owned subscription cancels',
    () async {
      final inbox = SpotifyIncomingFileInbox();
      inbox.offer(file('a'));
      final lease = inbox.begin('a');
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final result = inbox.readPreview(lease, openStream: (_) => stream.stream);
      final assertion = expectLater(
        result,
        throwsA(isA<SpotifyImportException>()),
      );
      stream.add(Uint8List(SpotifyCsvImporter.maxJsonBytes + 1));
      await assertion;
      expect(cancelled, isTrue);
      expect(inbox.active!.id, 'a');
      await stream.close();
    },
  );
  test(
    'overlap rejects and cancellation cannot release a newer lease',
    () async {
      final inbox = SpotifyIncomingFileInbox();
      inbox.offer(file('a'));
      inbox.offer(file('b'));
      final old = inbox.begin('a');
      final stream = StreamController<List<int>>();
      final reading = inbox.readPreview(old, openStream: (_) => stream.stream);
      final assertion = expectLater(
        reading,
        throwsA(isA<SpotifyImportException>()),
      );
      await expectLater(
        inbox.readPreview(
          old,
          openStream: (_) => throw StateError('must not open'),
        ),
        throwsStateError,
      );
      inbox.finish(old);
      final current = inbox.begin('b');
      await assertion;
      expect(inbox.active!.id, 'b');
      expect(inbox.finish(old), isFalse);
      expect(inbox.finish(current), isTrue);
      await stream.close();
    },
  );
  test(
    'ZIP preview requires explicit entry choice and retains source metadata',
    () async {
      final inbox = SpotifyIncomingFileInbox();
      inbox.offer(file('a', name: 'account.zip'));
      final lease = inbox.begin('a');
      await expectLater(
        inbox.readPreview(
          lease,
          openStream: (_) => Stream.value(SpotifyZipFixtures.membershipLists()),
        ),
        throwsA(isA<SpotifyImportException>()),
      );
      final preview = await inbox.readPreview(
        lease,
        openStream: (_) => Stream.value(SpotifyZipFixtures.membershipLists()),
        chooseArchiveEntry: (entries) async {
          expect(entries, ['YourLibrary.json', 'Playlist.json']);
          return 'Playlist.json';
        },
      );
      expect(preview.sourceEntryName, 'Playlist.json');
      expect(preview.sourcePlaylists.single.name, 'One');
      expect(preview.sourcePlaylists.single.members.map((m) => m.sourceRow), [
        1,
        null,
      ]);
      expect(inbox.active!.id, 'a');
    },
  );
  test(
    'pending archive choice settles on cancellation and late choice is ignored',
    () async {
      final inbox = SpotifyIncomingFileInbox();
      inbox.offer(file('a', name: 'account.zip'));
      inbox.offer(file('b'));
      final lease = inbox.begin('a');
      final choosing = Completer<void>();
      final choice = Completer<String?>();
      final reading = inbox.readPreview(
        lease,
        openStream: (_) => Stream.value(SpotifyZipFixtures.membershipLists()),
        chooseArchiveEntry: (_) {
          choosing.complete();
          return choice.future;
        },
      );
      final assertion = expectLater(
        reading,
        throwsA(isA<SpotifyImportException>()),
      );
      await choosing.future;
      inbox.finish(lease);
      inbox.begin('b');
      await assertion;
      choice.completeError(StateError('late provider error'));
      await Future<void>.delayed(Duration.zero);
      expect(inbox.active!.id, 'b');
    },
  );
}
