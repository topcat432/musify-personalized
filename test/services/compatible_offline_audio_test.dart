import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('compatible-offline-');
    Hive.init('${root.path}/hive');
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    applicationDirPath = '${root.path}/audio';
    await FilePaths.ensureDirectoriesExist();
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  for (final mode in ['complete', 'denied', 'truncated']) {
    test(
      'compatible download $mode publishes only a complete selected body',
      () async {
        const id = 'owned-dload';
        final uri = Uri.parse(
          'https://r.owned.googlevideo.com/videoplayback?clen=8&mime=video/mp4',
        );
        final muxed = MuxedStreamInfo(
          VideoId(id),
          18,
          uri,
          StreamContainer.mp4,
          const FileSize(8),
          const Bitrate(1000000),
          'mp4a.40.2',
          'avc1',
          '360p',
          VideoQuality.medium360,
          VideoResolution(640, 360),
          const Framerate(30),
          MediaType('video', 'mp4'),
        );
        final audio = AudioOnlyStreamInfo(
          VideoId(id),
          140,
          Uri.parse(
            'https://r.owned.googlevideo.com/audio?clen=8&mime=audio/mp4',
          ),
          StreamContainer.mp4,
          const FileSize(8),
          const Bitrate(128000),
          'mp4a.40.2',
          'medium',
          const [],
          MediaType('audio', 'mp4'),
          null,
        );
        var metadataCalls = 0;
        final requests = <http.Request>[];
        Future<OfflineAudioDownload?> loader(String selected) =>
            fetchCompatibleOfflineAudio(
              selected,
              manifestLoader: (selected) async {
                expect(selected, id);
                metadataCalls++;
                return StreamManifest([audio, muxed]);
              },
              clientFactory: () => MockClient((request) async {
                requests.add(request);
                expect(request.url, uri);
                expect(request.headers['Range'], 'bytes=0-7');
                return http.Response.bytes(
                  mode == 'truncated' ? [0, 1, 2, 3] : [0, 1, 2, 3, 4, 5, 6, 7],
                  mode == 'denied' ? 403 : 206,
                  headers: {'content-range': 'bytes 0-7/8'},
                  request: request,
                );
              }),
            );
        final song = {'ytid': id, 'title': 'Owned fixture', 'highResImage': ''};
        expect(
          await makeSongOffline(song, audioLoader: loader),
          mode == 'complete',
        );
        final saved =
            Hive.box('userNoBackup').get('offlineSongs', defaultValue: [])
                as List;
        if (mode == 'complete') {
          expect(saved.single['ytid'], id);
          expect(await File(saved.single['audioPath']).readAsBytes(), [
            0,
            1,
            2,
            3,
            4,
            5,
            6,
            7,
          ]);
          expect(await makeSongOffline(song, audioLoader: loader), true);
        } else {
          expect(saved, isEmpty);
          expect(await File(FilePaths.getAudioPath(id)).exists(), false);
        }
        expect(metadataCalls, 1);
        expect(requests, hasLength(1));
      },
    );
  }
}
