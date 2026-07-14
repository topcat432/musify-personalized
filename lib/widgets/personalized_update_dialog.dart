import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/services/personalized_update_service.dart';

class PersonalizedUpdateDialog extends StatefulWidget {
  const PersonalizedUpdateDialog({
    super.key,
    required this.check,
    required this.service,
  });

  final PersonalizedUpdateCheck check;
  final PersonalizedUpdateService service;

  @override
  State<PersonalizedUpdateDialog> createState() =>
      _PersonalizedUpdateDialogState();
}

enum _UpdateStage { available, downloading, verified, permission, error }

class _PersonalizedUpdateDialogState extends State<PersonalizedUpdateDialog> {
  _UpdateStage _stage = _UpdateStage.available;
  VerifiedPersonalizedUpdate? _verifiedUpdate;
  double? _progress;
  String? _error;

  bool get _busy => _stage == _UpdateStage.downloading;

  Future<void> _download() async {
    if (_busy) return;
    setState(() {
      _stage = _UpdateStage.downloading;
      _progress = 0;
      _error = null;
    });
    try {
      final update = await widget.service.downloadAndVerify(
        widget.check.manifest,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _verifiedUpdate = update;
        _stage = _UpdateStage.verified;
        _progress = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _UpdateStage.error;
        _error = error.toString();
      });
    }
  }

  Future<void> _install() async {
    final update = _verifiedUpdate;
    if (update == null || _busy) return;
    try {
      final result = await widget.service.install(update);
      if (!mounted) return;
      if (result == UpdateInstallStatus.launched) {
        Navigator.of(context).pop();
      } else {
        setState(() => _stage = _UpdateStage.permission);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _UpdateStage.error;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final manifest = widget.check.manifest;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _busy
              ? const SizedBox.square(
                  key: ValueKey('progress'),
                  dimension: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : Icon(
                  _stage == _UpdateStage.error
                      ? FluentIcons.warning_24_regular
                      : FluentIcons.arrow_download_24_regular,
                  key: ValueKey(_stage),
                  color: _stage == _UpdateStage.error
                      ? colors.error
                      : colors.primary,
                  size: 40,
                ),
        ),
        title: Text(
          _title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Musify Personalized ${manifest.versionName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_busy) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 10),
                Text(
                  _progress == null
                      ? 'Downloading signed APK…'
                      : 'Downloading ${((_progress ?? 0) * 100).round()}%',
                ),
              ] else
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              if (!_busy &&
                  _stage == _UpdateStage.available &&
                  manifest.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      manifest.releaseNotes,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!_busy)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          if (_stage == _UpdateStage.available ||
              _stage == _UpdateStage.error)
            FilledButton.icon(
              onPressed: _busy ? null : _download,
              icon: const Icon(FluentIcons.arrow_download_20_regular),
              label: Text(
                _stage == _UpdateStage.error ? 'Retry download' : 'Download',
              ),
            ),
          if (_stage == _UpdateStage.verified ||
              _stage == _UpdateStage.permission)
            FilledButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.install_mobile_rounded),
              label: Text(
                _stage == _UpdateStage.permission ? 'Try install again' : 'Install',
              ),
            ),
        ],
      ),
    );
  }

  String get _title => switch (_stage) {
    _UpdateStage.available => 'Personalized update available',
    _UpdateStage.downloading => 'Downloading update',
    _UpdateStage.verified => 'Verified and ready',
    _UpdateStage.permission => 'Allow updates from Musify',
    _UpdateStage.error => 'Update was not installed',
  };

  String get _message => switch (_stage) {
    _UpdateStage.available =>
      'This production APK is newer and uses your permanent Android signing key.',
    _UpdateStage.downloading => '',
    _UpdateStage.verified =>
      'Checksum, package identity, version code, and signing certificate all passed verification.',
    _UpdateStage.permission =>
      'Android opened the “Install unknown apps” setting. Allow Musify Personalized, return here, then try again.',
    _UpdateStage.error => _error ?? 'The update could not be verified.',
  };
}
