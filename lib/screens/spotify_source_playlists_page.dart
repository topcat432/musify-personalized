import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_destination_page.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import 'package:musify/widgets/personalized_ui.dart';

class SpotifySourcePlaylistsPage extends StatefulWidget {
  const SpotifySourcePlaylistsPage({
    super.key,
    this.preview,
    this.routingService = const SpotifyImportDestinationService(),
  });
  final List<SpotifySourcePlaylist>? preview;
  final SpotifyImportDestinationService routingService;
  @override
  State<SpotifySourcePlaylistsPage> createState() =>
      _SpotifySourcePlaylistsPageState();
}

class _SpotifySourcePlaylistsPageState
    extends State<SpotifySourcePlaylistsPage> {
  var selected = 0;
  @override
  Widget build(BuildContext context) {
    List<SpotifySourcePlaylist> sources;
    try {
      final metadata = Hive.isBoxOpen('user')
          ? Hive.box('user').get('spotifyImportMetadata')
          : null;
      sources =
          widget.preview ??
          SpotifySourcePlaylistCodec.readSaved(
            metadata is Map
                ? metadata[SpotifySourcePlaylistCodec.metadataKey]
                : null,
            Hive.isBoxOpen('user')
                ? Hive.box('user').get('spotifyImportTracks')
                : null,
          );
    } on FormatException catch (error) {
      return Scaffold(
        appBar: AppBar(title: const Text('Source playlists')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: PersonalizedStatusBanner(
            tone: PersonalizedStatusTone.error,
            title: 'Source data retained',
            message: error.message,
          ),
        ),
      );
    }
    if (sources.isEmpty)
      return Scaffold(
        appBar: AppBar(title: const Text('Source playlists')),
        body: const Center(
          child: Text('This import has no saved playlist membership.'),
        ),
      );
    final index = selected < sources.length ? selected : 0;
    final source = sources[index];
    return Scaffold(
      appBar: AppBar(title: const Text('Source playlists')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.preview == null
                        ? 'Saved source membership'
                        : 'Preview only; nothing saved',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Recording matches are shared across playlists. Source order and unsupported items are retained. Playlist recreation and synchronization are not implemented yet.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: index,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Source playlist',
                    ),
                    items: [
                      for (final (position, playlist) in sources.indexed)
                        DropdownMenuItem(
                          value: position,
                          child: Text(
                            '${position + 1}. ${playlist.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => selected = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('${source.members.length} source items'),
                  if (widget.preview == null)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        personalizedPageRoute<void>(
                          builder: (_) => SpotifyImportDestinationPage(
                            sourcePlaylistPosition: source.position,
                            routingService: widget.routingService,
                          ),
                        ),
                      ),
                      child: const Text('Route resolved songs'),
                    ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: source.members.length,
            itemBuilder: (context, position) {
              final member = source.members[position];
              return ListTile(
                leading: Text('${member.position}'),
                title: Text(
                  member.sourceMetadata['title'] ?? 'Unavailable item',
                ),
                subtitle: Text(
                  [
                    if (member.sourceMetadata['artist']?.isNotEmpty ?? false)
                      member.sourceMetadata['artist']!,
                    member.issue ?? 'Song retained',
                  ].join('\n'),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
