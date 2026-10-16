enum PlaybackSourceKind { youtube, local, unknown }

/// Ephemeral attribution for the source actually loaded, never a library edit.
/// URLs, request headers and recording identifiers are deliberately omitted.
class PlaybackSourceInfo {
  const PlaybackSourceInfo(this.kind, {this.container, this.includesVideo});

  factory PlaybackSourceInfo.loaded(
    String location, {
    required bool isOffline,
  }) {
    if (isOffline) return const PlaybackSourceInfo(PlaybackSourceKind.local);
    final uri = Uri.tryParse(location);
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'googlevideo.com' ||
            uri.host.endsWith('.googlevideo.com'))) {
      return const PlaybackSourceInfo(PlaybackSourceKind.unknown);
    }
    final mime = uri.queryParameters['mime'];
    return PlaybackSourceInfo(
      PlaybackSourceKind.youtube,
      container: switch (mime) {
        'audio/mp4' || 'video/mp4' => 'MP4',
        'audio/webm' || 'video/webm' => 'WebM',
        _ => null,
      },
      includesVideo: switch (mime) {
        'video/mp4' || 'video/webm' => true,
        'audio/mp4' || 'audio/webm' => false,
        _ => null,
      },
    );
  }
  final PlaybackSourceKind kind;
  final String? container;
  final bool? includesVideo;
}
