import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const personalizedReleaseApiUrl =
    'https://api.github.com/repos/topcat432/musify-personalized/releases/latest';
const personalizedUpdateManifestAsset = 'musify-personalized-update.json';
const personalizedProductionPackage = 'com.topcat432.musifypersonalized';
const _maximumApkBytes = 200 * 1024 * 1024;

enum PersonalizedUpdateAvailability { available, current }

enum UpdateInstallStatus { launched, permissionRequired }

class PersonalizedUpdateCancellation {
  final Completer<void> _abort = Completer<void>();

  Future<void> get abortTrigger => _abort.future;

  bool get isCancelled => _abort.isCompleted;

  void cancel() {
    if (!_abort.isCompleted) _abort.complete();
  }
}

class InstalledAppIdentity {
  const InstalledAppIdentity({
    required this.packageName,
    required this.versionCode,
    required this.signerSha256,
  });

  factory InstalledAppIdentity.fromMap(Map<Object?, Object?> map) {
    return InstalledAppIdentity(
      packageName: map['packageName']?.toString() ?? '',
      versionCode: _readInt(map['versionCode'], 'versionCode'),
      signerSha256: map['signerSha256']?.toString().toLowerCase() ?? '',
    );
  }

  final String packageName;
  final int versionCode;
  final String signerSha256;
}

class PersonalizedUpdateManifest {
  const PersonalizedUpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.packageName,
    required this.signerSha256,
    required this.apkSha256,
    required this.apkUrl,
    required this.sourceCommit,
    required this.releaseNotes,
  });

  factory PersonalizedUpdateManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _readInt(json['schemaVersion'], 'schemaVersion');
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported personalized update manifest.');
    }

    final packageName = _readString(json, 'packageName');
    if (packageName != personalizedProductionPackage) {
      throw const FormatException('Update package identity is not allowed.');
    }

    final signerSha256 = _readHex(json, 'signerSha256', length: 64);
    final apkSha256 = _readHex(json, 'apkSha256', length: 64);
    final sourceCommit = _readHex(json, 'sourceCommit', length: 40);
    final apkUrl = Uri.parse(_readString(json, 'apkUrl'));
    _validateReleaseAssetUrl(apkUrl);

    return PersonalizedUpdateManifest(
      versionCode: _readInt(json['versionCode'], 'versionCode'),
      versionName: _readString(json, 'versionName'),
      packageName: packageName,
      signerSha256: signerSha256,
      apkSha256: apkSha256,
      apkUrl: apkUrl,
      sourceCommit: sourceCommit,
      releaseNotes: json['releaseNotes']?.toString().trim() ?? '',
    );
  }

  final int versionCode;
  final String versionName;
  final String packageName;
  final String signerSha256;
  final String apkSha256;
  final Uri apkUrl;
  final String sourceCommit;
  final String releaseNotes;

  PersonalizedUpdateManifest withReleaseNotes(String notes) {
    final cleanedNotes = notes.trim();
    if (cleanedNotes.isEmpty || releaseNotes.isNotEmpty) return this;
    return PersonalizedUpdateManifest(
      versionCode: versionCode,
      versionName: versionName,
      packageName: packageName,
      signerSha256: signerSha256,
      apkSha256: apkSha256,
      apkUrl: apkUrl,
      sourceCommit: sourceCommit,
      releaseNotes: cleanedNotes,
    );
  }
}

class PersonalizedUpdateCheck {
  const PersonalizedUpdateCheck({
    required this.availability,
    required this.installed,
    required this.manifest,
  });

  final PersonalizedUpdateAvailability availability;
  final InstalledAppIdentity installed;
  final PersonalizedUpdateManifest manifest;
}

class VerifiedPersonalizedUpdate {
  const VerifiedPersonalizedUpdate({
    required this.file,
    required this.manifest,
  });

  final File file;
  final PersonalizedUpdateManifest manifest;
}

