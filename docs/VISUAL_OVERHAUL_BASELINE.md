# Musify Personalized — Visual Overhaul Baseline

## Status and provenance

Read-only frontend inventory for branch `agent/full-visual-overhaul-master`,
created directly from `origin/master` (commit `a786323556275a0de745ffca4d3affc088ac2055`,
which contains merged PR #17 "Ship personalized import, review, recovery, and
verified updates" and merged PR #18 governance bootstrap). No application
source was changed to produce this document.

**Current `master` is the authoritative functional baseline.** This document
supersedes an earlier version written against PR #7
(`agent/review-sprint-overhaul`, commit `b6fee783a1a91389ddffd0f78d89dbcc70dab329`),
preserved unchanged as an archival checkpoint on branch
`agent/full-visual-overhaul` / draft PR #19. PR #4 and PR #7 are historical,
superseded stacks — **not** the active implementation base. Every claim below
was verified directly against source on this branch, not carried over from
the PR #7-era audit without re-checking.

---

## 0. Governance context that shapes this baseline

- `AGENTS.md`, `CLAUDE.md`, and `docs/{MASTER_AGENT_HANDOVER,VISUAL_SYSTEM,DECISIONS,RELEASE_STATE}.md`
  already exist on `master` (merged via PR #18) — nothing needed to be
  cherry-picked for governance.
- `docs/VISUAL_SYSTEM.md` documents an established warm/dark/premium,
  album-driven direction, a semantic-`ColorScheme`-only color rule, a
  typography convention, a shape/spacing vocabulary (radii 28/24/18, padding
  22/18/24), and a motion vocabulary (220/240/320/240/360 ms), and references
  `PersonalizedReveal`, `personalizedPageRoute`, and
  `showPersonalizedDestructiveConfirmation`. **All three are confirmed present
  and in active use on `master`** (see §3) — unlike the PR #7 branch, where
  they did not exist. Treat `VISUAL_SYSTEM.md` as accurately describing the
  current codebase's existing direction to extend and formalize, not as a
  reason to invent an unrelated visual language.
- Product invariants that constrain every screen in this inventory (from
  `docs/MASTER_AGENT_HANDOVER.md` §3, §8 and `docs/DECISIONS.md` D-002/D-004/D-005):
  unmatched, review, error, accepted, routed, excluded, and now
  **destination-routed** states must never be conflated; import/matching must
  never silently mutate destinations or discard unresolved rows; backup/restore
  success requires structural + checksum + semantic + reopen + restart proof,
  never a toast or picker result alone.

---

## 1. Navigation architecture

**Router:** `lib/services/router_service.dart` (GoRouter, `StatefulShellRoute.indexedStack`,
4 tab branches: Home / Search / Library / Settings). Offline-mode redirects
`/search`, `/home/timeMachine`, and unavailable `/artist/:id` back to `/home`.
Tab-root transitions fade 180 ms; nested pushes fade+slide 220 ms
(`router_service.dart:327-371`).

**Imperative (`Navigator.push`) flows not in GoRouter:** Now Playing (from the
mini-player) and the entire Spotify import → matching → review → **destination**
subgraph (hub → import → matching → detailed review / quick review → manual
match → **destination**).

### Route map

```
/home                       → HomePage | UserSongsPage(offline)
/home/timeMachine            → TimeMachinePage
/home/library                → LibraryPage
/home/playlist/:playlistId   → PlaylistPage
/home/artist/:artistId       → ArtistPage → renders PlaylistPage(isArtist:true)
/home/folder/:id/:name       → PlaylistFolderPage
/search                      → SearchPage | OfflineSearchPlaceholder
/search/artist/:artistId     → ArtistPage
/library                     → LibraryPage
/library/userSongs/:page     → UserSongsPage   (page ∈ liked | recents | offline)
/library/artist/:artistId    → ArtistPage
/settings                    → SettingsPage
/settings/license            → LicensePage (Flutter built-in)
/settings/about              → AboutPage
/settings/equalizer          → EqualizerPage

Navigator-only (no route path):
  NowPlayingPage        ← MiniPlayer tap / drag-up
  SpotifyImportHubPage  ← Library AppBar action (OfflineAwareLibrarySpotifyImportAction),
                          online only — NOT a bottom-nav FAB (see §4 correction)
    → SpotifyImportPage             (Step 1 of 4)
    → SpotifyMatchingPage           (Step 2 of 4)
      → SpotifyMatchReviewPage → SpotifyManualMatchPage      (detailed queue)
      → SpotifyReviewSprintPage → SpotifyManualMatchPage     (quick review)
    → SpotifyImportDestinationPage  (Step 4 of 4 — NEW, see §2.3)
```

**Correction vs the PR #7-era baseline:** the Spotify FAB on the bottom
navigation shell has been **removed**. `lib/screens/bottom_navigation_page.dart`
no longer references Spotify or hosts a FAB at all (confirmed: zero matches
for "Spotify"/"FloatingActionButton" in that file). Import entry is now an
AppBar action, `OfflineAwareLibrarySpotifyImportAction`
(`lib/widgets/library_spotify_import_action.dart:52`), wired from
`lib/screens/library_page.dart:127`.

**No dedicated artist screen:** `ArtistPage` still resolves the artist then
renders `PlaylistPage(isArtist: true)` — unchanged from the PR #7 baseline.

---

## 2. Screen and flow inventory

Risk classification: **Critical** (deepest, most fragile coupling — treat as
a preservation-first zone), **High** (significant state/data coupling),
**Medium**, **Low** (mostly static/presentational).

### 2.1 Core navigation shell

| Screen | Source | Route/entry | Purpose | Must-preserve behavior | Risk |
|---|---|---|---|---|---|
| Bottom Navigation Shell | `lib/screens/bottom_navigation_page.dart` | Wraps all tab branches | Hosts nav bar/rail, mini-player overlay | Back-on-non-home → `goBranch(0)`; home-back → `SystemNavigator.pop`; offline hides Search tab; double-tap tab → reset to initial location; mini-player reserves bottom padding via `miniPlayerTotalHeight`. **No longer hosts a Spotify FAB** (moved to Library AppBar). | High |
| Home | `lib/screens/home_page.dart` | `/home` (offline swaps to `UserSongsPage(page:'offline')`) | Suggested/liked playlists, recap teaser, recommended songs | Playlist tap → push; recap CTA → Time Machine; play via `audioHandler`; dismiss announcement persists `announcementURL` | Medium |
| Search | `lib/screens/search_page.dart` | `/search` (offline → `OfflineSearchPlaceholder`) | Search songs/artists/albums/playlists + history | Writes Hive `searchHistory`; debounced suggestions; long-press history → confirm → remove; artist tap passes `extra` map | Medium |
| Offline Search Placeholder | `lib/widgets/offline_search_placeholder.dart` | Router swap for `/search` offline | Static offline message | — | Low |
| Library | `lib/screens/library_page.dart` | `/library`, `/home/library` | Pinned/custom/folder/offline/liked playlists + artists; hosts the Spotify import AppBar action | Recents/Liked/Offline → `router.go('/library/userSongs/{page}')`; folder/playlist create/delete; offline empty-library special UI; `OfflineAwareLibrarySpotifyImportAction` hidden/disabled offline (`library_page.dart:127`) | High |
| User Songs (liked/recents/offline) | `lib/screens/user_songs_page.dart` | `/library/userSongs/:page` | List + search/sort/play one song collection | `page` must remain one of `liked`\|`recents`\|`offline`; clear-recents confirms then wipes Hive; offline sort persisted; Liked view now uses `PersonalizedReveal` + compact header + smaller artwork | Medium–High |
| Playlist / Album detail | `lib/screens/playlist_page.dart` + `lib/widgets/playlist_page/*` | `/home/playlist/:playlistId` | Load/play/search/sort/share/download a playlist; dual-purpose as artist view | Custom-playlist mutations; share link format `musify://playlist/custom/...`; offline download/cancel/remove; `isArtist` mode branching; `playlist_header.dart` gained a `compact` padding variant | High |
| Artist | `lib/screens/artist_page.dart` | `/home/artist/:id`, `/search/artist/:id`, `/library/artist/:id` | Resolve artist → render as `PlaylistPage(isArtist:true)` | Loading/not-found states; offline uses downloaded catalog only; passes preferred name/image/sourceSongId via `extra` | High |
| Playlist Folder | `lib/screens/playlist_folder_page.dart` | `/home/folder/:id/:name` | Manage playlists inside a folder | Add/rename/delete-folder dialogs; remove-playlist-from-folder | Medium |
| Settings | `lib/screens/settings_page.dart` | `/settings` | Theme/language/audio/EQ/offline/proxy/stats toggles; backup/restore; about; verified-update check | Most toggles write Hive + toast; offline toggle calls `NavigationManager.refreshRouter()`; destructive clears always confirm first; "Check for personalized update" triggers `checkAppUpdates(showWhenCurrent: true)` (`settings_page.dart:371-376`); **Data safety section still lives under `_buildOnlineFeaturesSection` and remains unreachable offline** (confirmed still true, `settings_page.dart:72`, ~385) | High |
| Equalizer | `lib/screens/equalizer_page.dart` | `/settings/equalizer` | Enable EQ + band gains + presets | Platform audio API coupling; persisted via settings/audio handler | Medium |
| About | `lib/screens/about_page.dart` | `/settings/about` | Brand/version/author/social links | Mostly static | Low |
| License | Flutter `LicensePage` | `/settings/license` | OSS license list | Framework-provided | Low |
| Time Machine | `lib/screens/time_machine_page.dart` | `/home/timeMachine` | Listening recap, share PNG, expand song lists | Empty if stats disabled/absent; `RepaintBoundary` PNG share; offline embeds `UserSongsPage(offline)` | Medium |

### 2.2 Player

| Screen | Source | Entry | Must-preserve behavior | Risk |
|---|---|---|---|---|
| Mini Player | `lib/widgets/mini_player.dart` | Persistent overlay in shell when `audioHandler.mediaItem != null` | Hidden when no media; tap/drag-up opens Now Playing; play/pause/`playAgain`-on-completed; skip-next gated on queue; progress from throttled (120 ms) position stream; `Hero` tag `now_playing_artwork` shared with full player; fixed height `72` used as a shell layout contract (`miniPlayerTotalHeight`) | **Critical** |
| Now Playing (full player) | `lib/screens/now_playing_page.dart` + `lib/widgets/now_playing/*` | `Navigator.push` from mini-player (slide-up `PageRouteBuilder`) | Null-media → spinner; live streams hide transport; play/pause/prev/next; shuffle; repeat cycles none→all→one, next-under-repeat-one = `playAgain`; seek via `PositionSlider`; artist tap pops NP then pushes artist route with extras; offline toggle optimistic + rollback; like toggle; add-to-playlist; queue bottom sheet (mobile) / persistent panel (desktop ≥800×600); sleep timer set/cancel/end-of-song; lyrics flip disabled offline | **Critical** |

### 2.3 Spotify import → matching → review → destination pipeline (4 steps)

**Correction vs the PR #7-era baseline:** the pipeline is now explicitly a
**4-step flow** ("Step N of 4" copy at `spotify_import_page.dart:126`,
`spotify_matching_page.dart:220`, `spotify_import_destination_page.dart:182`),
not 3. Step 4 (Destination) did not exist on the PR #7 branch.

Shared Hive persistence (`user` box): `spotifyImportTracks`,
`spotifyImportMetadata`, `spotifyMatchResults`, `spotifyExcludedImportRows`.

| Screen/flow | Source | Entry | Purpose | Exact contracts that must survive redesign | Risk |
|---|---|---|---|---|---|
| Import Hub | `lib/screens/spotify_import_hub_page.dart` | Library AppBar action (online) | 4-step launcher | Pure navigation; no Hive I/O; step 04 label is Destination (`hub:89-100`) | Low–Medium |
| Import CSV | `lib/screens/spotify_import_page.dart` (Step 1 of 4) + `lib/services/spotify_csv_importer.dart` + **`lib/services/spotify_import_session_service.dart`** | Hub step 01 | Parse/validate/preview/persist CSV | Header aliases (title/artist required; album/ISRC/duration/added-at optional); format detection (Spotify/Exportify vs Soundiiz vs generic); duration heuristic (`<10000` → seconds→ms); quoted-CSV escaping; **save now goes through `SpotifyImportSessionService.saveNewImport`, which atomically writes tracks + metadata + an emptied `spotifyMatchResults` + emptied `spotifyExcludedImportRows`, with automatic rollback-to-previous-values on any write failure** (`spotify_import_session_service.dart:23-68`, called at `spotify_import_page.dart:95`). **This fixes the PR #7-era "stale match results survive re-import" defect — confirmed fixed, not merely planned.** | High |
| Matching | `lib/screens/spotify_matching_page.dart` (Step 2 of 4) + `lib/services/spotify_track_matching_service.dart` + `lib/services/spotify_match_scoring.dart` | Hub step 02 | Batch YTM/YouTube search + score + checkpoint | Auto-match ≥0.86 (+eligibility gate), review-band ≥0.58, else unmatched; 3-step search cascade; checkpoint every 5 tracks + truncate-past-`nextTrackIndex` on resume; pause/all-remaining gating (`nextTrackIndex≥50`, usefulRate≥0.90, unmatchedRate≤0.10 — usable-attempt denominator now **subtracts `excludedCount`**, `spotify_track_matching_service.dart:59-67`); excluded rows are skipped during matching; restart clears match results but keeps CSV | **Critical** |
| Detailed review ("repair workspace") | `lib/screens/spotify_match_review_page.dart` + `lib/services/spotify_review_workflow_service.dart` | Matching "Open detailed queue" | Metrics + rescue pass + per-item resolve + **permanent exclude** | Pending = `needs_review\|unmatched\|error`; rescue auto-accepts only "safe" `needs_review` (title≥0.98, artist≥0.95, score≥0.80, no version-risk term, `isSafeClusterItem`); resolve: accept→`manually_matched`, reject→`manual_unmatched` (durable, no confirmation dialog on individual reject); **exclude → `excluded` status via `showPersonalizedDestructiveConfirmation`, tracked in `spotifyExcludedImportRows` — a third, distinct terminal state from reject** (`spotify_review_workflow_service.dart:328-374`); exact-ISRC duplicates among pending auto-resolve; no undo for any of accept/reject/exclude | **Critical** |
| Manual match | `lib/screens/spotify_manual_match_page.dart` | Detailed/Sprint "Search manually" | Free-text YTM+YouTube search, 30 s preview, save one candidate | Save → `manually_matched`, `reviewDecision:'manual_search'`; **now correctly updates `pendingResolutionCount`** (`spotify_manual_match_page.dart:325-327` — confirmed fixed, the PR #7-era counter-drift defect no longer applies) | High |
| Quick Review / Review Sprint | `lib/screens/spotify_review_sprint_page.dart` + `lib/widgets/review_swipe_deck.dart` (gesture logic **unchanged** vs PR #7) + `lib/services/review_sprint_prefetch_cache.dart` + `lib/services/review_sprint_audio_player.dart` | Hub step 03 / Matching / Detailed "Start quick review" | One-card-at-a-time accept/reject/postpone with audio preview, plus a separate permanent-exclude action | **Right/+dx → accept** (persists selected alternative, cluster key = the accepted alternative); **Left/−dx → reject** → `manual_unmatched`/`review_sprint_no_match` (durable, no undo, but is *not* the same as exclusion); **Up (`\|dy\|>\|dx\|*0.85`) → postpone** (session-only reorder, not persisted); a **separate "Exclude permanently" button** (not a swipe gesture) opens `showPersonalizedDestructiveConfirmation` then sets status `excluded` — **this is the correction to the PR #7-era assumption that left-swipe was the only/permanent-exclusion action; on master, reject and exclude are two distinct, separately-triggered terminal states.** Commit thresholds 28% width / 20% height or velocity>900; haptics: `selectionClick` at threshold, `mediumImpact` on commit; accept blocked when `canAccept:false`; auto-preview 12 s, seek-to-20s if candidate>75s; prefetch top-alt for next 6 items + artwork precache next 4, LRU cache cap 12; **"Approve similar" bulk action requires ≥5 accepts and 0 rejects on a cluster (`_clusterAuditThreshold=5`), confirms, then `bulkApproveCluster` writes status `matched`/`audited_cluster_approval` (distinct from the individual-accept `manually_matched` status) and validates the import session ID first** | **Critical** |
| **Destination (NEW — Step 4 of 4)** | `lib/screens/spotify_import_destination_page.dart` + `lib/services/spotify_import_destination_service.dart` | Hub step 04 (only production entry point; not linked from matching/review/sprint screens directly) | Route already-resolved (`matched`/`manually_matched` with a `bestCandidate`) songs to Liked Songs, a new playlist, or an existing playlist, choosing all or an exact count | Kinds: `likedSongs \| newPlaylist \| existingPlaylist`; **unresolved rows are never moved** (banner shown if `unresolvedCount>0`); count selector defaults to all unique resolved songs by `ytid`, or an exact 1..N count taken in source order; Liked-songs routing prepends non-duplicate `ytid`s; new-playlist routing creates a playlist, or appends to an existing one if `title`+`importSourceName` already match (avoids duplicate playlists on retry); existing-playlist routing dedupes by `ytid` before appending; **session ID is re-validated immediately before the write** so a stale snapshot cannot silently route the wrong set; a routing-history write failure does not fail an otherwise-completed transfer; states: loading spinner, empty ("no resolved songs"), error banner, ready summary + destination pickers, pre-transfer confirm dialog, "Saving…" bottom bar, success SnackBar with added/already-present counts | **Critical** |

**Explicit clarification for redesigners (do not relabel without a product
decision):** three, not two, terminal outcomes exist for a reviewed item:
**accept** (matched/manually_matched), **reject** (`manual_unmatched`, no
undo, but recoverable in the sense that it is not flagged "excluded"), and
**exclude** (`excluded`, an explicit destructive action behind its own
confirmation, tracked separately in `spotifyExcludedImportRows`). **Postpone**
is a fourth, non-terminal, session-only deferral. Any visual redesign that
collapses reject and exclude into one visual treatment, or that makes
postpone look as permanent as reject/exclude, misrepresents real differences
in reversibility and audit trail — this is a UX-writing/visual-hierarchy
requirement, not just a data-contract note.

### 2.4 Safety-critical flows (backup, restore, recovery, update, identity)

| Flow | Source | Entry | Must-preserve behavior | UX weaknesses (presentation-only, safe to redesign) | Risk |
|---|---|---|---|---|---|
| Create verified backup | `lib/services/musify_backup_service.dart` (`createVerifiedBackup`) + `settings_page.dart` (`_backupUserData`) | Settings → Data safety → "Create verified backup" | Format `musify-personalized-backup`, schema v1; package/channel identity gates baked into the manifest; `BackupSummary` now includes `excludedItems`; freeze both boxes → validate → encode → picker; desktop re-reads the written file to verify, Android trusts the SAF picker write; **byte-for-byte re-open verification after save**; single-flight lock; success shown via a full verified dialog with path + counts | No progress/blocking UI during the operation; hardcoded English strings; **entire "Data safety" section is still hidden when the app is offline** (`settings_page.dart:72`, confirmed unchanged) — backup/restore/recovery remain unreachable offline | Critical |
| Restore from `.musifybackup` | `musify_backup_service.dart` (`inspectBundleBytes`, `restoreValidatedBackup`) + `settings_page.dart` | Settings → Data safety → "Restore from backup" | Format/schema/identity checks; SHA-256 + length check; **pre-restore step now shows a validated-summary confirm dialog ("Restore verified data", `settings_page.dart:994-1022`)**; journaled replace (`replacing`→verify/reopen→`verified`→delete pre-restore); auto-rollback on failure; concurrent-op lock | **Post-restore outcome (success or failure) is still reported via `showToast(result.message)` (`settings_page.dart:1025-1051`), asymmetric with backup's full dialog** — confirmed still true on master, this is a real, still-open presentation gap, not fixed by PR #17; no progress UI during the restore itself | Critical |
| Legacy debug recovery | `musify_backup_service.dart` (`pickAndInspectLegacyPair`) | Settings → "Recover legacy debug data" | Exactly two named files (`user.hive`+`settings.hive`); reject count mismatch; same transactional restore+rollback | No explicit "expected count" gate visible in UI; doesn't show current app package/channel to confirm destination | Critical |
| Interrupted-restore recovery | `musify_backup_service.dart` (`recoverInterruptedRestoreIfNeeded`), called from `main.dart:293` before Hive boxes open | App cold start, no UI | Runs outside the broad init try/catch; must fail closed | None (intentionally silent) — do not add UI here without care | Critical |
| Verified in-app update (personalized) | `lib/services/personalized_update_service.dart` + `lib/widgets/personalized_update_dialog.dart`, orchestrated by `lib/services/update_manager.dart` (`checkAppUpdates`) | Launch (opt-in / first-run prompt, `main.dart:171-184`) / Settings → "Check for personalized update" (`settings_page.dart:371-376`, `showWhenCurrent:true`) | **This is the correct, fork-scoped update path** — `PersonalizedUpdateService` fetches `https://api.github.com/repos/topcat432/musify-personalized/releases/latest` (`personalized_update_service.dart:10-13`) and validates schema version, package identity (`com.topcat432.musifypersonalized`), signer SHA-256, APK SHA-256, and release-asset URL shape before offering install | Update-availability check is correctly scoped; no defect found here on master | Medium |
| Legacy announcement fetch | `update_manager.dart` (`fetchAnnouncementOnly`) | Launch | Only fetches a home-screen announcement string, **not** an APK | **Still points at upstream `raw.githubusercontent.com/gokadzev/Musify/update/check.json`** (`update_manager.dart:24-25`, confirmed still present on master) — a fork-identity/content-accuracy defect, but a much narrower one than previously described: no APK is fetched from upstream, only announcement text. See Plan §16 for the corrected severity. | High (accuracy of displayed announcement content), not Critical (no unsafe install path) |
| Debug vs production identity | `main.dart` DEBUG banner; backup manifest package/channel tagging; `android/app/build.gradle.kts` suffixes | Always-on in debug builds | Separate packages/storage; banner debug-only; backups tagged with correct origin | No persistent "About this install" (package/channel/signer) surface in Settings | High |

### 2.5 Shared overlays, dialogs, sheets, menus, snackbars

| Overlay | Source | Used from | Must-preserve behavior | Risk |
|---|---|---|---|---|
| `ConfirmationDialog` | `lib/widgets/confirmation_dialog.dart` | Library, search, settings, queue, user songs, offline playlist, folder | Cancel never mutates; dangerous variant uses error color | Low (widget) / Medium (call sites) |
| `showPersonalizedDestructiveConfirmation` | `lib/widgets/personalized_ui.dart:439-522` | Review Sprint "Exclude permanently"; Detailed Review exclude action | Themed bottom-sheet confirm with "Keep track" vs destructive confirm button; distinct from `ConfirmationDialog` | High (gates a durable, audited, hard-to-reverse state) |
| Create/Add-to-playlist dialogs | `lib/utilities/playlist_dialogs.dart` | Library, playlist page, song menus | Persist playlist membership; toast on success/failure | High |
| `EditPlaylistDialog` | `lib/widgets/edit_playlist_dialog.dart` | Playlist page/bar | Returns edit map; caller persists | Medium |
| `RenameSongDialog` | `lib/widgets/rename_song_dialog.dart` | Song overflow menu | Empty fields → inline error, not silent accept | Medium |
| Remove-offline-playlist dialog | `lib/utilities/offline_playlist_dialogs.dart` | Library/bar/playlist page | Confirms before removing downloaded content | Medium |
| Custom bottom sheet host | `lib/utilities/flutter_bottom_sheet.dart` | Settings pickers, queue (mobile) | Non-modal `showBottomSheet`, single active instance, closes on tab change | Medium |
| Settings pickers (accent/theme/language/audio quality) | `settings_page.dart` | Settings rows | Persist immediately; some call `Musify.updateAppState` | Medium |
| Settings destructive-clear dialogs | `settings_page.dart` (`_showConfirmationDialog`) | Clear search/recents/stats/downloads | Confirm required; stats clear is "dangerous" styled | High |
| Backup/restore dialogs | `settings_page.dart` | Data safety section | Backup success: full verified dialog with path+counts. **Restore: pre-restore validated-summary confirm dialog, but post-restore outcome is a toast** — a confirmed, still-open asymmetry | Critical |
| Personalized update dialog | `lib/widgets/personalized_update_dialog.dart` | Launch / Settings "Check for personalized update" | Shows verified release notes, hash/signer proof, cancellable download; distinct from the legacy announcement text | Medium |
| Sleep timer dialog | `now_playing/bottom_actions_row.dart` | Now Playing timer button | Cancel closes; set applies `audioHandler.setSleepTimer`; active timer tap cancels | Medium |
| Queue widget + clear dialog | `lib/widgets/queue_list_view.dart` | Now Playing (panel/sheet) | Reorder/dismiss/skip; clear confirms first | High |
| Song overflow menu | `lib/widgets/song_bar.dart` + `OverflowMenuButton` | Every song row | Each action mutates queue/likes/offline/playlist/Hive; several toast | High |
| Playlist/folder overflow menus | `lib/widgets/playlist_bar.dart`, `playlist_folder_page.dart` | Library/folder rows | Pin/like/delete/move/edit/offline actions | High |
| Spotify confirm dialogs | Matching ("all remaining", "restart"), Detailed/Sprint ("exclude permanently", "approve similar"), Destination ("confirm transfer") | Respective screens | All cancel → no-op; all confirm start a real, sometimes destructive, operation | High |
| Toast/SnackBar system | `lib/utilities/flutter_toast.dart` | App-wide (dozens of call sites, including restore's outcome) | Bottom margin accounts for mini-player height; default icon is a checkmark unless the caller overrides it (e.g. restore failure explicitly passes an error icon, `settings_page.dart:1049`) | Medium |
| Announcement banner | `lib/widgets/announcement_box.dart` | Home | Dismiss persists `announcementURL`; content still sourced from upstream `gokadzev/Musify` check.json | Low (visual) / Medium (content accuracy) |

---

## 3. Reusable component inventory

The `personalized_ui.dart` suite is now **9 primitives**, not 6 — all
confirmed in active use via direct usage search, not just documented
aspirationally:

- `PersonalizedHero`, `PersonalizedSurface`, `PersonalizedSectionHeading`,
  `PersonalizedStatusBanner`, `PersonalizedMetric`, `PersonalizedEmptyState`
  (present on the PR #7 branch too);
- `PersonalizedReveal` (staggered entrance, reduced-motion aware) — used by
  Hub, Import, Destination, Matching, Match Review, and the Liked Songs view
  of User Songs, and nested inside `PersonalizedHero` itself;
- `personalizedPageRoute` (320 ms/240 ms fade+slide, reduced-motion aware) —
  used by all 4 hub steps, Library→Hub, Matching, Match Review, Review→Manual;
- `showPersonalizedDestructiveConfirmation` — used by Review Sprint's and
  Detailed Review's "Exclude permanently" actions.

New reusable widgets since the PR #7 baseline: `lib/widgets/library_spotify_import_action.dart`
(`OfflineAwareLibrarySpotifyImportAction`, the AppBar entry point that replaced
the bottom-nav FAB) and `lib/widgets/personalized_update_dialog.dart`.

Broadly reusable core widgets (used by 3+ screens, unchanged from before):
`SongBar`, `PlaylistBar`, `PlaylistCube`, `ConfirmationDialog`, `Spinner`,
`MarqueeWidget`, `SortChips`, `CustomBar`, `SectionHeader`,
`MiniPlayerBottomSpace`, `SongArtworkWidget`, `EmptyPlaylistState`.

**Confirmed dead code** (defined, zero references anywhere else in `lib/`;
re-verified on master): `ShufflePlayButton`
(`lib/widgets/playlist_page/shuffle_play_button.dart`),
`PlaylistActionButtons` (`lib/widgets/playlist_page/playlist_action_buttons.dart`).
Decide during implementation planning whether to wire them up or remove them.

---

## 4. Design tokens and hard-coded presentation

Unchanged from the PR #7-era findings — this part of the audit was not
materially affected by PR #17's hardening, since that work focused on
behavior/data safety rather than the design-token layer:

- **Color:** No semantic token layer beyond `ColorScheme`. `lib/theme/app_colors.dart`
  is only a 20-entry accent-seed picker. Raw `Color(0x…)`/`Colors.*` literals
  remain concentrated in `spotify_review_sprint_page.dart`'s black/white
  overlay gradients, which bypass `ColorScheme` and will fight light/pure-black
  themes.
- **Typography:** No custom `TextTheme` in `getAppTheme` (`lib/theme/app_themes.dart`).
  Two coexisting styles remain: raw `TextStyle(fontSize: …)` (older core
  screens) vs `textTheme.copyWith` (personalized/Spotify screens +
  `personalized_ui.dart`). Dead token: `commonBarTitleStyle`
  (`app_constants.dart:28`) still defined but unused.
- **Spacing:** Only 4 shared constants exist
  (`commonSingleChildScrollViewPadding`, `commonBarContentPadding`,
  `commonListViewBottomPadding`, `miniPlayerTotalHeight`). Dozens of raw
  `EdgeInsets` values remain across the codebase, now including the new
  Destination screen.
- **Shape/elevation:** Theme defines card=16, input=12, dialog=28,
  popup/snackbar=12. Widget-local radii still add many more distinct values.
- **Icons:** Fluent UI (`FluentIcons.*`) is the core system; Material
  `Icons.*` dominates the Spotify/personalized fork (now including the new
  Destination screen) plus a few spots in `settings_page.dart`.
- **Motion:** `docs/VISUAL_SYSTEM.md`'s documented vocabulary (220/240/320/240/360 ms)
  is now provably real code, not aspirational — `PersonalizedSurface` (220 ms),
  `PersonalizedMetric` (240 ms), `personalizedPageRoute` (320/240 ms),
  `PersonalizedReveal` (360 ms + delay) all match exactly. However, these
  values still live as literals inside each widget rather than as named
  shared constants — extracting them into a `lib/theme/motion.dart` remains a
  valid, low-risk upgrade (it would not change any behavior, only remove
  duplication).
- **Responsive/light-dark:** No changes found vs the PR #7-era findings.

---

## 5. State coverage (loading / empty / error / offline / disabled / success / partial-progress / destructive-confirmation)

Strongest coverage: the Spotify import/matching/review/**destination**
screens (the new Destination screen alone demonstrably covers loading, empty,
error, ready/success, and a distinct "Saving…" partial-progress state) and
`playlist_page.dart`. Weakest: `home_page.dart`, `about_page.dart`,
`now_playing_page.dart`, `bottom_navigation_page.dart`, `equalizer_page.dart`.
No shimmer/skeleton pattern exists anywhere in the app — all loading states
are spinners or progress bars. The Settings "Data safety" section still lacks
loading/disable-while-busy UI and remains the highest-risk gap given what it
protects.

---

## 6. Accessibility, gestures, motion, haptics

Unchanged from the PR #7-era findings; PR #17's hardening work did not add or
remove Semantics/haptics coverage in the areas it touched:

- **Haptics** exist in exactly one place: `review_swipe_deck.dart`
  (`selectionClick` at threshold, `mediumImpact` on commit). Nowhere else,
  including the new Destination screen.
- **Semantics** remains sparse; present on `PlaybackIconButton`, the Import
  Hub's step rows, `PersonalizedMetric`, and some Review Sprint controls. The
  new Destination screen was not confirmed to add new Semantics coverage
  beyond what these shared primitives already provide.
- **Touch targets, text scaling, rapid-tap/interruption guarding:** no change
  found vs the PR #7-era findings.

---

## 7. Tests and golden-screenshot coverage

**Correction vs the PR #7-era baseline:** `tool/visual_review_test.dart` now
produces **8 goldens**, not 3:

- `import_hub_light.png`
- `import_destination_light.png` (NEW)
- `import_destination_compact_dark.png` (NEW)
- `import_destination_options_compact_dark.png` (NEW — scrolled to
  existing-playlist option)
- `import_destination_dialog_compact_dark.png` (NEW — transfer confirm with
  4-digit counts)
- `quick_review_light.png`
- `quick_review_compact_dark.png`
- `personalized_update_compact_dark.png` (NEW)

As before, this directory is generated fresh via `--update-goldens` in
`.github/workflows/debug.yml` and is not committed to the repository.

**Test files:** in addition to the PR #7-era suite (CSV import parsing, match
scoring, review-workflow rules, prefetch cache, review-swipe-deck gestures,
backup-service checksum/rollback/recovery), master adds dedicated tests for
`spotify_import_destination_service_test.dart`,
`spotify_import_session_service_test.dart`,
`spotify_manual_source_service_test.dart`,
`personalized_update_service_test.dart`,
`library_spotify_import_action_test.dart`, and
`personalized_update_dialog_test.dart`.

**Zero test and zero golden coverage remains for:** Home, Search, Library,
Playlist, Playlist Folder, User Songs, Artist, Now Playing, Bottom Navigation
shell, Settings, About, Equalizer, Time Machine. This is unchanged from the
PR #7-era finding — almost the entire visible core-app surface still has no
automated regression net; only the Spotify pipeline and updater are covered.

---

## 8. Screen-by-screen upgrade opportunities (non-exhaustive, expand during implementation)

- Unify iconography (pick one of Fluent/Material, or explicitly define which
  screens use which and why) — the new Destination screen inherits the
  Material convention from the rest of the Spotify fork, so this is now one
  more screen to migrate if Fluent is chosen.
- Introduce and enforce spacing/radius/typography/motion tokens; extract the
  now-confirmed-real 220/240/320/360 ms motion values into named constants.
- Route the Review Sprint card's black/white overlay gradients through
  `ColorScheme` so they behave correctly in light and pure-black themes.
- Make backup/restore/recovery UI reachable offline, add progress/blocking UI,
  and **make restore's post-outcome presentation as strong as backup's**
  (dialog with counts, not a toast) — this remains a real, unfixed gap on
  master.
- Give the Destination screen's three routing kinds (Liked/new
  playlist/existing playlist) a stronger visual hierarchy given they are now
  a first-class step, not an afterthought.
- Visually distinguish reject vs. exclude vs. postpone in the Review Sprint UI
  so their different reversibility reads clearly (see §2.3 clarification).
- Add Semantics labels to playlist cubes, the mini-player, list rows, and the
  new Destination screen's controls.
- Add golden coverage for every screen listed as zero-coverage in §7 before
  restyling it, per `docs/VISUAL_SYSTEM.md`'s own acceptance checklist.
- Decide the fate of `ShufflePlayButton`/`PlaylistActionButtons` (wire up or
  remove) as part of the playlist-page overhaul.
- Consider surfacing the legacy-announcement-vs-verified-update distinction
  more clearly in the UI, since they are two different systems with two
  different trust levels (see Plan §16).

See `docs/VISUAL_OVERHAUL_PLAN.md` for the systemic direction and phased
implementation sequence built on top of this baseline.
