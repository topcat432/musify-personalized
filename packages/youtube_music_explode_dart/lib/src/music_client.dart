import 'package:youtube_explode_dart/youtube_explode_dart.dart';

typedef _JsonMap = Map<String, dynamic>;

/// A canonical YouTube Music artist result.
class MusicArtist {
  const MusicArtist({required this.id, required this.name, this.thumbnailUrl});

  /// Canonical `UC...` artist channel id.
  final String id;

  /// Display name returned by YouTube Music.
  final String name;

  /// Artist avatar URL, when YouTube Music exposes one.
  final String? thumbnailUrl;
}

/// A release (album, single or EP) as listed on a YouTube Music artist page.
class MusicAlbum {
  const MusicAlbum(this.id, this.title, {this.thumbnailUrl});

  /// Browse id of the release, e.g. `MPREb_...`.
  final String id;

  /// Display title of the release.
  final String title;

  /// Release artwork URL, when YouTube Music exposes one.
  final String? thumbnailUrl;

  @override
  String toString() => 'MusicAlbum($id, $title)';
}

/// A song-only YouTube Music search result.
class MusicSong {
  const MusicSong({
    required this.id,
    required this.title,
    required this.artists,
    this.album,
    this.duration,
    this.thumbnailUrl,
    this.explicit = false,
  });

  /// Playable YouTube video id.
  final String id;

  /// Canonical song title returned by YouTube Music.
  final String title;

  /// Structured artist names associated with the song.
  final List<String> artists;

  /// Album or single title, when YouTube Music exposes it.
  final String? album;

  /// Track duration, when available.
  final Duration? duration;

  /// Artwork URL, when available.
  final String? thumbnailUrl;

  /// Whether YouTube Music marks the result explicit.
  final bool explicit;
}

/// Queries the YouTube Music (`WEB_REMIX`) browse endpoints.
class MusicClient {
  /// Initializes an instance of [MusicClient].
  const MusicClient(this._httpClient);

  final YoutubeHttpClient _httpClient;

