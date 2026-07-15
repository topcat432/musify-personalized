# Musify Personalized — Visual Overhaul Baseline

## Status and provenance

Read-only frontend inventory produced on branch `agent/full-visual-overhaul`,
starting point `b6fee783a1a91389ddffd0f78d89dbcc70dab329` (= tip of
`origin/agent/review-sprint-overhaul`, PR #7, itself stacked on PR #4
`agent/data-recovery-hardening`). No application source was changed to produce
this document. Findings below were gathered by direct source inspection and by
six read-only research passes, each independently re-verified against the
actual files, current tests, and governance documents before being recorded
here.

**Read `docs/VISUAL_OVERHAUL_PLAN.md` section "Conflict zones inherited from PR
#4 and PR #7" before treating this file as a description of the current
`master`.** This baseline describes the code on *this branch*, which is a
superseded fork point relative to `master` (see that section for the exact
evidence).

---

## 0. Governance context that shapes this baseline

- `docs/MASTER_AGENT_HANDOVER.md`, `docs/DECISIONS.md`, `docs/VISUAL_SYSTEM.md`,
  and `docs/RELEASE_STATE.md` were added to this branch by cherry-picking the
  shared-agent bootstrap commit (`6711936…`, PR #18) after this branch was
  created. They were not available when PR #4/#7 were written.
- `docs/VISUAL_SYSTEM.md` already documents an established warm/dark/premium,
  album-driven direction, a semantic-`ColorScheme`-only color rule, a
  typography convention, a shape/spacing vocabulary (radii 28/24/18, padding
  22/18/24), and a motion vocabulary (220/240/320/240/360 ms). Treat this as
  the **existing baseline direction to extend and formalize**, not as a reason
  to invent an unrelated visual language. Where the plan proposes new token
  values, it says explicitly whether it reuses, extends, or deliberately
  departs from these documented values.
- Some components referenced by `docs/VISUAL_SYSTEM.md` (`PersonalizedReveal`,
  `personalizedPageRoute`, `showPersonalizedDestructiveConfirmation`) **do not
  exist in `lib/widgets/personalized_ui.dart` on this branch** — they were
  confirmed absent by direct search. They exist on `master` (post PR #17
  "harden review and destination flows"). This is one concrete symptom of the
  branch-staleness conflict described in the plan.
- Product invariants that constrain every screen in this inventory (from
  `docs/MASTER_AGENT_HANDOVER.md` §3, §8 and `docs/DECISIONS.md` D-002/D-004/D-005):
  unmatched, review, error, accepted, routed, and permanently-excluded states
  must never be conflated; import/matching must never silently mutate
  destinations or discard unresolved rows; backup/restore success requires
  structural + checksum + semantic + reopen + restart proof, never a toast or
  picker result alone.

---

## 1. Navigation architecture

**Router:** `lib/services/router_service.dart` (GoRouter, `StatefulShellRoute.indexedStack`,
4 tab branches: Home / Search / Library / Settings). Offline-mode redirects
`/search`, `/home/timeMachine`, and unavailable `/artist/:id` back to `/home`.
Tab-root transitions fade 180 ms; nested pushes fade+slide 220 ms
(`router_service.dart:327-371`).

**Imperative (`Navigator.push`) flows not in GoRouter:** Now Playing (from the
mini-player) and the entire Spotify import → matching → review subgraph (hub →
import → matching → detailed review → manual match → review sprint).

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
  SpotifyImportHubPage  ← Library FAB (online + Library tab only)
    → SpotifyImportPage
    → SpotifyMatchingPage
      → SpotifyMatchReviewPage → SpotifyManualMatchPage
      → SpotifyReviewSprintPage → SpotifyManualMatchPage
```

**Important note:** There is no dedicated "artist details modal." `ArtistPage`
resolves the artist then renders `PlaylistPage(isArtist: true)` — artist UI is
playlist-page reuse, not a separate surface.

---

## 2. Screen and flow inventory

Risk classification: **Critical** (deepest, most fragile coupling — treat as
a preservation-first zone), **High** (significant state/data coupling),
**Medium**, **Low** (mostly static/presentational).

### 2.1 Core navigation shell

| Screen | Source | Route/entry | Purpose | Must-preserve behavior | Risk |
|---|---|---|---|---|---|
| Bottom Navigation Shell | `lib/screens/bottom_navigation_page.dart` | Wraps all tab branches | Hosts nav bar/rail, mini-player overlay, Spotify FAB | Back-on-non-home → `goBranch(0)`; home-back → `SystemNavigator.pop`; offline hides Search tab; double-tap tab → reset to initial location; FAB opens Spotify hub only online + Library tab; mini-player reserves bottom padding via `miniPlayerTotalHeight` | High |
| Home | `lib/screens/home_page.dart` | `/home` (offline swaps to `UserSongsPage(page:'offline')`) | Suggested/liked playlists, recap teaser, recommended songs | Playlist tap → push; recap CTA → Time Machine; play via `audioHandler`; dismiss announcement persists `announcementURL` | Medium |
| Search | `lib/screens/search_page.dart` | `/search` (offline → `OfflineSearchPlaceholder`) | Search songs/artists/albums/playlists + history | Writes Hive `searchHistory`; debounced suggestions; long-press history → confirm → remove; artist tap passes `extra` map | Medium |
| Offline Search Placeholder | `lib/widgets/offline_search_placeholder.dart` | Router swap for `/search` offline | Static offline message | — | Low |
| Library | `lib/screens/library_page.dart` | `/library`, `/home/library` | Pinned/custom/folder/offline/liked playlists + artists | Recents/Liked/Offline → `router.go('/library/userSongs/{page}')`; folder/playlist create/delete; offline empty-library special UI | High |
| User Songs (liked/recents/offline) | `lib/screens/user_songs_page.dart` | `/library/userSongs/:page` | List + search/sort/play one song collection | `page` must remain one of `liked`\|`recents`\|`offline`; clear-recents confirms then wipes Hive; offline sort persisted | Medium–High |
| Playlist / Album detail | `lib/screens/playlist_page.dart` + `lib/widgets/playlist_page/*` | `/home/playlist/:playlistId` | Load/play/search/sort/share/download a playlist; dual-purpose as artist view | Custom-playlist mutations; share link format `musify://playlist/custom/...`; offline download/cancel/remove; `isArtist` mode branching | High |
| Artist | `lib/screens/artist_page.dart` | `/home/artist/:id`, `/search/artist/:id`, `/library/artist/:id` | Resolve artist → render as `PlaylistPage(isArtist:true)` | Loading/not-found states; offline uses downloaded catalog only; passes preferred name/image/sourceSongId via `extra` | High |
| Playlist Folder | `lib/screens/playlist_folder_page.dart` | `/home/folder/:id/:name` | Manage playlists inside a folder | Add/rename/delete-folder dialogs; remove-playlist-from-folder | Medium |
| Settings | `lib/screens/settings_page.dart` | `/settings` | Theme/language/audio/EQ/offline/proxy/stats toggles; backup/restore; about | Most toggles write Hive + toast; offline toggle calls `NavigationManager.refreshRouter()`; destructive clears always confirm first | High |
| Equalizer | `lib/screens/equalizer_page.dart` | `/settings/equalizer` | Enable EQ + band gains + presets | Platform audio API coupling; persisted via settings/audio handler | Medium |
| About | `lib/screens/about_page.dart` | `/settings/about` | Brand/version/author/social links | Mostly static | Low |
| License | Flutter `LicensePage` | `/settings/license` | OSS license list | Framework-provided | Low |
| Time Machine | `lib/screens/time_machine_page.dart` | `/home/timeMachine` | Listening recap, share PNG, expand song lists | Empty if stats disabled/absent; `RepaintBoundary` PNG share; offline embeds `UserSongsPage(offline)` | Medium |

### 2.2 Player

| Screen | Source | Entry | Must-preserve behavior | Risk |
|---|---|---|---|---|
| Mini Player | `lib/widgets/mini_player.dart` | Persistent overlay in shell when `audioHandler.mediaItem != null` | Hidden when no media; tap/drag-up opens Now Playing; play/pause/`playAgain`-on-completed; skip-next gated on queue; progress from throttled (120 ms) position stream; `Hero` tag `now_playing_artwork` shared with full player; fixed height `72` used as a shell layout contract (`miniPlayerTotalHeight`) | **Critical** |
| Now Playing (full player) | `lib/screens/now_playing_page.dart` + `lib/widgets/now_playing/*` | `Navigator.push` from mini-player (slide-up `PageRouteBuilder`) | Null-media → spinner; live streams hide transport; play/pause/prev/next; shuffle; repeat cycles none→all→one, next-under-repeat-one = `playAgain`; seek via `PositionSlider`; artist tap pops NP then pushes artist route with extras; offline toggle optimistic + rollback; like toggle; add-to-playlist; queue bottom sheet (mobile) / persistent panel (desktop ≥800×600); sleep timer set/cancel/end-of-song; lyrics flip disabled offline | **Critical** |

### 2.3 Spotify import → matching → review pipeline (PR #4/#7 protected core)

Shared Hive persistence (`user` box): `spotifyImportTracks`,
`spotifyImportMetadata`, `spotifyMatchResults`.

| Screen/flow | Source | Entry | Purpose | Exact contracts that must survive redesign | Risk |
|---|---|---|---|---|---|
| Import Hub | `lib/screens/spotify_import_hub_page.dart` | Library FAB (online) | 3-step launcher | Pure navigation; no Hive I/O | Low–Medium |
| Import CSV | `lib/screens/spotify_import_page.dart` + `lib/services/spotify_csv_importer.dart` | Hub step 01 | Parse/validate/preview/persist CSV | Header aliases (title/artist required; album/ISRC/duration/added-at optional); format detection (Spotify/Exportify vs Soundiiz vs generic); duration heuristic (`<10000` → seconds→ms); quoted-CSV escaping; save resets `matchingStatus:'not_started'`, `nextTrackIndex:0`; does **not** touch Favorites; does **not** clear stale `spotifyMatchResults` on re-import (known gap, see Plan §16) | High |
| Matching | `lib/screens/spotify_matching_page.dart` + `lib/services/spotify_track_matching_service.dart` + `lib/services/spotify_match_scoring.dart` | Hub step 02 | Batch YTM/YouTube search + score + checkpoint | Auto-match ≥0.86 (+eligibility gate), review-band ≥0.58, else unmatched; 3-step search cascade; checkpoint every 5 tracks + truncate-past-`nextTrackIndex` on resume; `matchingVersion:3`; pause/all-remaining gating (`nextTrackIndex≥50`, usefulRate≥0.90, unmatchedRate≤0.10); restart clears match results but keeps CSV | **Critical** |
| Detailed review ("repair workspace") | `lib/screens/spotify_match_review_page.dart` + `lib/services/spotify_review_workflow_service.dart` | Matching "Open detailed queue" | Metrics + rescue pass + per-item resolve | Pending = `needs_review\|unmatched\|error`; rescue auto-accepts only "safe" `needs_review` (title≥0.98, artist≥0.95, score≥0.80, no version-risk term); resolve: accept→`manually_matched`, reject→`manual_unmatched` (durable, no confirmation dialog on individual reject); exact-ISRC duplicates among pending auto-resolve; no undo | **Critical** |
| Manual match | `lib/screens/spotify_manual_match_page.dart` | Detailed/Sprint "Search manually" | Free-text YTM+YouTube search, 30 s preview, save one candidate | Save → `manually_matched`, `reviewDecision:'manual_search'`; does not update `pendingResolutionCount` (known counter-drift gap, see Plan §16) | High |
| Quick Review / Review Sprint | `lib/screens/spotify_review_sprint_page.dart` + `lib/widgets/review_swipe_deck.dart` + `lib/services/review_sprint_prefetch_cache.dart` + `lib/services/review_sprint_audio_player.dart` | Hub step 03 / Matching / Detailed "Start quick review" | One-card-at-a-time accept/reject/postpone with audio preview | **Right/+dx → accept; Left/−dx → reject (permanent `manual_unmatched`, no undo); Up (dy-dominant) → postpone (session-only, not persisted)**; commit thresholds 28% width / 20% height or velocity>900; haptics: `selectionClick` at threshold, `mediumImpact` on commit; accept blocked when `canAccept:false`; auto-preview 12 s, seek-to-20s if candidate>75s; prefetch top-alt for next 6 items, LRU cache cap 12; 5-accepts/0-rejects same-cluster → "Approve similar" bulk action → `matched`/`audited_cluster_approval` | **Critical** |

**Explicit clarification for redesigners (do not relabel without a product
decision):** "No match" / left-swipe *is* the permanent-exclusion action
(`manual_unmatched`); there is no separate "exclude permanently" step and no
undo. "Postpone" / up-swipe is a temporary, session-only deferral that is lost
if the user leaves the screen. Any visual redesign that makes these two
gestures feel symmetric (e.g. identical color/weight) would misrepresent their
very different reversibility — this is a UX-writing/visual-hierarchy
requirement, not just a data-contract note.

### 2.4 Safety-critical flows (backup, restore, recovery, update, identity)

| Flow | Source | Entry | Must-preserve behavior | UX weaknesses (presentation-only, safe to redesign) | Risk |
|---|---|---|---|---|---|
| Create verified backup | `lib/services/musify_backup_service.dart` (`createVerifiedBackup`) + `settings_page.dart` (`_backupUserData`) | Settings → Data safety → "Create verified backup" | Flush both boxes; validate before write; **byte-for-byte re-open verification after save**; `.musifybackup` extension enforced; single-flight lock; success message shows path + counts | No progress/blocking UI during the operation; hardcoded English strings; **entire "Data safety" section is hidden when the app is offline** (`settings_page.dart:72`) — backup/restore/recovery become unreachable offline | Critical |
| Restore from `.musifybackup` | `musify_backup_service.dart` (`inspectBundleBytes`, `restoreValidatedBackup`) + `settings_page.dart` | Settings → Data safety → "Restore from backup" | Format/schema/identity checks; SHA-256 + length check; journaled replace (`replacing`→verify→`verified`→delete pre-restore); auto-rollback on failure; concurrent-op lock | Success reported via toast (not a verified dialog like backup's); no progress UI; restore confirm dialog not styled as dangerous | Critical |
| Legacy debug recovery | `musify_backup_service.dart` (`pickAndInspectLegacyPair`) | Settings → "Recover legacy debug data" | Exactly two named files (`user.hive`+`settings.hive`); reject count mismatch; same transactional restore+rollback | No explicit "expected count" gate visible in UI; doesn't show current app package/channel to confirm destination | Critical |
| Interrupted-restore recovery | `musify_backup_service.dart` (`recoverInterruptedRestoreIfNeeded`), called from `main.dart` before Hive boxes open | App cold start, no UI | Runs outside the broad init try/catch; must fail closed | None (intentionally silent) — do not add UI here without care | Critical |
| In-app update check/install | `lib/services/update_manager.dart` | Launch (opt-in) / Settings → Tools | Only signed production APKs; F-Droid path never prompts downloads | Update-check URLs point at `gokadzev/Musify`, not this fork (`update_manager.dart:39,41`) — **functional defect, not visual; do not fix in this phase, see Plan §16** | High |
| Debug vs production identity | `main.dart` DEBUG banner; backup manifest package/channel tagging; `android/app/build.gradle.kts` suffixes | Always-on in debug builds | Separate packages/storage; banner debug-only; backups tagged with correct origin | No persistent "About this install" (package/channel/signer) surface in Settings | High |

### 2.5 Shared overlays, dialogs, sheets, menus, snackbars

| Overlay | Source | Used from | Must-preserve behavior | Risk |
|---|---|---|---|---|
| `ConfirmationDialog` | `lib/widgets/confirmation_dialog.dart` | Library, search, settings, queue, user songs, offline playlist, folder | Cancel never mutates; dangerous variant uses error color | Low (widget) / Medium (call sites) |
| Create/Add-to-playlist dialogs | `lib/utilities/playlist_dialogs.dart` | Library, playlist page, song menus | Persist playlist membership; toast on success/failure | High |
| `EditPlaylistDialog` | `lib/widgets/edit_playlist_dialog.dart` | Playlist page/bar | Returns edit map; caller persists | Medium |
| `RenameSongDialog` | `lib/widgets/rename_song_dialog.dart` | Song overflow menu | Empty fields → inline error, not silent accept | Medium |
| Remove-offline-playlist dialog | `lib/utilities/offline_playlist_dialogs.dart` | Library/bar/playlist page | Confirms before removing downloaded content | Medium |
| Custom bottom sheet host | `lib/utilities/flutter_bottom_sheet.dart` | Settings pickers, queue (mobile) | Non-modal `showBottomSheet`, single active instance, closes on tab change | Medium |
| Settings pickers (accent/theme/language/audio quality) | `settings_page.dart` | Settings rows | Persist immediately; some call `Musify.updateAppState` | Medium |
| Settings destructive-clear dialogs | `settings_page.dart` (`_showConfirmationDialog`) | Clear search/recents/stats/downloads | Confirm required; stats clear is "dangerous" styled | High |
| Backup/restore dialogs | `settings_page.dart` | Data safety section | Success dialog shows path+counts (backup) vs toast (restore) — inconsistent | Critical |
| Update dialogs | `update_manager.dart` | Launch / Settings Tools | Enable-checks first-run prompt; update-available cancel/download | Medium |
| Sleep timer dialog | `now_playing/bottom_actions_row.dart` | Now Playing timer button | Cancel closes; set applies `audioHandler.setSleepTimer`; active timer tap cancels | Medium |
| Queue widget + clear dialog | `lib/widgets/queue_list_view.dart` | Now Playing (panel/sheet) | Reorder/dismiss/skip; clear confirms first | High |
| Song overflow menu | `lib/widgets/song_bar.dart` + `OverflowMenuButton` | Every song row | Each action mutates queue/likes/offline/playlist/Hive; several toast | High |
| Playlist/folder overflow menus | `lib/widgets/playlist_bar.dart`, `playlist_folder_page.dart` | Library/folder rows | Pin/like/delete/move/edit/offline actions | High |
| Spotify confirm dialogs | Matching ("all remaining", "restart"), Detailed ("rescue pass"), Sprint ("approve similar") | Respective screens | All cancel → no-op; all confirm start a real, sometimes destructive, operation | High |
| Toast/SnackBar system | `lib/utilities/flutter_toast.dart` | App-wide (dozens of call sites) | Bottom margin accounts for mini-player height; **default icon is a checkmark even for some error paths unless the caller overrides it** (presentation bug, safe to fix visually) | Medium |
| Announcement banner | `lib/widgets/announcement_box.dart` | Home | Dismiss persists `announcementURL` | Low |

---

## 3. Reusable component inventory

40 files under `lib/widgets/**` were cataloged. Broadly reusable (used by 3+
screens): `SongBar`, `PlaylistBar`, `PlaylistCube`, `ConfirmationDialog`,
`Spinner`, `MarqueeWidget`, `SortChips`, `CustomBar`, `SectionHeader`,
`MiniPlayerBottomSpace`, `SongArtworkWidget`, `EmptyPlaylistState`. Domain-scoped
but shared within their domain: the `personalized_ui.dart` suite (6 primitives:
`PersonalizedHero`, `PersonalizedSurface`, `PersonalizedSectionHeading`,
`PersonalizedStatusBanner`, `PersonalizedMetric`, `PersonalizedEmptyState`),
used by all 6 Spotify-flow screens (~52 usages) and by no core music screen.

**Confirmed dead code** (defined, zero references anywhere else in `lib/`):
`ShufflePlayButton` (`lib/widgets/playlist_page/shuffle_play_button.dart`),
`PlaylistActionButtons` (`lib/widgets/playlist_page/playlist_action_buttons.dart`).
Decide during implementation planning whether to wire them up or remove them —
do not silently keep dead code in the redesigned component set.

---

## 4. Design tokens and hard-coded presentation

- **Color:** No semantic token layer beyond `ColorScheme`. `lib/theme/app_colors.dart`
  is only a 20-entry accent-seed picker. 4 raw `Color(0x…)` literals and ~40
  `Colors.*` call sites exist outside theme files, concentrated in
  `spotify_review_sprint_page.dart:859-1272` (black/white overlay gradients that
  bypass `ColorScheme` and will fight light/pure-black themes).
- **Typography:** No custom `TextTheme` in `getAppTheme` (`lib/theme/app_themes.dart`).
  Two coexisting styles: ~90 raw `TextStyle(fontSize: …)` call sites (older
  core screens) vs ~90 `textTheme.copyWith` call sites (personalized/Spotify
  screens + `personalized_ui.dart`). Observed literal sizes: 11–36px with no
  shared scale. Dead token: `commonBarTitleStyle` (`app_constants.dart:28`) is
  defined but never used.
- **Spacing:** Only 4 shared constants exist (`commonSingleChildScrollViewPadding`,
  `commonBarContentPadding`, `commonListViewBottomPadding`, `miniPlayerTotalHeight`).
  ~25+ distinct raw `EdgeInsets` values observed across ~50 files.
- **Shape/elevation:** Theme defines card=16, input=12, dialog=28,
  popup/snackbar=12 (`app_themes.dart`). Widget-local radii add ~17 more
  distinct values (2–999, including pill radius 99 in the Spotify fork).
  `mini_player.dart` defines local radius `20`/artwork `14`, not aligned with
  the unused shared `commonMiniArtworkRadius` (8).
- **Icons:** Fluent UI (`FluentIcons.*`) is the core system (~40 files);
  Material `Icons.*` dominates the entire Spotify/personalized fork plus a few
  spots in `settings_page.dart`. This is a visible two-dialect split.
- **Motion:** No shared duration/curve tokens in code, even though
  `docs/VISUAL_SYSTEM.md` already documents an intended vocabulary
  (220/240/320/240/360 ms). Observed literals in code span 100–1500 ms across
  ~15 files with 7 different `Curves.*` values.
- **Responsive:** No shared breakpoint system. Ad hoc width checks: ≥600 (nav
  rail), >800 (desktop now-playing/queue split), >480 (home carousel), <360/<400
  (now-playing font/icon shrink). No multi-column tablet layout for
  library/search/playlists.
- **Light/dark:** `theme` and `darkTheme` in `main.dart` are built from the
  *already-selected* brightness rather than being two independent `ThemeData`
  objects — works via full rebuild on brightness change but is fragile.
  Pure-black mode overrides 4 surface tokens (`app_themes.dart:94-117`).

---

## 5. State coverage (loading / empty / error / offline / disabled / success / partial-progress / destructive-confirmation)

Strongest coverage: the Spotify import/matching/review screens (most have 6-8
of 8 states) and `playlist_page.dart`. Weakest: `home_page.dart`,
`about_page.dart`, `now_playing_page.dart`, `bottom_navigation_page.dart`,
`equalizer_page.dart` (2-3 of 8 states each). No shimmer/skeleton pattern
exists anywhere in the app — all loading states are spinners or progress bars.
The Settings "Data safety" section specifically lacks loading/disable-while-busy
UI and is the highest-risk gap given what it protects.

Full per-screen matrix is preserved in the underlying research transcripts and
should be re-derived against the actual implementation branch at
implementation time, since exact line numbers will shift.

---

## 6. Accessibility, gestures, motion, haptics

- **Haptics** exist in exactly one place: `review_swipe_deck.dart` (`selectionClick`
  at threshold, `mediumImpact` on commit). Nowhere else in the app.
- **Semantics** is sparse: present on `PlaybackIconButton`, the Import Hub's
  `_WorkflowStep` rows, `PersonalizedMetric`, and some Review Sprint controls.
  Most `CustomBar`/list rows, playlist cubes, and the mini-player's entire tap
  target have no Semantics label.
- **Touch targets:** Review Sprint's action buttons correctly use
  `minimumSize: Size(48,48)`. Multiple `visualDensity: VisualDensity.compact`
  IconButtons (mini-player skip-next, queue tiles, some Review Sprint icons)
  risk falling under 48×48dp.
- **Text scaling:** No `textScaler`/`textScaleFactor` overrides found anywhere
  — system scaling is not disabled, which is correct, but fixed font sizes in
  several places may still clip at large scale factors (untested).
- **Rapid-tap/async interruption:** Well-guarded in the Spotify flows (`mounted`
  checks, busy flags, generation tokens on sprint audio). Weaker in Settings
  backup/restore, where the UI does not lock itself even though the service
  layer has an internal `_operationInProgress` guard.

---

## 7. Tests and golden-screenshot coverage

- **Golden system:** `tool/visual_review_test.dart` produces 3 goldens
  (`import_hub_light`, `quick_review_light`, `quick_review_compact_dark`) under
  `tool/visual_review_goldens/`, generated fresh via `--update-goldens` in
  `.github/workflows/debug.yml` and uploaded only as a CI artifact — **the
  directory does not exist in the repository itself** (confirmed empty via
  direct search).
- **Test files** (`test/`, 7 files, excluding `packages/*/test`): CSV import
  parsing, match scoring, review-workflow pending/cluster rules, prefetch
  cache LRU/coalescing, review-swipe-deck gesture mapping, Review Sprint page
  widget behavior, and backup-service checksum/rollback/recovery behavior.
- **Zero test and zero golden coverage:** Home, Search, Library, Playlist,
  Playlist Folder, User Songs, Artist, Now Playing, Bottom Navigation shell,
  Settings, About, Equalizer, Time Machine, Spotify CSV Import screen,
  Spotify Matching screen, Spotify Match Review screen, Spotify Manual Match
  screen. This means almost the entire visible surface area of the app has no
  automated regression net today — the golden/test strategy in the plan must
  close this before large-scale visual changes land.

---

## 8. Screen-by-screen upgrade opportunities (non-exhaustive, expand during implementation)

- Unify iconography (pick one of Fluent/Material, or explicitly define which
  screens use which and why).
- Introduce and enforce spacing/radius/typography/motion tokens; retire the
  scattered literals cited in §4.
- Route the Review Sprint card's black/white overlay gradients through
  `ColorScheme` so they behave correctly in light and pure-black themes.
- Make backup/restore/recovery UI reachable offline, add progress/blocking UI,
  and make restore's success surface as strong as backup's (dialog with counts,
  not a toast).
- Add Semantics labels to playlist cubes, the mini-player, and list rows;
  audit compact-density IconButtons against 48×48dp.
- Add golden coverage for every screen listed as zero-coverage in §7 before
  restyling it, per `docs/VISUAL_SYSTEM.md`'s own acceptance checklist.
- Decide the fate of `ShufflePlayButton`/`PlaylistActionButtons` (wire up or
  remove) as part of the playlist-page overhaul.

See `docs/VISUAL_OVERHAUL_PLAN.md` for the systemic direction and phased
implementation sequence built on top of this baseline.
