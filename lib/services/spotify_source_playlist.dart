class SpotifyPlaylistMember {
  const SpotifyPlaylistMember({
    required this.position,
    required this.sourceRow,
    required this.issue,
    this.sourceMetadata = const {},
  });
  final int position;
  final int? sourceRow;
  final String? issue;
  final Map<String, String> sourceMetadata;
}

class SpotifySourcePlaylist {
  const SpotifySourcePlaylist({
    required this.position,
    required this.name,
    required this.spotifyUri,
    required this.members,
  });
  final int position;
  final String name;
  final String? spotifyUri;
  final List<SpotifyPlaylistMember> members;
}

class SpotifySourcePlaylistCodec {
  const SpotifySourcePlaylistCodec._();
  static const metadataKey = 'sourcePlaylists';
  static Map<String, dynamic> encode(List<SpotifySourcePlaylist> playlists) {
    final value = <String, dynamic>{
      'version': 1,
      'playlists': [
        for (final playlist in playlists)
          <String, dynamic>{
            'position': playlist.position,
            'name': playlist.name,
            'spotifyUri': playlist.spotifyUri,
            'members': [
              for (final member in playlist.members)
                <String, dynamic>{
                  'position': member.position,
                  'sourceRow': member.sourceRow,
                  'issue': member.issue,
                  'sourceMetadata': Map<String, String>.from(
                    member.sourceMetadata,
                  ),
                },
            ],
          },
      ],
    };
    decode(value);
    return value;
  }

  static List<SpotifySourcePlaylist> decode(Object? value) {
    if (value == null) return const [];
    Never fail() => throw const FormatException(
      'Stored playlist membership is unsupported or damaged. The original import was retained.',
    );
    if (value is! Map ||
        value['version'] is! int ||
        value['version'] != 1 ||
        value['playlists'] is! List ||
        (value['playlists'] as List).length > 200) {
      fail();
    }
    final output = <SpotifySourcePlaylist>[];
    var total = 0;
    for (final (index, playlist) in (value['playlists'] as List).indexed) {
      if (playlist is! Map ||
          playlist['position'] != index + 1 ||
          playlist['name'] is! String ||
          (playlist['name'] as String).trim().isEmpty ||
          playlist['members'] is! List) {
        fail();
      }
      final uri = playlist['spotifyUri'];
      if (uri != null &&
          (uri is! String ||
              !RegExp(r'^spotify:playlist:[A-Za-z0-9]{22}$').hasMatch(uri))) {
        fail();
      }
      total += (playlist['members'] as List).length;
      if (total > 10000) {
        fail();
      }
      final members = <SpotifyPlaylistMember>[];
      for (final (position, member) in (playlist['members'] as List).indexed) {
        if (member is! Map || member['position'] != position + 1) {
          fail();
        }
        final row = member['sourceRow'],
            issue = member['issue'],
            metadata = member['sourceMetadata'];
        if ((row != null && (row is! int || row < 1 || row > 10000)) ||
            (issue != null && (issue is! String || issue.isEmpty)) ||
            (row == null) == (issue == null) ||
            metadata is! Map ||
            metadata.keys.any(
              (key) => !const [
                'title',
                'artist',
                'album',
                'uri',
                'addedAt',
              ].contains(key),
            ) ||
            metadata.values.any((entry) => entry is! String)) {
          fail();
        }
        members.add(
          SpotifyPlaylistMember(
            position: position + 1,
            sourceRow: row as int?,
            issue: issue as String?,
            sourceMetadata: Map<String, String>.unmodifiable(
              Map<String, String>.from(metadata),
            ),
          ),
        );
      }
      output.add(
        SpotifySourcePlaylist(
          position: index + 1,
          name: playlist['name'] as String,
          spotifyUri: uri as String?,
          members: List.unmodifiable(members),
        ),
      );
    }
    return List.unmodifiable(output);
  }
}