abstract class PersonalizedUpdatePlatform {
  Future<InstalledAppIdentity> getInstalledIdentity();

  Future<void> verifyApk({
    required String path,
    required PersonalizedUpdateManifest manifest,
  });

  Future<UpdateInstallStatus> installApk(String path);
}

class AndroidPersonalizedUpdatePlatform implements PersonalizedUpdatePlatform {
  const AndroidPersonalizedUpdatePlatform();

  static const _channel = MethodChannel(
    'com.topcat432.musifypersonalized/updater',
  );

  @override
  Future<InstalledAppIdentity> getInstalledIdentity() async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'getInstalledIdentity',
    );
    if (response == null) {
      throw StateError('Android did not return the installed app identity.');
    }
    return InstalledAppIdentity.fromMap(response);
  }

  @override
  Future<void> verifyApk({
    required String path,
    required PersonalizedUpdateManifest manifest,
  }) async {
    await _channel.invokeMethod<void>('verifyUpdateApk', {
      'path': path,
      'expectedPackage': manifest.packageName,
      'expectedSignerSha256': manifest.signerSha256,
      'minimumVersionCode': manifest.versionCode,
    });
  }

  @override
  Future<UpdateInstallStatus> installApk(String path) async {
    final status = await _channel.invokeMethod<String>('installUpdateApk', {
      'path': path,
    });
    return switch (status) {
      'launched' => UpdateInstallStatus.launched,
      'permission_required' => UpdateInstallStatus.permissionRequired,
      _ => throw StateError('Android returned an unknown installer status.'),
    };
  }
}

class PersonalizedUpdateService {
  PersonalizedUpdateService({
    http.Client? client,
    PersonalizedUpdatePlatform? platform,
  }) : _client = client ?? http.Client(),
       _platform = platform ?? const AndroidPersonalizedUpdatePlatform();

  final http.Client _client;
  final PersonalizedUpdatePlatform _platform;

  Future<PersonalizedUpdateCheck> check() async {
    if (!Platform.isAndroid && _platform is AndroidPersonalizedUpdatePlatform) {
      throw UnsupportedError('Personalized APK updates require Android.');
    }

    final releaseResponse = await _client.get(
      Uri.parse(personalizedReleaseApiUrl),
      headers: _githubHeaders,
    );
    if (releaseResponse.statusCode == 404) {
      throw StateError('No personalized production update has been published.');
    }
    if (releaseResponse.statusCode != 200) {
      throw HttpException(
        'GitHub update check returned ${releaseResponse.statusCode}.',
      );
    }

    final release = _decodeObject(releaseResponse.body, 'GitHub release');
    if (release['draft'] == true || release['prerelease'] == true) {
      throw const FormatException('GitHub returned a non-production release.');
    }
    final manifestUrl = _findManifestAsset(release);
    final manifestResponse = await _client.get(
      manifestUrl,
      headers: _githubHeaders,
    );
    if (manifestResponse.statusCode != 200) {
      throw HttpException(
        'Update manifest download returned ${manifestResponse.statusCode}.',
      );
    }

    final manifest = PersonalizedUpdateManifest.fromJson(
      _decodeObject(manifestResponse.body, 'update manifest'),
    ).withReleaseNotes(release['body']?.toString() ?? '');
    final installed = await _platform.getInstalledIdentity();

    if (installed.packageName != personalizedProductionPackage) {
      throw StateError(
        'This build is ${installed.packageName}; production updates only replace '
        '$personalizedProductionPackage.',
      );
    }
    if (installed.signerSha256 != manifest.signerSha256) {
      throw StateError(
        'The published update was signed by a different Android key.',
      );
    }

    return PersonalizedUpdateCheck(
      availability: manifest.versionCode > installed.versionCode
          ? PersonalizedUpdateAvailability.available
          : PersonalizedUpdateAvailability.current,
      installed: installed,
      manifest: manifest,
    );
  }

