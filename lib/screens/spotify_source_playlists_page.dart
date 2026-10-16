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
  var creating = false;
  String? message;
  Future<void> reviewEmptySource(SpotifySourcePlaylist source) async {
    if (creating) return;
    setState(() {
      creating = true;
      message = null;
    });
    try {
      final snapshot = await widget.routingService.loadSourcePlaylistSnapshot(
        source.position,
      );
      if (snapshot.wholeSourceReadiness?.verifiedEmpty != true) {
        throw StateError(
          'The source is not verifiably empty. Its membership was retained; reload and review it.',
        );
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create empty source playlist?'),
          content: SingleChildScrollView(
            child: Text(
              '"${snapshot.sourceName}" has 0 source items. No songs will be transferred. A destination already linked to this source will be reused without changing its name, contents or location. Removed destinations will not be recreated automatically.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm empty playlist'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final result = await widget.routingService.createEmptySourcePlaylist(
        snapshot: snapshot,
      );
      if (!mounted) return;
      final status = result.verificationFailedAfterWrite
          ? 'Playlist "${result.destinationTitle}" was saved. Later verification is incomplete. 0 songs transferred.'
          : result.created
          ? 'Created empty playlist "${result.destinationTitle}". 0 songs transferred.'
          : 'Reused "${result.destinationTitle}" without changes. 0 songs transferred.';
      setState(() {
        message = result.trackingRecorded
            ? status
            : '$status Audit unverified; review before retrying.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          message = error is StateError
              ? error.message
              : 'Empty playlist creation could not be verified. Existing data was retained.';
        });
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }
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
                    'Recording matches are shared across playlists. Source order and unsupported items are retained. Nonempty sources can route resolved recordings. Empty sources can be created after confirmation; exact repeated slots and synchronization remain separate.',
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
                    onChanged: creating ? null : (value) {
                      if (value != null) setState(() => selected = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('${source.members.length} source items'),
                  if (message != null)
                    PersonalizedStatusBanner(title: 'Empty source action', message: message!),
                  if (widget.preview == null && source.members.isEmpty)
                    OutlinedButton(
                      onPressed: creating ? null : () => reviewEmptySource(source),
                      child: Text(creating ? 'Checking source…' : 'Review empty playlist creation'),
                    ),
                  if (widget.preview == null && source.members.isNotEmpty)
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
