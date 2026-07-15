# Musify Personalized — Visual Overhaul Plan

**Status:** Planning/audit only. No application-source implementation has
started. This plan targets `master` directly (branch
`agent/full-visual-overhaul-master`). Read
`docs/VISUAL_OVERHAUL_BASELINE.md` first.

## 0. Branch-lineage decision — resolved

An earlier version of this plan (preserved unchanged on branch
`agent/full-visual-overhaul` / draft PR #19) was written stacked on PR #7
(`agent/review-sprint-overhaul`) and flagged an unresolved conflict: PR #17,
already merged into `master`, contains a materially hardened implementation
of exactly the code this overhaul cares most about.

**That conflict is now resolved by explicit decision: the full visual
overhaul is implemented against current `origin/master`, because merged PR
#17 is the consolidated production implementation and explicitly supersedes
the older stacked PRs #3, #4, and #7.**

Consequences of this decision, verified directly against source while
reconciling this plan (not assumed):

- `master` (`a786323556275a0de745ffca4d3affc088ac2055`) contains PR #17's
  "harden review and destination flows" work and an entirely new Step 4
  Destination screen/service, a new session-transaction service, and a new
  fork-scoped verified-update system — none of which existed on the PR #7
  branch. See `docs/VISUAL_OVERHAUL_BASELINE.md` §2.3-§2.4 for the exact,
  re-verified contracts.
- PR #4 and PR #7 are **historical references only** — they describe an
  earlier, superseded implementation of the same product surface. Do not
  treat anything in those PRs' branches as the current contract; always check
  the equivalent logic on `master` instead.
- PR #19 (the PR #7-based audit checkpoint) is preserved, untouched, as an
  archival record of the pre-reconciliation state. It is not closed by this
  work and should not be revived as an implementation base.
- This reconciliation was performed as one bounded, targeted read-only pass
  (direct source inspection plus one scoped subagent covering ~15
  large-diff files), not a full re-run of the original six-way audit, per
  task scope.

---

## 1. Recommended visual direction

Unchanged in substance from the PR #7-era plan, and now backed by stronger
evidence: continue and formalize the direction `docs/VISUAL_SYSTEM.md`
already establishes — **warm, dark-forward, premium, cinematic,
album-art-driven** — expressed through Material 3 `ColorScheme` roles (never
fixed hex values) so it remains correct across dynamic-color, light, dark,
and pure-black modes.

On `master`, `docs/VISUAL_SYSTEM.md`'s description of the shared personalized
component suite is **accurate and complete** (all 9 primitives it implies —
including `PersonalizedReveal`, `personalizedPageRoute`, and
`showPersonalizedDestructiveConfirmation` — exist and are in active use). The
overhaul's job is still to take this from "a system used only by the Spotify
fork" to "a single enforced system used by every screen in the app," and to
extend it where `VISUAL_SYSTEM.md` is silent (a full type scale, a spacing
scale, a named motion-token file, an icon-set decision).

This is an explicit, scoped decision to depart from `docs/VISUAL_SYSTEM.md`'s
framing of itself as "a maintenance guide, not approval to redesign unrelated
product surfaces" — the current task instructions explicitly authorize a
comprehensive overhaul of presentation app-wide, provided behavior is
preserved. Record this as a new entry in `docs/DECISIONS.md` (`D-011`) once
Daniel confirms scope, since it changes the applicability of an existing
accepted decision (D-010).

---

## 2. Systems

### 2.1 Color

- Keep `ColorScheme.fromSeed`/dynamic-color as the source of truth; do not
  introduce a fixed brand palette.
- Add a small semantic-alias layer (e.g. `AppSemanticColors` extension on
  `ColorScheme` or a `ThemeExtension`) for meanings currently expressed as
  raw `Colors.black`/`Colors.white` + alpha: card overlay scrim,
  destructive/warning surfaces, success surfaces. Every raw-color call site
  cited in the baseline (§4), including the Review Sprint card overlays and
  the new Destination screen's status banners, should resolve to one of
  these aliases.
- Pure-black mode's 4 surface overrides stay as-is; extend the same override
  pattern to any new semantic alias so pure-black remains correct.

### 2.2 Typography

- Define a real `TextTheme` in `getAppTheme` instead of leaving Material's
  defaults in place, keeping `paytoneOne` for the app-bar/brand moments per
  existing convention.
- Formalize the scale `docs/VISUAL_SYSTEM.md` already describes qualitatively
  (hero/heading/section/body/eyebrow/metric roles — now provably matched by
  real widget code, see baseline §4) into actual `TextTheme` entries.
- Require every new/touched screen, including the Destination screen, to use
  `Theme.of(context).textTheme.*`, never a literal `fontSize`.

### 2.3 Spacing

- Introduce a small spacing scale (e.g. 4/8/12/16/20/24/32) as named
  constants in `lib/constants/app_constants.dart`, replacing ad hoc
  `EdgeInsets` literals identified in the baseline (§4), now including those
  in the Destination screen. Keep existing outer-page constants
  (`commonSingleChildScrollViewPadding`, etc.) as the outermost layer.

### 2.4 Shape & elevation

- Keep the existing theme-level values (card 16, input 12, dialog 28,
  popup/snackbar 12) as the canonical shape scale; retire stray widget-local
  radii by mapping each to the nearest canonical value or documenting a
  deliberate exception.
- Centralize shadow definitions (mini-player, artwork, sprint/destination
  cards) instead of repeating `Colors.black.withValues(...)` inline.

### 2.5 Icons

- Decide and document one rule: either (a) migrate the entire Spotify/
  personalized fork — now including the Destination screen — to Fluent icons
  to match the core app, or (b) formally adopt Material icons for all
  "personalized" surfaces as an intentional sub-brand. Recommendation
  unchanged: (a), for a single coherent icon language.

### 2.6 Motion

- Create a small `lib/theme/motion.dart` with named `Duration`/`Curve`
  constants. Unlike the PR #7-era plan, this is now extracting **real,
  already-implemented, already-consistent values** (confirmed: 220 ms
  `PersonalizedSurface`, 240 ms `PersonalizedMetric`, 320/240 ms
  `personalizedPageRoute`, 360 ms+delay `PersonalizedReveal`) rather than
  reconciling scattered ad hoc literals — this phase is lower-risk than
  originally scoped.
- Every new animation must use `MediaQuery.disableAnimations` for a
  reduced-motion path, matching the existing `PersonalizedReveal` convention
  (now confirmed to exist and be usable directly, not aspirational).
- Haptics: extend the `HapticFeedback` pattern currently isolated to the
  review swipe deck to other meaningful confirmations (exclude-permanently,
  destination-transfer confirm, successful backup/restore).

---

## 3. Shared component architecture

- Promote the full, now-confirmed 9-primitive `personalized_ui.dart` suite
  (`PersonalizedHero`, `PersonalizedSurface`, `PersonalizedSectionHeading`,
  `PersonalizedStatusBanner`, `PersonalizedMetric`, `PersonalizedEmptyState`,
  `PersonalizedReveal`, `personalizedPageRoute`,
  `showPersonalizedDestructiveConfirmation`) from "Spotify-flow-only" to
  app-wide shared primitives.
- Consolidate `EmptyPlaylistState` / `PersonalizedEmptyState` / ad hoc
  empty-state code into one configurable empty-state component.
- Give `ConfirmationDialog` and `showPersonalizedDestructiveConfirmation` a
  single documented decision rule for which one a given call site should use
  (today they coexist without an explicit rule).
- Resolve `ShufflePlayButton`/`PlaylistActionButtons` (baseline §3) as part of
  the playlist-page component pass.
- `library_spotify_import_action.dart` and `personalized_update_dialog.dart`
  should be folded into the same design-system review as the rest of the
  personalized suite, since they are newer additions built in the same idiom.

---

## 4. Navigation and information-architecture improvements

- No route/IA changes are required to achieve the visual goals. One
  structural note carried over from before: Artist has no dedicated screen
  (reuses `PlaylistPage`) — out of scope unless Daniel wants it addressed.
- Standardize transition timing: tab-root fades (180 ms), nested pushes
  (220 ms), the mini→full player transition (250 ms), and
  `personalizedPageRoute` (320/240 ms) are four independently-tuned values
  that should fold into the motion tokens in §2.6.
- The Spotify pipeline is now genuinely 4 steps end-to-end (Import → Match →
  Review → Destination); make sure any visual step-indicator treats all 4
  steps as first-class, not 3 steps plus an afterthought.

---

## 5. Screen-by-screen overhaul scope

Use `docs/VISUAL_OVERHAUL_BASELINE.md` §2 as the authoritative per-screen
table. Sequencing intent, updated for the master baseline:

1. **Foundation first** (tokens, no screen-visible change yet): color aliases,
   typography scale, spacing scale, motion-token extraction, icon-set
   decision.
2. **Low-risk screens**: About, Time Machine, Offline placeholder, Playlist
   Folder.
3. **Core navigation shell + Home/Search/Library/Settings** — note Library's
   Spotify entry point changed shape (AppBar action, not FAB) since the
   PR #7-era plan; account for that when restyling Library's AppBar.
4. **Player** (Mini Player, Now Playing).
5. **Spotify pipeline, all 4 steps** (Import, Matching, Detailed Review,
   Manual Match, Quick Review, **Destination**) — no branch-lineage
   uncertainty remains; this can proceed once tokens exist and golden
   coverage is backfilled for the newly-added Destination screen and the
   updated Review Sprint exclude/reject/postpone distinction.
6. **Safety-critical Settings surfaces** (backup/restore/recovery/update) —
   pair every visual change here with the specific non-visual fix tracked in
   §16 item 4 (restore's toast-only success/failure presentation, confirmed
   still open on master).

---

## 6. Complete UI-state coverage requirements

Every screen touched in any phase must, on completion, demonstrably handle:
loading, empty, error, warning, offline, disabled, success, partial-progress,
and destructive-confirmation. Baseline §5 lists today's gaps. The new
Destination screen already models most of these states well and can serve as
a reference implementation for other screens in this respect.

---

## 7. Animation, gesture, haptic, and interruption principles

Unchanged from the PR #7-era plan; re-confirmed accurate against master:

- Motion explains continuity; never motion for its own sake, never motion
  that slows high-volume review (Quick Review specifically).
- Every animation must define its interruption behavior (rapid taps, back
  navigation mid-transition, cancellation). The `mounted`-check + busy-flag +
  generation-token pattern proven in the Spotify screens remains the
  app-wide convention to follow, and is now also used by the Destination
  screen's save flow.
- Reduced motion is mandatory for every new animation.
- Haptics confirm meaningful decisions only.

---

## 8. Accessibility requirements

Unchanged from the PR #7-era plan; re-confirmed the underlying gaps are still
present on master (PR #17's hardening was behavior-focused, not
accessibility-focused):

- Every icon-only control gets a `Semantics`/`tooltip` label; every list-row
  widget gets a descriptive label. This now explicitly includes the new
  Destination screen's controls, which were not confirmed to have Semantics
  coverage beyond what shared primitives already provide.
- No control below 48×48dp effective touch target.
- No text-scaling override; verify (don't assume) fixed-size text containers
  don't clip at 130%/200% system scale for every touched screen.
- Contrast: any content drawn over album artwork must keep a
  verified-contrast scrim, replacing ad hoc black-gradient literals with the
  semantic scrim alias from §2.1.

---

## 9. Golden screenshot and regression-test strategy

1. **Close the coverage gap before restyling.** Baseline §7's "zero
   coverage" list (Home, Search, Library, Playlist, Playlist Folder, User
   Songs, Artist, Now Playing, Bottom Navigation shell, Settings, About,
   Equalizer, Time Machine) is unchanged by PR #17 and should be closed
   before those screens are restyled.
2. **The Spotify pipeline and updater already have real golden coverage on
   master** (8 goldens, up from 3 — see baseline §7), including the new
   Destination screen. Extend this pattern rather than starting from
   scratch for Phase 5 (pipeline restyle).
3. **Commit goldens for compared screens for the duration of the overhaul**,
   even though today's convention is CI-artifact-only.
4. **Every phase PR must include:** updated/added widget tests proving
   preserved behavior, a before/after golden pair for each touched screen,
   and an explicit note of which baseline "must-preserve behavior" bullets
   were re-verified — including, for any Review Sprint/Detailed Review work,
   explicit confirmation that accept/reject/exclude/postpone remain four
   distinct, correctly-labeled outcomes.
5. **Dispatch `musify-regression-guard`** on every phase before opening its
   PR, and **`musify-visual-auditor`** after every visual change. Both are
   read-only and now reference `master` as the baseline (see agent-file
   corrections below).

---

## 10. Implementation phases (independently verifiable)

Each phase is a separate branch/PR off `agent/full-visual-overhaul-master`,
gated on the previous phase's acceptance criteria (§15) and on both
subagents reporting clean.

| Phase | Scope | Key files (indicative, confirm exact set at phase start) | Depends on |
|---|---|---|---|
| 1 | Foundation tokens (color/type/spacing/shape/motion extraction/icon decision) | `lib/theme/app_themes.dart`, `lib/theme/app_colors.dart`, new `lib/theme/motion.dart`, `lib/constants/app_constants.dart` | — (lineage already resolved) |
| 2 | Golden/test coverage backfill for Home, Settings, Library, Search, Playlist, Now Playing, Mini Player | `test/screens/*`, `tool/visual_review_test.dart` additions | Phase 1 |
| 3 | Low-risk screens restyle (About, Time Machine, Offline placeholder, Playlist Folder) | `lib/screens/about_page.dart`, `time_machine_page.dart`, `lib/widgets/offline_search_placeholder.dart`, `playlist_folder_page.dart` | Phase 1 |
| 4 | Core shell + Home/Search/Library restyle | `bottom_navigation_page.dart`, `home_page.dart`, `search_page.dart`, `library_page.dart`, `user_songs_page.dart`, `lib/widgets/library_spotify_import_action.dart`, shared widgets (`SongBar`, `PlaylistBar`, `PlaylistCube`, `ArtistBar`) | Phase 2 |
| 5 | Settings + safety-surface visual pass (paired with the restore-toast fix, §16 item 4, reviewed together) | `settings_page.dart`, backup/restore dialogs, `personalized_update_dialog.dart` | Phase 2, explicit sign-off on pairing visual+behavioral changes |
| 6 | Player (Mini Player, Now Playing) | `mini_player.dart`, `now_playing_page.dart`, `lib/widgets/now_playing/*` | Phase 2 |
| 7 | Playlist/Artist detail restyle | `playlist_page.dart`, `artist_page.dart`, `lib/widgets/playlist_page/*` | Phase 4, Phase 6 |
| 8 | Spotify pipeline restyle, all 4 steps (Import → Matching → Review → Destination) | `spotify_import_*`, `spotify_matching_page.dart`, `spotify_match_review_page.dart`, `spotify_manual_match_page.dart`, `spotify_review_sprint_page.dart`, `review_swipe_deck.dart`, `spotify_import_destination_page.dart`, `personalized_ui.dart` | No lineage blocker; regression-guard clean run required, with explicit attention to the accept/reject/exclude/postpone four-way distinction |
| 9 | Cross-cutting a11y pass + dead-widget resolution + final consistency sweep | App-wide, `ShufflePlayButton`/`PlaylistActionButtons` | All prior phases |

---

## 11. Functional preservation contracts

The full contract list lives in `docs/VISUAL_OVERHAUL_BASELINE.md` §2. The
highest-stakes contracts, restated here because they are the ones most likely
to be broken by a "visual-only" change, **updated for master**:

1. Review Sprint/Detailed Review has **four** distinct outcomes: accept
   (matched/manually_matched), reject (`manual_unmatched`, no undo),
   exclude (`excluded`, its own destructive confirmation, tracked in
   `spotifyExcludedImportRows`), and postpone (session-only, not persisted).
   Do not visually collapse reject and exclude.
2. Matching thresholds (auto ≥0.86 + eligibility, review-band ≥0.58) and the
   checkpoint-every-5 + truncate-past-`nextTrackIndex` resume contract,
   including the excluded-count-adjusted usable-attempt denominator for the
   "process all remaining" gate.
3. Re-importing a CSV goes through `SpotifyImportSessionService.saveNewImport`,
   which atomically clears prior match results and excluded rows with
   rollback-on-failure — do not reintroduce ad hoc `box.put`/`delete`
   sequences around this reset.
4. Destination routing never moves unresolved rows; re-validates the import
   session immediately before writing; and is idempotent for repeated
   routing of the same resolved set (dedupe by `ytid`, name+source-match
   reuse for new playlists).
5. Backup byte-for-byte re-verification after save; restore's journaled
   replace→verify→commit→delete-pre-restore sequence; both must remain
   provably safe. The verified in-app update path
   (`personalized_update_service.dart`) must keep validating package/signer/
   hash before install; the separate legacy announcement fetch must never be
   allowed to become an install path.
6. Debug vs production package/label/signer separation, everywhere it is
   surfaced.
7. Router redirect behavior in offline mode; the Library Spotify-import entry
   point (`OfflineAwareLibrarySpotifyImportAction`) must remain
   offline-disabled.
8. Settings toggles continue reading/writing the same `settings_manager.dart`
   keys after any visual restructuring of the Settings screen.

---

## 12. Files likely touched per phase

See the "Key files" column in §10's table. Confirm the exact set via the
actual diff at the start of each phase.

---

## 13. Historical note — PR #4 / PR #7 (no longer a conflict zone)

An earlier version of this plan (PR #19) treated the PR #7 lineage as a live
architectural conflict requiring resolution. That conflict is now resolved
(§0): PR #4 and PR #7 are historical references describing an earlier,
superseded implementation. They remain useful only as historical context for
*why* certain contracts exist (e.g. the data-recovery incident described in
`docs/MASTER_AGENT_HANDOVER.md` §4 that motivated PR #4's hardening). Do not
diff against, rebase onto, or otherwise treat PR #4/#7 branches as an active
target for this workstream. PR #19 itself remains open, untouched, as an
archival checkpoint of the pre-reconciliation audit.

---

## 14. Rollback and before/after comparison strategy

- Every phase is its own branch/PR off `agent/full-visual-overhaul-master`,
  so any phase can be reverted independently via a normal PR revert, provided
  phases don't share uncommitted state.
- Keep committed "before" goldens (§9.3) so every phase PR can show a literal
  image diff, not just a code diff.
- Because this branch is now based directly on `master` with no further
  lineage ambiguity, ordinary `git fetch`/merge-forward of any new `master`
  commits during the overhaul is safe and expected — unlike the PR #7-era
  plan, there is no separate lineage to reconcile later.
- Rollback of a bad visual change should never touch Hive data, backup files,
  or signing/release configuration — if a rollback ever seems to require
  that, stop and treat it as a data-safety incident, not a routine revert.

---

## 15. Acceptance criteria for declaring the overhaul complete

- Every screen/flow in `docs/VISUAL_OVERHAUL_BASELINE.md` §2 has been visited
  by a phase, has committed golden coverage (light+dark, standard+compact),
  and has a passing widget test for each of the 9 states in §6 that applies.
- Zero raw color/font-size/spacing/radius/duration literals remain outside
  the token definitions in §2.
- One consistent icon set per the decision in §2.5.
- `musify-regression-guard` reports zero open "lost capabilities" or "changed
  contracts" findings against current `master` for every phase's diff.
- `musify-visual-auditor` reports zero "Blocking" findings and a documented,
  accepted disposition for every "Important" finding.
- `ShufflePlayButton`/`PlaylistActionButtons` are either wired up or removed.
- The adjacent functional defects in §16 have been explicitly triaged.
- `flutter analyze` and `flutter test` pass on the final head; `flutter test
  tool/visual_review_test.dart --update-goldens` runs clean (all 8+ goldens)
  and the resulting goldens are reviewed, not just regenerated.

---

## 16. Adjacent functional defects (out of scope for visual implementation)

**Corrected for master** — several PR #7-era findings are now fixed; one is
narrower than originally described; one remains fully open:

1. **Legacy announcement fetch still points at upstream `gokadzev/Musify`**
   (`lib/services/update_manager.dart:24-25`, `fetchAnnouncementOnly`,
   confirmed live). **Narrower than previously described:** this only
   affects a home-screen announcement string, not the APK update path — the
   actual verified-update mechanism (`personalized_update_service.dart`)
   already correctly targets `topcat432/musify-personalized` and validates
   package/signer/hash. Risk is now "may show an announcement meant for
   upstream Musify users," not "may offer the wrong binary." Still needs
   Daniel's explicit approval before changing, per `AGENTS.md`'s release
   contract stop-rule, but is lower severity than the PR #7-era plan stated.
2. ~~Re-importing does not clear stale `spotifyMatchResults`~~ — **fixed on
   master.** `SpotifyImportSessionService.saveNewImport` now atomically
   resets `spotifyMatchResults` and `spotifyExcludedImportRows` alongside the
   new tracks/metadata, with rollback on failure. No follow-up needed.
3. ~~Manual match save does not update `pendingResolutionCount`~~ —
   **appears fixed on master**; `spotify_manual_match_page.dart:325-327`
   updates the counter. Re-verify with a targeted test during Phase 8 rather
   than assuming, since this was confirmed by code reading, not by running
   the test suite.
4. **Restore success/failure is still reported via a transient toast**, while
   backup success gets a full verified dialog with path+counts —
   **confirmed still open on master**, not fixed by PR #17's hardening
   (which added a pre-restore confirm dialog, but left the post-restore
   outcome as `showToast(result.message)` at `settings_page.dart:1025-1051`).
   `docs/TESTING_DATA_SAFETY.md` requires restore success to be as verifiable
   as backup success. This sits on the boundary between "visual" and
   "functional" — flag it explicitly to Daniel when Phase 5 is scoped rather
   than deciding unilaterally which side of the line it's on.
5. **Settings "Data safety" section is still unreachable while offline**
   (`settings_page.dart:72`, confirmed unchanged), hiding backup/restore/
   recovery entirely offline. Needs product confirmation, not a silent move.
6. **`SpotifyTrackMatchingService.resolveReviewItem`** (older decision
   vocabulary) — not re-verified in this reconciliation pass; re-check
   whether it is still dead code before removing it, since PR #17 touched
   `spotify_track_matching_service.dart` substantially (177 changed lines)
   and may have already addressed or repurposed it.

None of these should be fixed inside a visual-overhaul PR. Each should become
its own `agent/{short-description}` branch with its own explicit scope
statement, per `AGENTS.md`'s branch discipline, once Daniel approves working
on it.