  Future<VerifiedPersonalizedUpdate> downloadAndVerify(
    PersonalizedUpdateManifest manifest, {
    void Function(double? progress)? onProgress,
    Directory? targetRoot,
    PersonalizedUpdateCancellation? cancellation,
  }) async {
    final root = targetRoot ?? await getTemporaryDirectory();
    final updateDirectory = Directory('${root.path}/updates');
    await updateDirectory.create(recursive: true);
    final finalFile = File(
      '${updateDirectory.path}/musify-personalized-${manifest.versionCode}.apk',
    );
    final partialFile = File('${finalFile.path}.part');
    await _deleteIfPresent(partialFile);
    await _deleteIfPresent(finalFile);

    IOSink? sink;
    try {
      final request = http.AbortableRequest(
        'GET',
        manifest.apkUrl,
        abortTrigger: cancellation?.abortTrigger,
      )
        ..headers.addAll(_githubHeaders);
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        throw HttpException(
          'APK download returned ${response.statusCode}.',
        );
      }
      final contentLength = response.contentLength;
      if (contentLength != null && contentLength > _maximumApkBytes) {
        throw const FormatException('The update APK is unexpectedly large.');
      }

      sink = partialFile.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > _maximumApkBytes) {
          throw const FormatException('The update APK is unexpectedly large.');
        }
        sink.add(chunk);
        if (contentLength != null && contentLength > 0) {
          onProgress?.call(received / contentLength);
        } else {
          onProgress?.call(null);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      await partialFile.rename(finalFile.path);

      final digest = await sha256.bind(finalFile.openRead()).first;
      if (digest.toString().toLowerCase() != manifest.apkSha256) {
        throw const FormatException(
          'The downloaded APK checksum does not match the signed release.',
        );
      }
      await _platform.verifyApk(path: finalFile.path, manifest: manifest);
      onProgress?.call(1);
      return VerifiedPersonalizedUpdate(file: finalFile, manifest: manifest);
    } catch (_) {
      await sink?.close();
      await _deleteIfPresent(partialFile);
      await _deleteIfPresent(finalFile);
      rethrow;
    }
  }

  Future<UpdateInstallStatus> install(VerifiedPersonalizedUpdate update) {
    return _platform.installApk(update.file.path);
  }

  void close() => _client.close();
}

const _githubHeaders = {
  'Accept': 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'Musify-Personalized-Updater',
};

Map<String, dynamic> _decodeObject(String source, String label) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw FormatException('The $label is not a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

Uri _findManifestAsset(Map<String, dynamic> release) {
  final assets = release['assets'];
  if (assets is! List) {
    throw const FormatException('The GitHub release has no assets.');
  }
  for (final asset in assets) {
    if (asset is! Map || asset['name'] != personalizedUpdateManifestAsset) {
      continue;
    }
    final uri = Uri.parse(asset['browser_download_url']?.toString() ?? '');
    _validateReleaseAssetUrl(uri);
    return uri;
  }
  throw const FormatException(
    'The latest release has no personalized update manifest.',
  );
}

void _validateReleaseAssetUrl(Uri uri) {
  const prefix = '/topcat432/musify-personalized/releases/download/';
  if (uri.scheme != 'https' ||
      uri.host != 'github.com' ||
      !uri.path.startsWith(prefix)) {
    throw const FormatException('The update asset URL is not trusted.');
  }
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim() ?? '';
  if (value.isEmpty) throw FormatException('Missing update field: $key.');
  return value;
}

String _readHex(
  Map<String, dynamic> json,
  String key, {
  required int length,
}) {
  final value = _readString(json, key).toLowerCase();
  if (value.length != length || !RegExp(r'^[0-9a-f]+$').hasMatch(value)) {
    throw FormatException('Invalid update field: $key.');
  }
  return value;
}

int _readInt(Object? value, String key) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 1) {
    throw FormatException('Invalid update field: $key.');
  }
  return parsed;
}

Future<void> _deleteIfPresent(File file) async {
  if (await file.exists()) await file.delete();
}
