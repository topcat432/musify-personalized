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
import 'package:flutter/services.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/artist_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlist_sharing.dart';
import 'package:musify/services/playlist_slot_undo.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/offline_playlist_dialogs.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/utilities/song_filtering.dart';
import 'package:musify/utilities/sort_utils.dart';
import 'package:musify/widgets/edit_playlist_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_cube.dart';
import 'package:musify/widgets/playlist_page/empty_playlist_state.dart';
import 'package:musify/widgets/playlist_page/playlist_header.dart';
import 'package:musify/widgets/playlist_page/search_bar_section.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/sort_chips.dart';
import 'package:musify/widgets/spinner.dart';

enum PlaylistSortType { default_, title, artist, dateAdded }

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({
    super.key,
    this.playlistId,
    this.playlistData,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
    this.isArtist = false,
  });

  final String? playlistId;
  final dynamic playlistData;
  final IconData cubeIcon;
  final bool isArtist;

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  dynamic _playlist;
  Map? _sourcePlaylist;
  late List<dynamic> _originalPlaylistList; // Keep original order separately
  List<int> _playlistSourceOrder = []; // Runtime slots, never stored in songs.

  late final playlistLikeStatus = ValueNotifier<bool>(
    isPlaylistAlreadyLiked(_resolvedPlaylistId),
  );
  bool playlistOfflineStatus = false;
  bool _isInitializingPlaylist = true;

  String? get _resolvedPlaylistId =>
      _playlist?['ytid']?.toString() ??
      widget.playlistData?['ytid']?.toString() ??
      widget.playlistId;

  // Sorting
  late PlaylistSortType _sortType = PlaylistSortType.values.firstWhere(
    (e) => e.name == playlistSortSetting,
    orElse: () => PlaylistSortType.default_,
  );

  // Search
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  List<int> _getSourceIndices(String searchQuery) {
    final list = _playlist?['list'] as List<dynamic>? ?? [];
    return filterSongIndicesByQuery(list, searchQuery);
  }

  bool get _isArtistCatalogLoading =>
      widget.isArtist && _playlist?['catalogStatus'] == 'loading';

  bool get _isArtistCatalogFailed =>
      widget.isArtist && _playlist?['catalogStatus'] == 'failed';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    userLikedPlaylists.addListener(_syncPlaylistLikeStatus);
    _initializePlaylist();
  }

  @override
  void dispose() {
    userLikedPlaylists.removeListener(_syncPlaylistLikeStatus);
    playlistLikeStatus.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  void _syncPlaylistLikeStatus() {
    final newStatus = isPlaylistAlreadyLiked(_resolvedPlaylistId);
    if (playlistLikeStatus.value != newStatus) {
      playlistLikeStatus.value = newStatus;
    }
  }

  Future<void> _initializePlaylist() async {
    try {
      final initialPlaylist = widget.playlistData;
      final resolvedId =
          initialPlaylist?['ytid']?.toString() ?? widget.playlistId;

      if (initialPlaylist != null) {
        _playlist = initialPlaylist;
        final playlistList = _playlist?['list'] as List?;
        final shouldFetchInitialPlaylist =
            playlistList == null || (!widget.isArtist && playlistList.isEmpty);
        if (shouldFetchInitialPlaylist && resolvedId != null) {
          _playlist =
              await getPlaylistInfoForWidget(
                resolvedId,
                isArtist: widget.isArtist,
                artistName: initialPlaylist?['title']?.toString(),
                artistImage: initialPlaylist?['image']?.toString(),
                sourceSongId: initialPlaylist?['sourceSongId']?.toString(),
                sourceVideoAuthor: initialPlaylist?['videoAuthor']?.toString(),
                preferredVerified: initialPlaylist?['isVerifiedArtist'] == true,
              ) ??
              initialPlaylist;
        }
      } else {
        _playlist = await getPlaylistInfoForWidget(
          resolvedId,
          isArtist: widget.isArtist,
          artistName: initialPlaylist?['title']?.toString(),
          artistImage: initialPlaylist?['image']?.toString(),
          sourceSongId: initialPlaylist?['sourceSongId']?.toString(),
          sourceVideoAuthor: initialPlaylist?['videoAuthor']?.toString(),
          preferredVerified: initialPlaylist?['isVerifiedArtist'] == true,
        );
      }

      if (_playlist is Map) _sourcePlaylist = _playlist;
      if (_playlist != null && _playlist['list'] != null) {
        _capturePlaylistOrder();
        _sortPlaylist(_sortType);
        _syncPlaylistLikeStatus();
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error initializing playlist:',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showToast(context, context.l10n!.error);
      }
    } finally {
      _isInitializingPlaylist = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(FluentIcons.arrow_left_24_regular),
          onPressed: () =>
              Navigator.pop(context, widget.playlistData == _sourcePlaylist),
          tooltip: context.l10n!.back,
        ),
      ),
      body: Padding(
        padding: commonSingleChildScrollViewPadding,
        child: _isInitializingPlaylist
            ? SizedBox(
                height: MediaQuery.sizeOf(context).height - 100,
                child: const Spinner(),
              )
            : _playlist != null
            ? CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeaderSection()),
                  if ((_playlist['list'] as List? ?? const []).isNotEmpty) ...[
                    ValueListenableBuilder<String>(
                      valueListenable: _searchQueryNotifier,
                      builder: (context, searchQuery, _) {
                        final sourceIndices = _getSourceIndices(searchQuery);
                        return SliverPadding(
                          padding: commonListViewBottomPadding,
                          sliver: SliverList.builder(
                            itemCount: sourceIndices.length,
                            itemBuilder: (context, index) {
                              final isRemovable =
                                  _playlist['source'] == 'user-created';
                              return _buildSongListItem(
                                _playlist['list'][sourceIndices[index]],
                                index,
                                sourceIndices[index],
                                sourceIndices.length,
                                isRemovable,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ] else if (_isArtistCatalogLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.3,
                          child: const Spinner(),
                        ),
                      ),
                    )
                  else if (_isArtistCatalogFailed)
                    EmptyPlaylistState(message: context.l10n!.error)
                  else
                    EmptyPlaylistState(
                      message: context.l10n!.noSongsInPlaylist,
                    ),
                  const SliverMiniPlayerBottomSpace(),
                ],
              )
            : CustomScrollView(
                slivers: [
                  EmptyPlaylistState(message: context.l10n!.error),
                  const SliverMiniPlayerBottomSpace(),
                ],
              ),
      ),
    );
  }

  Widget _buildPlaylistImage() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    final playlist = widget.isArtist
        ? {
            ..._playlist,
            'image': normalizeArtistThumbnailUrl(
              _playlist['image']?.toString(),
            ),
          }
        : _playlist;
    return PlaylistCube(
      playlist,
      size: isLandscape ? 250 : screenWidth / commonPlaylistArtworkDivision,
      cubeIcon: widget.cubeIcon,
      showTypeLabel: false,
    );
  }

  Widget _buildHeaderSection() {
    final songsLength = (_playlist['list'] as List? ?? const []).length;
    final isUserCreated = _playlist['source'] == 'user-created';
    final colorScheme = Theme.of(context).colorScheme;
    final playlistTitle = widget.isArtist
        ? normalizeArtistDisplayTitle(_playlist['title']?.toString() ?? '')
        : _playlist['title']?.toString() ?? '';

    final hasSecondaryActions =
        (widget.playlistId != null && !isUserCreated && !offlineMode.value) ||
        !offlineMode.value ||
        isUserCreated;

    return Column(
      children: [
        PlaylistHeader(
          _buildPlaylistImage(),
          playlistTitle,
          songsLength,
          isAlbum: _playlist['isAlbum'] == true,
          isArtist: widget.isArtist,
        ),
        if (songsLength > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(FluentIcons.play_24_filled),
                    label: Text(context.l10n!.play),
                    onPressed: () => audioHandler.playPlaylistSong(
                      playlist: _playlist,
                      songIndex: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                    ),
                    icon: const Icon(FluentIcons.arrow_shuffle_24_filled),
                    label: Text(context.l10n!.shuffle),
                    onPressed: () async {
                      final songs = _playlist['list'] as List? ?? [];
                      if (songs.isEmpty) return;
                      final orderedSongs = List<Map>.from(
                        songs.whereType<Map>(),
                      );
                      if (orderedSongs.isEmpty) return;
                      await audioHandler.addPlaylistToQueue(
                        orderedSongs,
                        replace: true,
                        startIndex: 0,
                        shuffle: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        if (hasSecondaryActions) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 5,
            children: [
              if (widget.playlistId != null &&
                  !isUserCreated &&
                  !offlineMode.value)
                _buildLikeButton(),
              if (!offlineMode.value) ...[
                _buildAddToPlaylistButton(),
                if (!isUserCreated) _buildSyncButton(),
              ],
              if (songsLength > 0) _buildDownloadButton(),
              if (isUserCreated) ...[_buildShareButton(), _buildEditButton()],
            ],
          ),
        ],
        if (songsLength > 1) ...[
          const SizedBox(height: 12),
          SortChips<PlaylistSortType>(
            currentSortType: _sortType,
            sortTypes: PlaylistSortType.values,
            sortTypeToString: _getSortTypeDisplayText,
            onSelected: (type) {
              setState(() {
                _sortType = type;
                addOrUpdateData<String>(
                  'settings',
                  'playlistSortType',
                  type.name,
                );
                playlistSortSetting = type.name;
                _sortPlaylist(type);
              });
            },
          ),
        ],
        if (songsLength > 0) ...[
          const SizedBox(height: 16),
          SearchBarSection(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onSearchChanged: (value) => _searchQueryNotifier.value = value,
            labelText: context.l10n!.search,
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildShareButton() {
    return IconButton.filledTonal(
      icon: const Icon(FluentIcons.share_24_regular),
      iconSize: 24,
      onPressed: () async {
        try {
          final encodedPlaylist = PlaylistSharingService.encodePlaylist(
            _playlist,
          );
          final url = 'musify://playlist/custom/$encodedPlaylist';
          await Clipboard.setData(ClipboardData(text: url));
          if (mounted) {
            showToast(context, context.l10n!.linkCopied);
          }
        } catch (e, stackTrace) {
          logger.log(
            'Error sharing playlist',
            error: e,
            stackTrace: stackTrace,
          );
          if (mounted) {
            showToast(context, context.l10n!.error);
          }
        }
      },
      tooltip: context.l10n!.share,
    );
  }

  Widget _buildLikeButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: playlistLikeStatus,
      builder: (_, value, __) {
        final icon = value
            ? FluentIcons.heart_24_filled
            : FluentIcons.heart_24_regular;

        return value
            ? IconButton.filled(
                icon: Icon(icon),
                iconSize: 24,
                onPressed: () {
                  playlistLikeStatus.value = !playlistLikeStatus.value;
                  unawaited(
                    updatePlaylistLikeStatus(
                      _playlist['ytid'],
                      playlistLikeStatus.value,
                      playlistData: _sourcePlaylist ?? _playlist,
                    ),
                  );
                },
                tooltip: context.l10n!.removeFromLikedSongs,
              )
            : IconButton.filledTonal(
                icon: Icon(icon),
                iconSize: 24,
                onPressed: () {
                  playlistLikeStatus.value = !playlistLikeStatus.value;
                  unawaited(
                    updatePlaylistLikeStatus(
                      _playlist['ytid'],
                      playlistLikeStatus.value,
                      playlistData: _sourcePlaylist ?? _playlist,
                    ),
                  );
                },
                tooltip: context.l10n!.addToLikedSongs,
              );
      },
    );
  }

  Widget _buildSyncButton() {
    return IconButton.filledTonal(
      icon: const Icon(FluentIcons.arrow_sync_24_filled),
      iconSize: 24,
      onPressed: _handleSyncPlaylist,
      tooltip: context.l10n!.update,
    );
  }

  Widget _buildAddToPlaylistButton() {
    return IconButton.filledTonal(
      icon: const Icon(FluentIcons.album_add_24_regular),
      iconSize: 24,
      onPressed: _handleAddFullPlaylistToPlaylist,
      tooltip: context.l10n!.addToPlaylist,
    );
  }

  void _handleAddFullPlaylistToPlaylist() {
    if (_playlist != null && _playlist['list'] != null) {
      final List<dynamic> tracks = _playlist['list'];
      if (tracks.isEmpty) {
        showToast(context, context.l10n!.noSongsInPlaylist);
        return;
      }
      showAddToPlaylistDialog(context, songs: tracks);
    } else {
      showToast(context, context.l10n!.loading);
    }
  }

  Widget _buildEditButton() {
    return IconButton.filledTonal(
      icon: const Icon(FluentIcons.edit_24_filled),
      iconSize: 24,
      onPressed: () async {
        final result = await showDialog<Map?>(
          context: context,
          builder: (context) => EditPlaylistDialog(playlistData: _sourcePlaylist ?? _playlist),
        );

        if (result != null) {
          final resolvedPlaylistYtid =
              _playlist['ytid']?.toString() ?? widget.playlistId;
          if (resolvedPlaylistYtid == null ||
              resolvedPlaylistYtid.isEmpty ||
              resolvedPlaylistYtid == 'null') {
            showToast(context, context.l10n!.error);
            return;
          }

          final sourcePlaylist = _sourcePlaylist ?? _playlist;
          final updatedPlaylist = {
            ...sourcePlaylist,
            ...result,
            'ytid': resolvedPlaylistYtid,
            'source': _playlist['source'] ?? result['source'],
            'list': result['list'] ?? sourcePlaylist['list'],
          };

          // Search root list first, then inside folders.
          final rootIndex = userCustomPlaylists.value.indexWhere(
            (p) => p['ytid'] == resolvedPlaylistYtid,
          );

          if (rootIndex != -1) {
            final updatedPlaylists = List<Map>.from(userCustomPlaylists.value);
            updatedPlaylists[rootIndex] = updatedPlaylist;
            userCustomPlaylists.value = updatedPlaylists;
            unawaited(
              addOrUpdateData<List>(
                'user',
                'customPlaylists',
                userCustomPlaylists.value,
              ),
            );
          } else {
            // Playlist lives inside a folder - update it there.
            final updatedFolders = List<Map>.from(userPlaylistFolders.value);
            for (final folder in updatedFolders) {
              final folderPlaylists = List<Map>.from(
                folder['playlists'] as List? ?? [],
              );
              final fi = folderPlaylists.indexWhere(
                (p) => p['ytid'] == resolvedPlaylistYtid,
              );
              if (fi != -1) {
                folderPlaylists[fi] = updatedPlaylist;
                folder['playlists'] = folderPlaylists;
                break;
              }
            }
            userPlaylistFolders.value = updatedFolders;
            unawaited(
              addOrUpdateData<List>(
                'user',
                'playlistFolders',
                userPlaylistFolders.value,
              ),
            );
          }

          // Update offline playlist if it exists
          unawaited(syncOfflinePlaylistMetadata(updatedPlaylist));

          setState(() {
            _playlist = updatedPlaylist;
            if (_playlist['list'] is List) {
              _capturePlaylistOrder();
              _sortPlaylist(_sortType);
            } else {
              _sourcePlaylist = updatedPlaylist;
            }
          });
          showToast(context, context.l10n!.playlistUpdated);
        }
      },
      tooltip: context.l10n!.editPlaylist,
    );
  }

  Widget _buildDownloadButton() {
    final playlistId = _playlist?['ytid']?.toString() ?? widget.playlistId;

    if (playlistId == null || playlistId.isEmpty) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<List>(
      valueListenable: userOfflineSongs,
      builder: (context, _, __) {
        return ValueListenableBuilder<List>(
          valueListenable: offlinePlaylistService.offlinePlaylists,
          builder: (context, offlinePlaylists, _) {
            final playlistSongs = _playlist?['list'] as List? ?? [];
            playlistOfflineStatus = isPlaylistFullyOffline(playlistSongs);

            if (playlistOfflineStatus) {
              return IconButton.filled(
                icon: Icon(
                  FluentIcons.arrow_download_off_24_filled,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                iconSize: 24,
                onPressed: () => _showRemoveOfflineDialog(playlistId),
                tooltip: context.l10n!.removeOffline,
              );
            }

            return ValueListenableBuilder<DownloadProgress>(
              valueListenable: offlinePlaylistService.getProgressNotifier(
                playlistId,
              ),
              builder: (context, progress, _) {
                final isDownloading = offlinePlaylistService
                    .isPlaylistDownloading(playlistId);

                if (isDownloading) {
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            value: progress.isCancelled
                                ? null
                                : progress.progress,
                            strokeWidth: 3,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                        ),
                        if (!progress.isCancelled)
                          IconButton(
                            icon: const Icon(
                              FluentIcons.dismiss_24_filled,
                              size: 16,
                            ),
                            onPressed: () => offlinePlaylistService
                                .cancelDownload(context, playlistId),
                            tooltip: context.l10n!.cancel,
                          ),
                      ],
                    ),
                  );
                }

                if (offlineMode.value) {
                  return const SizedBox.shrink();
                }

                return IconButton.filledTonal(
                  icon: const Icon(FluentIcons.arrow_download_24_filled),
                  iconSize: 24,
                  onPressed: () => offlinePlaylistService.downloadPlaylist(
                    context,
                    _playlist,
                  ),
                  tooltip: context.l10n!.downloadPlaylist,
                );
              },
            );
          },
        );
      },
    );
  }

  void _showRemoveOfflineDialog(String playlistId) =>
      showRemoveOfflinePlaylistDialog(context, playlistId);

  void _handleSyncPlaylist() async {
    final playlistId = _playlist?['ytid']?.toString();
    if (playlistId == null || playlistId.isEmpty) return;

    if (offlineMode.value &&
        offlinePlaylistService.isPlaylistDownloaded(playlistId)) {
      if (mounted) {
        showToast(context, context.l10n!.removeOffline);
      }
      return;
    }

    final updated = widget.isArtist
        ? await getPlaylistInfoForWidget(
            playlistId,
            isArtist: true,
            artistName: _playlist?['title']?.toString(),
            artistImage: _playlist?['image']?.toString(),
            preferredVerified: _playlist?['isVerifiedArtist'] == true,
            forceRefresh: true,
          )
        : await updatePlaylistList(context, playlistId);
    if (updated != null && mounted) {
      setState(() {
        _playlist = updated;
        if (_playlist['list'] != null) {
          _capturePlaylistOrder();
        }
      });
    }
  }

  void _updateSongsListOnRemove(int indexOfRemovedSong, dynamic songToRemove) {
    final sourceIndex = _playlistSourceOrder.removeAt(indexOfRemovedSong);
    _originalPlaylistList.removeAt(sourceIndex);
    _playlistSourceOrder = [
      for (final index in _playlistSourceOrder)
        index > sourceIndex ? index - 1 : index,
    ];
    final undo = PlaylistSlotUndo(
      _sourcePlaylist!,
      remainingSourceSongs: _originalPlaylistList,
      removedSong: songToRemove,
      sourceIndex: sourceIndex,
    );
    if (mounted) {
      setState(() {});
      showToastWithButton(
        context,
        context.l10n!.songRemoved,
        context.l10n!.undo.toUpperCase(),
        () async {
          if (!mounted || undo.used) return;
          _syncOriginalSongValues();
          final restoredSource = undo.restoredSource(_originalPlaylistList);
          if (restoredSource == null) {
            showToast(context, context.l10n!.error);
            return;
          }
          // The writer owns canonical slots; display sorting is reapplied only
          // to the detached page container after a successful source restore.
          final restored = await undo.apply(
            expectedCurrentSongs: List<dynamic>.from(_sourcePlaylist!['list'] as List),
            currentSourceOrder: List.generate(_originalPlaylistList.length, (i) => i),
            restoredOrder: List.generate(restoredSource.length, (i) => i),
          );
          if (!mounted) return;
          if (restored == null) {
            showToast(context, context.l10n!.error);
            return;
          }
          setState(() {
            _playlist = restored;
            _capturePlaylistOrder();
            _sortPlaylist(_sortType);
          });
        },
      );
    } else {
      logger.log(
        '(_updateSongsListOnRemove): Widget not mounted, cannot show undo toast.',
      );
    }
  }

  String _getSortTypeDisplayText(PlaylistSortType type) {
    switch (type) {
      case PlaylistSortType.default_:
        return context.l10n!.default_;
      case PlaylistSortType.title:
        return context.l10n!.name;
      case PlaylistSortType.artist:
        return context.l10n!.artist;
      case PlaylistSortType.dateAdded:
        return context.l10n!.dateAdded;
    }
  }

  void _capturePlaylistOrder() {
    _sourcePlaylist = _playlist as Map;
    // Sort a page-owned container; the library/Hive map retains source order.
    _playlist = Map<dynamic, dynamic>.from(_sourcePlaylist!)
      ..['list'] = List<dynamic>.from(_sourcePlaylist!['list'] as List);
    _originalPlaylistList = List<dynamic>.from(_sourcePlaylist!['list'] as List);
    _playlistSourceOrder = List.generate(
      _originalPlaylistList.length,
      (i) => i,
    );
  }

  void _syncOriginalSongValues() {
    final current = _playlist['list'] as List;
    if (current.length != _playlistSourceOrder.length) {
      // A topology change outside this removal flow establishes a fresh view.
      _capturePlaylistOrder();
      return;
    }
    for (var i = 0; i < current.length; i++) {
      _originalPlaylistList[_playlistSourceOrder[i]] = current[i];
    }
  }

  void _sortPlaylist(PlaylistSortType type) {
    if (_playlist == null || _playlist['list'] == null) return;
    _syncOriginalSongValues();
    _playlistSourceOrder = _sortedSourceOrder(
      type,
      _originalPlaylistList,
      _playlistSourceOrder,
    );
    _playlist['list'] = [
      for (final index in _playlistSourceOrder) _originalPlaylistList[index],
    ];
  }

  List<int> _sortedSourceOrder(
    PlaylistSortType type,
    List<dynamic> source,
    List<int> currentOrder,
  ) {
    switch (type) {
      case PlaylistSortType.default_:
        return List.generate(source.length, (i) => i);
      case PlaylistSortType.title:
      case PlaylistSortType.artist:
        final slots = <dynamic>[
          for (final index in currentOrder)
            {
              'index': index,
              'title': source[index]['title'],
              'artist': source[index]['artist'],
            },
        ];
        sortSongsByKey(
          slots,
          type == PlaylistSortType.title ? 'title' : 'artist',
        );
        return [for (final slot in slots) slot['index'] as int];
      case PlaylistSortType.dateAdded:
        return List.generate(source.length, (i) => source.length - 1 - i);
    }
  }

  Widget _buildSongListItem(
    dynamic song,
    int index,
    int fullIndex,
    int totalItems,
    bool isRemovable,
  ) {
    final borderRadius = getItemBorderRadius(index, totalItems);
    final isUserCreatedPlaylist = _playlist?['source'] == 'user-created';
    final playlistId = isUserCreatedPlaylist ? _playlist!['ytid'] : null;
    final isSearching = _searchQueryNotifier.value.isNotEmpty;

    return SongBar(
      song,
      true,
      key: listItemKey('playlist_song', index, song),
      onRemove: (isRemovable && !isSearching)
          ? () {
              _syncOriginalSongValues();
              if (removeSongFromPlaylist(
                _sourcePlaylist!,
                song,
                removeOneAtIndex: _playlistSourceOrder[index],
              )) {
                _playlist['list'] = List<dynamic>.from(_playlist['list'] as List)..removeAt(index);
                _updateSongsListOnRemove(index, song);
              }
            }
          : null,
      onPlay: () {
        audioHandler.playPlaylistSong(
          playlist: _playlist,
          songIndex: fullIndex,
        );
      },
      borderRadius: borderRadius,
      playlistId: playlistId,
      playlist: isUserCreatedPlaylist ? _sourcePlaylist : null,
      playlistSongIndex: _playlistSourceOrder[fullIndex],
      onRenamed: (renamed) {
        if (!mounted) return;
        _playlist = renamed;
        _capturePlaylistOrder();
        _sortPlaylist(_sortType);
        setState(() {});
      },
    );
  }
}
