import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/theme/app_shape.dart';
import 'package:musify/theme/app_spacing.dart';

class PlaybackSourceError extends StatelessWidget {
  const PlaybackSourceError({
    super.key,
    required this.stream,
    required this.onOpenLibrary,
  });
  final Stream<PlaybackState> stream;
  final VoidCallback onOpenLibrary;
  @override
  Widget build(BuildContext context) => StreamBuilder<PlaybackState>(
    stream: stream,
    builder: (context, snapshot) {
      final message = snapshot.data?.errorMessage;
      if (message == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.compactGap,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: AppShape.status,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.normalGap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      FluentIcons.warning_24_regular,
                      size: 22,
                      color: colors.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.compactGap),
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onOpenLibrary,
                    child: const Text('Library'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