  static const _remixContext = {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240101.01.00',
      'hl': 'en',
    },
  };

  /// Search filter that restricts results to artists only.
  static const _artistsSearchParams = 'EgWKAQIgAWoMEA4QChADEAQQCRAF';

  /// Search filter that restricts results to songs only.
  static const _songsSearchParams =
      'EgWKAQIIAWoKEAkQChAFEAMQBA%3D%3D';

  static const _artistPageType = 'MUSIC_PAGE_TYPE_ARTIST';
  static const _albumPageType = 'MUSIC_PAGE_TYPE_ALBUM';

  /// Searches YouTube Music for canonical artist entries matching [query].
  Future<List<MusicArtist>> searchArtists(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final root = await _httpClient.sendPost('search', {
      'context': _remixContext,
      'query': normalizedQuery,
      'params': _artistsSearchParams,
    });

    final results = <MusicArtist>[];
    final seen = <String>{};
    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final endpoint = item
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint');
      final id = endpoint?.getValue<String>('browseId');
      if (id == null || !id.startsWith('UC') || !seen.add(id)) continue;

      final pageType = endpoint
          ?.getMap('browseEndpointContextSupportedConfigs')
          ?.getMap('browseEndpointContextMusicConfig')
          ?.getValue<String>('pageType');
      if (pageType != _artistPageType) continue;

      final name = _firstFlexColumnText(item) ?? '';
      if (name.trim().isEmpty) continue;

      results.add(
        MusicArtist(
          id: id,
          name: name.trim(),
          thumbnailUrl: _listItemThumbnailUrl(item),
        ),
      );
    }
    return results;
  }

  /// Searches the song-only YouTube Music catalog matching [query].
  Future<List<MusicSong>> searchSongs(String query, {int limit = 10}) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || limit <= 0) return [];

    final root = await _httpClient.sendPost('search', {
      'context': _remixContext,
      'query': normalizedQuery,
      'params': _songsSearchParams,
    });

    final results = <MusicSong>[];
    final seen = <String>{};
    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _trackVideoId(item);
      if (videoId == null || !seen.add(videoId)) continue;

      final title = _firstFlexColumnText(item)?.trim() ?? '';
      if (title.isEmpty) continue;

      final artists = _songArtists(item);
      if (artists.isEmpty) continue;

      results.add(
        MusicSong(
          id: videoId,
          title: title,
          artists: List.unmodifiable(artists),
          album: _songAlbum(item),
          duration: _parseDuration(_fixedColumnText(item)),
          thumbnailUrl: _listItemThumbnailUrl(item),
          explicit: item.toString().contains('MUSIC_EXPLICIT_BADGE'),
        ),
      );
      if (results.length >= limit) break;
    }

    return results;
  }

  /// Returns the full discography (albums, singles and EPs) of a YouTube Music
  /// artist.
  Future<List<MusicAlbum>> getArtistReleases(dynamic channelId) async {
    final id = ChannelId.fromString(channelId).value;
    final root = await _browse(id);

    final releases = <String, MusicAlbum>{};
    _collectReleases(root, releases);

    for (final more in _collectMoreReleaseBrowses(root)) {
      try {
        final grid = await _browse(more.$1, params: more.$2);
        _collectReleases(grid, releases);
      } catch (_) {
        // Keep inline releases if a secondary grid fails.
      }
    }

    return releases.values.toList();
  }

  /// Returns the top tracks shown on the YouTube Music artist page.
  Future<List<Video>> getArtistTopTracks(
    dynamic channelId, {
    required String author,
    int limit = 10,
  }) async {
    final id = ChannelId.fromString(channelId).value;
    final root = await _browse(id);
    final resolvedChannelId = ChannelId(id);
    final videos = <Video>[];
    final seen = <String>{};

    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _trackVideoId(item);
      if (videoId == null || !seen.add(videoId)) continue;

      final title = _firstFlexColumnText(item);
      if (title == null || title.isEmpty) continue;

      videos.add(
        Video(
          VideoId(videoId),
          title,
          author,
          resolvedChannelId,
          null,
          null,
          null,
          '',
          _parseDuration(_fixedColumnText(item)),
          ThumbnailSet(videoId),
          null,
          const Engagement(0, null, null),
          false,
        ),
      );
      if (videos.length >= limit) break;
    }

    return videos;
  }

  /// Returns the tracks of a release as [Video]s.
  Future<List<Video>> getAlbumTracks(
    String albumBrowseId, {
    required String author,
    String? channelId,
  }) async {
    final root = await _browse(albumBrowseId);
    final resolvedChannelId = (channelId != null && channelId.isNotEmpty)
        ? ChannelId.fromString(channelId)
        : ChannelId('UC0000000000000000000000');

    final videos = <Video>[];
    final seen = <String>{};
    for (final item in _findRenderers(
      root,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _trackVideoId(item);
      if (videoId == null || !seen.add(videoId)) continue;

      final title = _firstFlexColumnText(item);
      if (title == null || title.isEmpty) continue;

      videos.add(
        Video(
          VideoId(videoId),
          title,
          author,
          resolvedChannelId,
          null,
          null,
          null,
          '',
          _parseDuration(_fixedColumnText(item)),
          ThumbnailSet(videoId),
          null,
          const Engagement(0, null, null),
          false,
        ),
      );
    }

    return videos;
  }

  Future<_JsonMap> _browse(String browseId, {String? params}) {
    return _httpClient.sendPost('browse', {
      'context': _remixContext,
      'browseId': browseId,
      if (params != null) 'params': params,
    });
  }

  void _collectReleases(_JsonMap root, Map<String, MusicAlbum> into) {
    for (final item in _findRenderers(root, 'musicTwoRowItemRenderer')) {
      final browseId = item
          .getMap('navigationEndpoint')
          ?.getMap('browseEndpoint')
          ?.getValue<String>('browseId');
      if (browseId == null || !browseId.startsWith('MPRE')) continue;

      final title = item
          .getMap('title')
          ?.getList('runs')
          ?.whereType<Map>()
          .parseRuns();
      into.putIfAbsent(
        browseId,
        () => MusicAlbum(
          browseId,
          title?.trim() ?? '',
          thumbnailUrl: _twoRowThumbnailUrl(item),
        ),
      );
    }
  }

  List<(String, String?)> _collectMoreReleaseBrowses(_JsonMap root) {
    final result = <(String, String?)>[];
    for (final header in _findRenderers(
      root,
      'musicCarouselShelfBasicHeaderRenderer',
    )) {
      final endpoint = header
          .getMap('moreContentButton')
          ?.getMap('buttonRenderer')
          ?.getMap('navigationEndpoint')
          ?.getMap('browseEndpoint');
      final browseId = endpoint?.getValue<String>('browseId');
      if (browseId == null || !browseId.startsWith('MPAD')) continue;
      result.add((browseId, endpoint?.getValue<String>('params')));
    }
    return result;
  }

  String? _trackVideoId(_JsonMap item) {
    return item
        .getMap('overlay')
        ?.getMap('musicItemThumbnailOverlayRenderer')
        ?.getMap('content')
        ?.getMap('musicPlayButtonRenderer')
        ?.getMap('playNavigationEndpoint')
        ?.getMap('watchEndpoint')
        ?.getValue<String>('videoId');
  }

  String? _firstFlexColumnText(_JsonMap item) {
    final runs = _flexColumnRuns(item, 0);
    return runs.isEmpty ? null : runs.parseRuns();
  }

  List<_JsonMap> _flexColumnRuns(_JsonMap item, int index) {
    final columns = item.getList('flexColumns');
    if (columns == null || index < 0 || index >= columns.length) return [];
    final column = columns[index];
    if (column is! Map) return [];
    final runs = column
        .cast<String, dynamic>()
        .getMap('musicResponsiveListItemFlexColumnRenderer')
        ?.getMap('text')
        ?.getList('runs');
    if (runs == null) return [];
    return runs
        .whereType<Map>()
        .map((run) => run.cast<String, dynamic>())
        .toList(growable: false);
  }

  List<String> _songArtists(_JsonMap item) {
    final artists = <String>[];
    final seen = <String>{};
    final runs = _flexColumnRuns(item, 1);

    for (final run in runs) {
      final browseId = _runBrowseId(run);
      final pageType = _runPageType(run);
      final text = run.getValue<String>('text')?.trim() ?? '';
      final isArtist =
          (browseId?.startsWith('UC') ?? false) || pageType == _artistPageType;
      if (isArtist && text.isNotEmpty && seen.add(text.toLowerCase())) {
        artists.add(text);
      }
    }

    if (artists.isNotEmpty) return artists;

    final pieces = runs
        .map((run) => run.getValue<String>('text') ?? '')
        .join()
        .split('•')
        .map((piece) => piece.trim())
        .where((piece) => piece.isNotEmpty)
        .toList();
    for (final piece in pieces) {
      final normalized = piece.toLowerCase();
      if (normalized == 'song' ||
          RegExp(r'^\d{1,2}:\d{2}$').hasMatch(piece) ||
          RegExp(r'^\d{4}$').hasMatch(piece)) {
        continue;
      }
      artists.add(piece);
      break;
    }
    return artists;
  }

  String? _songAlbum(_JsonMap item) {
    for (final run in _flexColumnRuns(item, 1)) {
      final browseId = _runBrowseId(run);
      final pageType = _runPageType(run);
      final isAlbum =
          (browseId?.startsWith('MPRE') ?? false) || pageType == _albumPageType;
      if (!isAlbum) continue;
      final text = run.getValue<String>('text')?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  String? _runBrowseId(_JsonMap run) {
    return run
        .getMap('navigationEndpoint')
        ?.getMap('browseEndpoint')
        ?.getValue<String>('browseId');
  }

  String? _runPageType(_JsonMap run) {
    return run
        .getMap('navigationEndpoint')
        ?.getMap('browseEndpoint')
        ?.getMap('browseEndpointContextSupportedConfigs')
        ?.getMap('browseEndpointContextMusicConfig')
        ?.getValue<String>('pageType');
  }

  String? _fixedColumnText(_JsonMap item) {
    final columns = item.getList('fixedColumns');
    if (columns == null || columns.isEmpty) return null;
    final lastColumn = columns.last;
    if (lastColumn is! Map) return null;
    return lastColumn
        .cast<String, dynamic>()
        .getMap('musicResponsiveListItemFixedColumnRenderer')
        ?.getMap('text')
        ?.getList('runs')
        ?.whereType<Map>()
        .parseRuns();
  }

  String? _listItemThumbnailUrl(_JsonMap item) {
    final thumbnails = item
        .getMap('thumbnail')
        ?.getMap('musicThumbnailRenderer')
        ?.getMap('thumbnail')
        ?.getList('thumbnails');
    if (thumbnails == null || thumbnails.isEmpty) return null;
    final thumbnail = thumbnails.last;
    if (thumbnail is! Map) return null;
    return thumbnail.cast<String, dynamic>().getValue<String>('url');
  }

  String? _twoRowThumbnailUrl(_JsonMap item) {
    final thumbnails = item
        .getMap('thumbnailRenderer')
        ?.getMap('musicThumbnailRenderer')
        ?.getMap('thumbnail')
        ?.getList('thumbnails');
    if (thumbnails == null || thumbnails.isEmpty) return null;
    final thumbnail = thumbnails.last;
    if (thumbnail is! Map) return null;
    return thumbnail.cast<String, dynamic>().getValue<String>('url');
  }

  Duration? _parseDuration(String? value) {
    if (value == null) return null;
    final parts = value.trim().split(':');
    if (parts.isEmpty || parts.length > 3) return null;

    var seconds = 0;
    for (final part in parts) {
      final n = int.tryParse(part.trim());
      if (n == null) return null;
      seconds = seconds * 60 + n;
    }
    return Duration(seconds: seconds);
  }

  Iterable<_JsonMap> _findRenderers(dynamic node, String rendererKey) sync* {
    if (node is Map) {
      final match = node[rendererKey];
      if (match is Map) yield match.cast<String, dynamic>();
      for (final value in node.values) {
        yield* _findRenderers(value, rendererKey);
      }
    } else if (node is List) {
      for (final value in node) {
        yield* _findRenderers(value, rendererKey);
      }
    }
  }
}

extension _MapReader on Map<String, dynamic> {
  Map<String, dynamic>? getMap(String key) {
    final value = this[key];
    return value is Map ? value.cast<String, dynamic>() : null;
  }

  List<dynamic>? getList(String key) {
    final value = this[key];
    return value is List ? value : null;
  }

  T? getValue<T>(String key) {
    final value = this[key];
    return value is T ? value : null;
  }
}

extension _RunsParser on Iterable<Map<dynamic, dynamic>> {
  String parseRuns() {
    return map((run) => run['text']?.toString() ?? '').join();
  }
}
