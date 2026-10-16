/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/music_search_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/theme/app_spacing.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/custom_search_bar.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/personalized_ui.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/section_title.dart';
import 'package:musify/widgets/song_bar.dart';

typedef SearchLoader = Future<List<dynamic>> Function(String query);
typedef PlaylistSearchLoader =
    Future<List<dynamic>> Function(String query, String type);

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.songSearch,
    this.videoSearch,
    this.artistSearch,
    this.playlistSearch,
    this.suggestionSearch,
  });

  final SearchLoader? songSearch;
  final SearchLoader? videoSearch;
  final SearchLoader? artistSearch;
  final PlaylistSearchLoader? playlistSearch;
  final SearchLoader? suggestionSearch;

  @override
  _SearchPageState createState() => _SearchPageState();
}

// Global ValueNotifier for search history to make it reactive
final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

// Backward compatibility - keep the global variable for existing code
List get searchHistory => searchHistoryNotifier.value;
set searchHistory(List value) {
  searchHistoryNotifier.value = value;
}

void reloadSearchHistoryFromStorage() {
  searchHistoryNotifier.value = Hive.box(
    'user',
  ).get('searchHistory', defaultValue: []);
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<dynamic> _videosSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;
  int _latestSearchRequest = 0;
  String? _completedSearchQuery;
  bool _searchHadFailure = false;

  bool get _hasSearchResults =>
      _songsSearchResult.isNotEmpty ||
      _videosSearchResult.isNotEmpty ||
      _artistsSearchResult.isNotEmpty ||
      _albumsSearchResult.isNotEmpty ||
      _playlistsSearchResult.isNotEmpty;

  bool _isCurrentSearch(int requestId, String query) =>
      mounted && requestId == _latestSearchRequest && _searchBar.text == query;

  void _clearSearchResults() {
    _completedSearchQuery = null;
    _searchHadFailure = false;
    _songsSearchResult = [];
    _videosSearchResult = [];
    _artistsSearchResult = [];
    _albumsSearchResult = [];
    _playlistsSearchResult = [];
  }

  Future<void> _submitSearch([String? query]) async {
    if (query != null) {
      _searchBar.text = query;
      _searchBar.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchBar.text.length),
      );
    }

    _latestSuggestionRequest++;
    _debounce?.cancel();
    _suggestionsList = [];
    if (mounted) setState(() {});

    _inputNode.unfocus();
    await search();
  }

  @override
  void dispose() {
    _latestSearchRequest++;
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingSongs.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> search() async {
    if (!mounted) return;
    final requestId = ++_latestSearchRequest;
    final query = _searchBar.text;

    if (query.isEmpty) {
      _clearSearchResults();
      _suggestionsList = [];
      _fetchingSongs.value = false;
      setState(() {});
      return;
    }
    _fetchingSongs.value = true;
    setState(_clearSearchResults);

    if (!searchHistory.contains(query)) {
      final updatedHistory = List.from(searchHistory)..insert(0, query);
      searchHistoryNotifier.value = updatedHistory;
      unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));
    }

    var hadFailure = false;
    void markFailure() => hadFailure = true;
    try {
      final results = await Future.wait<List<dynamic>>([
        _loadSearchCategory(
          widget.songSearch ?? searchMusicSongs,
          query,
          onFailure: markFailure,
        ),
        _loadSearchCategory(
          widget.artistSearch ?? searchArtists,
          query,
          onFailure: markFailure,
        ),
        _loadSearchCategory(
          (value) =>
              widget.playlistSearch?.call(value, 'album') ??
              getPlaylists(query: value, type: 'album'),
          query,
          onFailure: markFailure,
        ),
        _loadSearchCategory(
          (value) =>
              widget.playlistSearch?.call(value, 'playlist') ??
              getPlaylists(query: value, type: 'playlist'),
          query,
          onFailure: markFailure,
        ),
        _loadSearchCategory(
          widget.videoSearch ?? fetchSongsList,
          query,
          onFailure: markFailure,
        ),
      ]);

      if (!_isCurrentSearch(requestId, query)) return;
      var songs = results[0];
      final artists = results[1]
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      if (songs.isEmpty && artists.isNotEmpty && results[4].isEmpty) {
        songs = await _fetchSongsForResolvedArtist(
          query,
          artists,
          requestId,
          onFailure: markFailure,
        );
      }
      if (!_isCurrentSearch(requestId, query)) return;
      _songsSearchResult = songs;
      final songIds = songs
          .whereType<Map>()
          .map((song) => song['ytid'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      _videosSearchResult = results[4]
          .where((video) => video is! Map || !songIds.contains(video['ytid']))
          .toList();
      _artistsSearchResult = artists;
      _albumsSearchResult = results[2];
      _playlistsSearchResult = results[3];
    } catch (e, stackTrace) {
      if (!_isCurrentSearch(requestId, query)) return;
      hadFailure = true;
      logger.log(
        'Error while searching online songs',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (_isCurrentSearch(requestId, query)) {
        _completedSearchQuery = query;
        _searchHadFailure = hadFailure;
        _fetchingSongs.value = false;
        setState(() {});
      }
    }
  }

  Future<List<dynamic>> _loadSearchCategory(
    SearchLoader loader,
    String query, {
    VoidCallback? onFailure,
  }) async {
    try {
      return await loader(query);
    } catch (error, stackTrace) {
      onFailure?.call();
      logger.log(
        'Search category unavailable',
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<List<dynamic>> _fetchSongsForResolvedArtist(
    String query,
    List<Map<String, dynamic>> artists,
    int requestId, {
    VoidCallback? onFailure,
  }) async {
    final artistName = artists.first['title']?.toString().trim();
    if (artistName == null || artistName.isEmpty) return [];

    final fallbackQueries = <String>{
      if (artistName.toLowerCase() != query.trim().toLowerCase()) artistName,
      '$artistName songs',
      '$artistName music',
    };

    for (final fallbackQuery in fallbackQueries) {
      if (!_isCurrentSearch(requestId, query)) return [];
      final songs = await _loadSearchCategory(
        widget.songSearch ?? searchMusicSongs,
        fallbackQuery,
        onFailure: onFailure,
      );
      if (!_isCurrentSearch(requestId, query)) return [];
      if (songs.isNotEmpty) return songs;
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.search)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final bar = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 600 : double.infinity,
                  ),
                  child: CustomSearchBar(
                    loadingProgressNotifier: _fetchingSongs,
                    controller: _searchBar,
                    focusNode: _inputNode,
                    labelText: '${context.l10n!.search}...',
                    onChanged: (value) {
                      _latestSearchRequest++;
                      _fetchingSongs.value = false;
                      // debounce suggestions to avoid rapid API calls
                      _debounce?.cancel();
                      final query = value;
                      final requestId = ++_latestSuggestionRequest;

                      // Clear suggestions immediately if input is empty
                      if (query.isEmpty) {
                        _clearSearchResults();
                        _suggestionsList = [];
                        if (mounted) setState(() {});
                        return;
                      }

                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () async {
                          final searchSuggestions =
                              await (widget.suggestionSearch ??
                                  getSearchSuggestions)(query);

                          if (!mounted ||
                              requestId != _latestSuggestionRequest ||
                              _searchBar.text != query) {
                            return;
                          }

                          _suggestionsList = List<String>.from(
                            searchSuggestions,
                          );
                          if (mounted) setState(() {});
                        },
                      );
                    },
                    onSubmitted: (String value) {
                      _submitSearch();
                    },
                  ),
                );
                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [bar],
                  );
                } else {
                  return bar;
                }
              },
            ),

            if (_completedSearchQuery != null &&
                _completedSearchQuery == _searchBar.text &&
                _suggestionsList.isEmpty &&
                (_searchHadFailure || !_hasSearchResults)) ...[
              const SizedBox(height: AppSpacing.md),
              PersonalizedStatusBanner(
                title: _searchHadFailure
                    ? 'Search incomplete'
                    : 'No results found',
                message: _searchHadFailure
                    ? 'Some search sources are unavailable. Try again.'
                    : 'Try another search or use a previous query.',
                tone: _searchHadFailure
                    ? PersonalizedStatusTone.error
                    : PersonalizedStatusTone.neutral,
              ),
              if (_searchHadFailure)
                TextButton.icon(
                  onPressed: _submitSearch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry search'),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  (_suggestionsList.isNotEmpty ||
                      (_songsSearchResult.isEmpty &&
                          _videosSearchResult.isEmpty &&
                          _artistsSearchResult.isEmpty &&
                          _albumsSearchResult.isEmpty &&
                          _playlistsSearchResult.isEmpty))
                  ? ValueListenableBuilder<List>(
                      valueListenable: searchHistoryNotifier,
                      builder: (context, searchHistory, _) {
                        final items = _suggestionsList.isEmpty
                            ? searchHistory
                            : _suggestionsList;

                        return Column(
                          key: ValueKey(
                            'history-${_suggestionsList.length}-${_searchBar.text}-${searchHistory.length}',
                          ),
                          children: [
                            for (int index = 0; index < items.length; index++)
                              Builder(
                                builder: (context) {
                                  final query = items[index];
                                  final borderRadius = getItemBorderRadius(
                                    index,
                                    items.length,
                                  );

                                  return CustomBar(
                                    query,
                                    FluentIcons.search_24_regular,
                                    borderRadius: borderRadius,
                                    onTap: () async {
                                      await _submitSearch(query.toString());
                                    },
                                    onLongPress: () async {
                                      final confirm =
                                          await _showConfirmationDialog(
                                            context,
                                          ) ??
                                          false;
                                      if (confirm &&
                                          searchHistory.contains(query)) {
                                        final updatedHistory = List.from(
                                          searchHistory,
                                        )..remove(query);
                                        searchHistoryNotifier.value =
                                            updatedHistory;
                                        unawaited(
                                          addOrUpdateData<List>(
                                            'user',
                                            'searchHistory',
                                            updatedHistory,
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    )
                  : _buildSearchResults(context, primaryColor),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, Color primaryColor) {
    final widgets = <Widget>[];

    // Artists section
    if (_artistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.artists,
          primaryColor,
          icon: FluentIcons.person_24_filled,
        ),
      );

      final artists = _artistsSearchResult.take(3).toList();
      for (var index = 0; index < artists.length; index++) {
        final artist = Map<String, dynamic>.from(artists[index]);
        final artistId =
            artist['ytid']?.toString() ?? artist['title']?.toString() ?? '';
        if (artistId.isEmpty) continue;

        final borderRadius = getItemBorderRadius(index, artists.length);
        widgets.add(
          ArtistBar(
            key: listItemKey('search_artist', index, artist),
            artist: artist,
            borderRadius: borderRadius,
            onTap: () {
              context.push(
                '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistId)}',
                extra: artist,
              );
            },
          ),
        );
      }
    }

    // Songs section
    if (_songsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          '${context.l10n!.songs} · YouTube Music',
          primaryColor,
          icon: FluentIcons.music_note_1_24_filled,
        ),
      );

      final songsCount = _songsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _songsSearchResult.length;

      for (var index = 0; index < songsCount; index++) {
        final song = _songsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, songsCount);
        widgets.add(
          SongBar(
            song,
            true,
            key: listItemKey('search_song', index, song),
            showMusicDuration: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Generic results remain discoverable without claiming they are songs.
    if (_videosSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          'YouTube videos',
          primaryColor,
          icon: FluentIcons.video_24_regular,
        ),
      );
      final videos = _videosSearchResult.take(maxSongsInList).toList();
      for (var index = 0; index < videos.length; index++) {
        final video = videos[index];
        widgets.add(
          SongBar(
            video,
            true,
            key: listItemKey('search_video', index, video),
            showMusicDuration: true,
            borderRadius: getItemBorderRadius(index, videos.length),
          ),
        );
      }
    }

    // Albums section
    if (_albumsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.albums,
          primaryColor,
          icon: FluentIcons.album_24_filled,
        ),
      );

      final albumsCount = _albumsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _albumsSearchResult.length;

      for (var index = 0; index < albumsCount; index++) {
        final playlist = _albumsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, albumsCount);

        widgets.add(
          PlaylistBar(
            key: listItemKey('search_album', index, playlist),
            playlist['title'],
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['image'],
            cubeIcon: FluentIcons.cd_16_filled,
            isAlbum: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Playlists section
    if (_playlistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.playlists,
          primaryColor,
          icon: FluentIcons.text_bullet_list_24_filled,
        ),
      );

      final playlistsCount = _playlistsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _playlistsSearchResult.length;

      for (var index = 0; index < playlistsCount; index++) {
        final playlist = _playlistsSearchResult[index];
        final isLast = index == playlistsCount - 1;
        final borderRadius = getItemBorderRadius(index, playlistsCount);

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: PlaylistBar(
              key: listItemKey('search_playlist', index, playlist),
              playlist['title'],
              playlistId: playlist['ytid'],
              playlistArtwork: playlist['image'],
              cubeIcon: FluentIcons.apps_list_24_filled,
              borderRadius: borderRadius,
            ),
          ),
        );
      }
    }

    return Column(
      key: ValueKey(
        'results-${_videosSearchResult.length}-${_songsSearchResult.length}-${_artistsSearchResult.length}-${_albumsSearchResult.length}-${_playlistsSearchResult.length}',
      ),
      children: widgets,
    );
  }

  Future<bool?> _showConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n!.removeSearchQueryQuestion,
          submitMessage: context.l10n!.confirm,
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }
}
