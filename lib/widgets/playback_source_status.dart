import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/models/playback_source_info.dart';

class PlaybackSourceStatus extends StatelessWidget {
  const PlaybackSourceStatus({super.key, required this.stream});
  final Stream<PlaybackSourceInfo?> stream;

  @override
  Widget build(BuildContext context) => StreamBuilder<PlaybackSourceInfo?>(
    stream: stream,
    builder: (context, snapshot) {
      final source = snapshot.data;
      if (source == null) return const SizedBox.shrink();
      final l10n = context.l10n!;
      final provider = switch (source.kind) {
        PlaybackSourceKind.youtube => 'YouTube',
        PlaybackSourceKind.local => l10n.playbackSourceLocal,
        PlaybackSourceKind.unknown => l10n.playbackSourceUnknown,
      };
      final format = source.container;
      final label = format == null
          ? provider
          : '$provider · $format · ${source.includesVideo == true ? l10n.playbackSourceAudioVideo : l10n.playbackSourceAudio}';
      return TextButton.icon(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        icon: const Icon(FluentIcons.info_24_regular, size: 18),
        label: Text(label, textAlign: TextAlign.center),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.playbackSourceDetails),
            content: SingleChildScrollView(
              child: Text(
                '$label\n\n${source.kind == PlaybackSourceKind.local
                    ? l10n.playbackSourceLocalNote
                    : source.includesVideo == true
                    ? l10n.playbackSourceMuxedNote
                    : l10n.playbackSourceUnknownQualityNote}\n\n${l10n.playbackSourceCapabilities}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.understand),
              ),
            ],
          ),
        ),
      );
    },
  );
}
