import 'package:flutter/material.dart';
import 'package:musify/services/personalized_update_service.dart';
import 'package:musify/widgets/personalized_ui.dart';

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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final quickMotion = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final contentMotion = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 260);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        icon: AnimatedSwitcher(
          duration: quickMotion,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: _UpdateStageIcon(
            key: ValueKey(_stage),
            stage: _stage,
            busy: _busy,
          ),
        ),
        title: Text(
          _title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: AnimatedSize(
          duration: contentMotion,
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: contentMotion,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Semantics(
              key: ValueKey(_stage),
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        'PRODUCTION  •  ${manifest.versionName}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_busy) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _progress == null
                          ? 'Downloading signed APK…'
                          : 'Downloading ${((_progress ?? 0) * 100).round()}%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ] else
                    PersonalizedStatusBanner(
                      tone: _tone,
                      icon: _statusIcon,
                      message: _message,
                    ),
                  if (!_busy &&
                      _stage == _UpdateStage.available &&
                      manifest.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    PersonalizedSurface(
                      padding: const EdgeInsets.all(13),
                      borderRadius: 18,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: SingleChildScrollView(
                          child: Text(
                            manifest.releaseNotes,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(height: 1.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!_busy)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                _stage == _UpdateStage.available ? 'Not now' : 'Close',
              ),
            ),
          if (_stage == _UpdateStage.available ||
              _stage == _UpdateStage.error)
            FilledButton.icon(
              onPressed: _verifiedUpdate == null ? _download : _install,
              icon: Icon(
                _verifiedUpdate == null
                    ? Icons.download_rounded
                    : Icons.install_mobile_rounded,
              ),
              label: Text(
                _stage == _UpdateStage.error
                    ? _verifiedUpdate == null
                          ? 'Retry download'
                          : 'Retry install'
                    : 'Download',
              ),
            ),
          if (_stage == _UpdateStage.verified ||
              _stage == _UpdateStage.permission)
            FilledButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.install_mobile_rounded),
              label: Text(
                _stage == _UpdateStage.permission
                    ? 'Try install again'
                    : 'Install',
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
    _UpdateStage.error => _friendlyError,
  };

  PersonalizedStatusTone get _tone => switch (_stage) {
    _UpdateStage.verified => PersonalizedStatusTone.success,
    _UpdateStage.permission => PersonalizedStatusTone.warning,
    _UpdateStage.error => PersonalizedStatusTone.error,
    _ => PersonalizedStatusTone.neutral,
  };

  IconData get _statusIcon => switch (_stage) {
    _UpdateStage.available => Icons.security_update_good_rounded,
    _UpdateStage.downloading => Icons.download_rounded,
    _UpdateStage.verified => Icons.verified_rounded,
    _UpdateStage.permission => Icons.settings_rounded,
    _UpdateStage.error => Icons.error_outline_rounded,
  };

  String get _friendlyError {
    var message = _error ?? 'The update could not be verified.';
    for (final prefix in const [
      'Exception: ',
      'StateError: ',
      'FormatException: ',
    ]) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length);
      }
    }
    return message;
  }
}

class _UpdateStageIcon extends StatelessWidget {
  const _UpdateStageIcon({
    required this.stage,
    required this.busy,
    super.key,
  });

  final _UpdateStage stage;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isError = stage == _UpdateStage.error;
    final background = isError
        ? colors.errorContainer
        : colors.primaryContainer;
    final foreground = isError
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: 54,
        child: Center(
          child: busy
              ? SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: foreground,
                  ),
                )
              : Icon(
                  stage == _UpdateStage.verified
                      ? Icons.verified_rounded
                      : stage == _UpdateStage.permission
                      ? Icons.settings_rounded
                      : isError
                      ? Icons.error_outline_rounded
                      : Icons.system_update_alt_rounded,
                  color: foreground,
                  size: 29,
                ),
        ),
      ),
    );
  }
}
