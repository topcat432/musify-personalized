import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musify/services/personalized_update_service.dart';

void main() {
  const signer =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const sourceCommit = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  final apkBytes = utf8.encode('verified personalized apk fixture');
  final apkSha = sha256.convert(apkBytes).toString();

  Map<String, dynamic> manifestJson({int versionCode = 300000003}) => {
    'schemaVersion': 1,
    'versionCode': versionCode,
    'versionName': '0.1.$versionCode',
    'packageName': personalizedProductionPackage,
    'signerSha256': signer,
    'apkSha256': apkSha,
    'apkUrl':
        'https://github.com/topcat432/musify-personalized/releases/download/personalized-v$versionCode/musify-personalized-production.apk',
    'sourceCommit': sourceCommit,
    'releaseNotes': 'Verified test release.',
  };

  MockClient updateClient(Map<String, dynamic> manifest) {
    return MockClient((request) async {
      if (request.url.toString() == personalizedReleaseApiUrl) {
        return http.Response(
          jsonEncode({
            'draft': false,
            'prerelease': false,
            'body': 'GitHub release notes.',
            'assets': [
              {
                'name': personalizedUpdateManifestAsset,
                'browser_download_url':
                    'https://github.com/topcat432/musify-personalized/releases/download/personalized-v300000003/$personalizedUpdateManifestAsset',
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith(personalizedUpdateManifestAsset)) {
        return http.Response(jsonEncode(manifest), 200);
      }
      if (request.url.path.endsWith('.apk')) {
        return http.Response.bytes(apkBytes, 200);
      }
      return http.Response('not found', 404);
    });
  }

  test(
    'retains installed preview identity and rejects the old separate app',
    () {
      expect(
        personalizedProductionPackage,
        'com.topcat432.musifypersonalized.preview',
      );
      final oldPackage = manifestJson()
        ..['packageName'] = 'com.topcat432.musifypersonalized';
      expect(
        () => PersonalizedUpdateManifest.fromJson(oldPackage),
        throwsA(isA<FormatException>()),
      );
      final identity = InstalledAppIdentity.fromMap({
        'packageName': personalizedProductionPackage,
        'versionName': 'preview.0.1.1',
        'versionCode': 300000001,
        'signerSha256': signer,
      });
      expect(identity.versionName, 'preview.0.1.1');
      expect(identity.versionCode, 300000001);
    },
  );

  test(
    'offers a signed personalized release with a higher version code',
    () async {
      final platform = _FakeUpdatePlatform(
        identity: const InstalledAppIdentity(
          packageName: personalizedProductionPackage,
          versionCode: 300000001,
          signerSha256: signer,
        ),
      );
      final service = PersonalizedUpdateService(
        client: updateClient(manifestJson()),
        platform: platform,
      );

      final result = await service.check();

      expect(result.availability, PersonalizedUpdateAvailability.available);
      expect(result.manifest.versionCode, 300000003);
      expect(result.manifest.apkSha256, apkSha);
      service.close();
    },
  );

  test(
    'reports current when the published build is already installed',
    () async {
      final service = PersonalizedUpdateService(
        client: updateClient(manifestJson()),
        platform: _FakeUpdatePlatform(
          identity: const InstalledAppIdentity(
            packageName: personalizedProductionPackage,
            versionCode: 300000003,
            signerSha256: signer,
          ),
        ),
      );

      final result = await service.check();

      expect(result.availability, PersonalizedUpdateAvailability.current);
      service.close();
    },
  );

  test('rejects a release signed by a different Android key', () async {
    final service = PersonalizedUpdateService(
      client: updateClient(manifestJson()),
      platform: _FakeUpdatePlatform(
        identity: const InstalledAppIdentity(
          packageName: personalizedProductionPackage,
          versionCode: 300000001,
          signerSha256:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        ),
      ),
    );

    await expectLater(service.check(), throwsA(isA<StateError>()));
    service.close();
  });

  test('downloads, hashes, and asks Android to inspect the APK', () async {
    final directory = await Directory.systemTemp.createTemp('musify-update-');
    final platform = _FakeUpdatePlatform(
      identity: const InstalledAppIdentity(
        packageName: personalizedProductionPackage,
        versionCode: 300000001,
        signerSha256: signer,
      ),
    );
    final service = PersonalizedUpdateService(
      client: updateClient(manifestJson()),
      platform: platform,
    );
    final manifest = PersonalizedUpdateManifest.fromJson(manifestJson());

    final update = await service.downloadAndVerify(
      manifest,
      targetRoot: directory,
    );

    expect(await update.file.readAsBytes(), apkBytes);
    expect(platform.verifiedPaths, [update.file.path]);
    service.close();
    await directory.delete(recursive: true);
  });

  test('rejects update assets outside the personalized GitHub release', () {
    final json = manifestJson()..['apkUrl'] = 'https://example.com/musify.apk';

    expect(
      () => PersonalizedUpdateManifest.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('download cancellation completes its abort trigger once', () async {
    final cancellation = PersonalizedUpdateCancellation();
    var completionCount = 0;
    final completion = cancellation.abortTrigger.then((_) => completionCount++);

    cancellation.cancel();
    cancellation.cancel();
    await completion;
    await Future<void>.delayed(Duration.zero);

    expect(cancellation.isCancelled, isTrue);
    expect(completionCount, 1);
  });
}

class _FakeUpdatePlatform implements PersonalizedUpdatePlatform {
  _FakeUpdatePlatform({required this.identity});

  final InstalledAppIdentity identity;
  final List<String> verifiedPaths = [];

  @override
  Future<InstalledAppIdentity> getInstalledIdentity() async => identity;

  @override
  Future<UpdateInstallStatus> installApk(String path) async {
    return UpdateInstallStatus.launched;
  }

  @override
  Future<void> verifyApk({
    required String path,
    required PersonalizedUpdateManifest manifest,
  }) async {
    verifiedPaths.add(path);
  }
}
