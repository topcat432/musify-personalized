# Musify Personalized — Visual Overhaul Plan

**Status:** Planning/audit only. No application-source implementation has
started. This plan is stacked on PR #7 (`agent/review-sprint-overhaul`), which
is stacked on PR #4 (`agent/data-recovery-hardening`). Read
`docs/VISUAL_OVERHAUL_BASELINE.md` first.

## 0. Read this first — the branch-lineage conflict

Repository governance (`docs/MASTER_AGENT_HANDOVER.md` §5, `AGENTS.md`
"Ownership and Git discipline") records that **PR #17 was merged into `master`
and that PR #4/#7 were, at that snapshot, considered superseded** ("inspected
only to confirm they contain no unique unmerged work, then closed without
merging. Do not revive or stack them onto current master.").

This was independently re-verified against live repository state while
writing this plan, not taken on faith from the dated handover:

- `gh pr view` confirms PR #4 (`agent/data-recovery-hardening`) is still
  **open/draft** and PR #7 (`agent/review-sprint-overhaul`) is still **open**
  — neither has actually been closed yet, despite the handover's
  recommendation.
- `origin/master` tip (`a7863235`, merge of PR #18) is **not** a descendant of
  this branch's base (`b6fee783`), and vice versa — they are genuinely
  diverged, not superset/subset.
- Diffing `origin/master...HEAD` shows **11 files, 2,846 insertions, 1,276
  deletions** of real divergence in `lib/`, `test/`, and `tool/`. In
  particular, `master` contains a commit titled *"fix: harden review and
  destination flows"* that rewrites `lib/screens/spotify_review_sprint_page.dart`
  (894 changed lines) and `lib/widgets/review_swipe_deck.dart` (152 changed
  lines) relative to what exists on this branch.
- `lib/widgets/personalized_ui.dart` on `master` includes components
  (`PersonalizedReveal`, `personalizedPageRoute`,
  `showPersonalizedDestructiveConfirmation`) that `docs/VISUAL_SYSTEM.md`
  documents as already existing, but that **do not exist on this branch** —
  confirmed absent by direct search.

**Conclusion:** this branch and PR #4/#7 are running on a materially older,
pre-hardening version of exactly the code this overhaul cares most about (the
Review Sprint / swipe-deck / destination flow). The audit in
`VISUAL_OVERHAUL_BASELINE.md` accurately describes *what is on this branch
today*, but a decision is needed before real implementation starts:

- **Option A:** Rebase/re-target this visual-overhaul effort onto current
  `master` (post-PR #17) instead of PR #7, and re-run the regression-guard
  comparison against `master`'s hardened review-sprint implementation.
- **Option B:** Keep building on PR #4/#7 as instructed, and explicitly accept
  that this branch will need to reconcile with `master`'s hardened flow before
  or during merge — i.e., treat PR #17's hardening as a second, later merge
  concern rather than blocking this audit.

This plan does **not** resolve that decision — it is a product/architecture
choice for Daniel, per `AGENTS.md`'s mandatory-stop rule on scope/architecture
ambiguity. Everything below is written so it is useful under either option,
but **Option A vs B must be decided before any implementation phase begins.**

---

## 1. Recommended visual direction

Continue and formalize the direction `docs/VISUAL_SYSTEM.md` already
establishes, rather than inventing a new one: **warm, dark-forward, premium,
cinematic, album-art-driven**, expressed through Material 3 `ColorScheme`
roles (never fixed hex values) so it remains correct across dynamic-color,
light, dark, and pure-black modes. The overhaul's job is to take this from "a
maintenance note plus a few components used only in the Spotify fork" to "a
single enforced system used by every screen in the app," and to extend it
where the existing note is silent (a full type scale, a spacing scale, a
motion-token file, icon-set unification).

This is an explicit, scoped design decision to depart from
`docs/VISUAL_SYSTEM.md`'s framing of itself as "a maintenance guide, not
approval to redesign unrelated product surfaces" — the current task
instructions explicitly authorize a comprehensive overhaul of presentation
app-wide, provided behavior is preserved. Record this as a new entry in
`docs/DECISIONS.md` (`D-011`) once Daniel confirms scope, since it changes the
applicability of an existing accepted decision (D-010).

---

## 2. Systems

### 2.1 Color

- Keep `ColorScheme.fromSeed`/dynamic-color as the source of truth; do not
  introduce a fixed brand palette.
- Add a small semantic-alias layer (e.g. `AppSemanticColors` extension on
  `ColorScheme` or a `ThemeExtension`) for the handful of meanings that are
  currently expressed as raw `Colors.black`/`Colors.white` + alpha: card
  overlay scrim, destructive/warning surfaces, success surfaces. Every
  existing raw-color call site cited in the baseline (§4) should resolve to
  one of these aliases.
- Pure-black mode's 4 surface overrides stay as-is; extend the same override
  pattern to any new semantic alias so pure-black remains correct.

### 2.2 Typography

- Define a real `TextTheme` in `getAppTheme` instead of leaving Material's
  defaults in place, keeping `paytoneOne` for the app-bar/brand moments per
  existing convention, and using the theme's `TextTheme` everywhere else.
- Formalize the scale `docs/VISUAL_SYSTEM.md` already describes qualitatively
  (hero/heading/section/body/eyebrow/metric roles) into actual `TextTheme`
  entries so screens stop hand-rolling `TextStyle(fontSize: …)`.
- Require every new/touched screen to use `Theme.of(context).textTheme.*`,
  never a literal `fontSize`.

### 2.3 Spacing

- Introduce a small spacing scale (e.g. 4/8/12/16/20/24/32) as named
  constants in `lib/constants/app_constants.dart`, replacing the ~25 ad hoc
  `EdgeInsets` literals identified in the baseline. Keep the existing
  `commonSingleChildScrollViewPadding` etc. as the outermost page-level
  constants and build the rest of the scale underneath them.

### 2.4 Shape & elevation

- Keep the existing theme-level values (card 16, input 12, dialog 28,
  popup/snackbar 12) as the canonical shape scale and retire the ~17 stray
  radii found in widgets by mapping each to the nearest canonical value
  (or documenting a deliberate exception, e.g. pill-shaped chips at 999).
- Elevation stays flat (0) by convention; keep using `BoxShadow` for the few
  intentionally-elevated surfaces (mini-player, artwork, sprint cards) but
  centralize the shadow definition instead of repeating `Colors.black.withValues(...)`
  inline.

### 2.5 Icons

- Decide and document one rule: either (a) migrate the Spotify/personalized
  fork to Fluent icons to match the core app, or (b) formally adopt Material
  icons for all "personalized" surfaces as an intentional visual sub-brand and
  migrate the few stray Material icons out of core screens the other
  direction. Do not leave the current unlabeled 50/50 split. Recommendation:
  (a), since the core app (and any future non-Spotify screens) are Fluent-first
  and a single icon language reads as more premium/coherent.

### 2.6 Motion

- Create a small `lib/theme/motion.dart` (or extend `app_themes.dart`) with
  named `Duration`/`Curve` constants seeded from the values
  `docs/VISUAL_SYSTEM.md` already specifies (220 ms surface, 240 ms metric,
  320/240 ms page enter/exit, 360 ms reveal, ~220-260 ms review-deck
  commit/recovery), and migrate the ~15 files with literal duration values
  onto these constants.
- Require every new animation to use `MediaQuery.disableAnimations` for a
  reduced-motion path, matching the existing `PersonalizedReveal`-style
  convention (once that component is available on whichever branch lineage is
  chosen per §0).
- Haptics: extend the `HapticFeedback` pattern currently isolated to the
  review swipe deck to other meaningful confirmations (destructive deletes,
  successful backup/restore) — lightly, per `docs/VISUAL_SYSTEM.md`'s "confirm
  meaningful decisions, not every minor tap."

---

## 3. Shared component architecture

- Promote the `personalized_ui.dart` primitives (`PersonalizedHero`,
  `PersonalizedSurface`, `PersonalizedSectionHeading`, `PersonalizedStatusBanner`,
  `PersonalizedMetric`, `PersonalizedEmptyState`, and — once available per §0 —
  `PersonalizedReveal`/`personalizedPageRoute`/`showPersonalizedDestructiveConfirmation`)
  from "Spotify-flow-only" to app-wide shared primitives, renaming away from
  the `Personalized*` prefix only if Daniel wants that (functionally it is
  already a general design-system layer).
- Consolidate the currently-separate `EmptyPlaylistState` /
  `PersonalizedEmptyState` / ad hoc empty-state code into one configurable
  empty-state component used everywhere.
- Give `ConfirmationDialog` a single "destructive" and "neutral" preset that
  every call site uses, instead of some screens building their own confirm UI
  inline.
- Resolve `ShufflePlayButton`/`PlaylistActionButtons` (baseline §3) as part of
  the playlist-page component pass — either wire them into `playlist_page.dart`
  or delete them; do not carry dead components into the new architecture.

---

## 4. Navigation and information-architecture improvements

- No route/IA changes are required to achieve the visual goals; this overhaul
  is presentation-first. The one structural note worth a product decision:
  Artist currently has no dedicated screen (it reuses `PlaylistPage`), which
  works but limits artist-specific content (bio, top tracks module, etc.) —
  out of scope unless Daniel wants it pulled in.
- Standardize transition timing: currently tab-root fades are 180 ms and
  nested pushes are 220 ms fade+slide (`router_service.dart`), while the mini
  → full player transition is a separate 250 ms slide-up
  (`mini_player.dart`). Fold all three into the motion tokens in §2.6 so they
  read as one coherent system rather than three independently-tuned values.

---

## 5. Screen-by-screen overhaul scope

Use `docs/VISUAL_OVERHAUL_BASELINE.md` §2 as the authoritative per-screen
table (source files, entry point, must-preserve behavior, risk). This section
only adds *sequencing intent*:

1. **Foundation first** (tokens, no screen-visible change yet): color aliases,
   typography scale, spacing scale, motion tokens, icon-set decision.
2. **Low-risk screens** (§2.1 Low/Medium rows: About, License-adjacent chrome,
   Time Machine, Offline placeholder, Playlist Folder) — prove the new tokens
   end-to-end with minimal behavioral surface area.
3. **Core navigation shell + Home/Search/Library/Settings** — highest visible
   impact, medium-high risk, needs full state-coverage + golden baseline
   before touching.
4. **Player** (Mini Player, Now Playing) — critical risk, do only after the
   token system is proven and golden coverage exists for both.
5. **Spotify pipeline** (Import, Matching, Detailed Review, Manual Match,
   Review Sprint) — critical risk, gated on the branch-lineage decision in §0
   and on the regression-guard subagent clearing every contract in
   `docs/VISUAL_OVERHAUL_BASELINE.md` §2.3.
6. **Safety-critical Settings surfaces** (backup/restore/recovery/update) —
   pair every visual change here with the specific non-visual fixes tracked in
   §16, reviewed together since the UI and the safety guarantee are tightly
   linked (e.g. fixing "restore success is a toast" is a visual+behavioral
   change that must go through the regression guard, not just the visual
   auditor).

---

## 6. Complete UI-state coverage requirements

Every screen touched in any phase must, on completion, demonstrably handle:
loading, empty, error, warning, offline, disabled, success, partial-progress,
and destructive-confirmation — matching `docs/VISUAL_SYSTEM.md`'s existing
acceptance checklist. Baseline §5 lists today's gaps per screen; each phase's
acceptance criteria (§15) must show the gap closed for the screens in that
phase, not just restyled.

---

## 7. Animation, gesture, haptic, and interruption principles

- Motion explains continuity (a card follows the finger, the next card is
  revealed, values change in place) — never motion for its own sake, and never
  motion that slows high-volume review (Quick Review specifically).
- Every animation must define its interruption behavior: rapid taps, back
  navigation mid-transition, and cancellation must not leave the UI in a
  half-animated or duplicated state. Use the existing `mounted`-check +
  busy-flag + generation-token patterns already proven in the Spotify screens
  as the app-wide convention.
- Reduced motion is mandatory, not optional, for every new animation
  (`MediaQuery.disableAnimations`).
- Haptics confirm meaningful decisions only (swipe commit, destructive
  confirm, verified backup/restore success) — never routine taps.

---

## 8. Accessibility requirements

- Every icon-only control gets a `Semantics`/`tooltip` label; every list-row
  widget (`SongBar`, `PlaylistBar`, `ArtistBar`, `PlaylistCube`) gets a
  descriptive `Semantics` label including at minimum name + type + primary
  state (e.g. "downloaded", "playing").
  - Add a lint/test convention (widget test that walks the tree checking for
    unlabeled `IconButton`/`GestureDetector` in touched screens) so this
    doesn't regress silently.
- No control below 48×48dp effective touch target; audit every
  `VisualDensity.compact` usage identified in the baseline (§6) and either
  justify or remove it.
- No text-scaling override; verify (don't just assume) that fixed-size text
  containers don't clip at 130%/200% system scale for every touched screen —
  add this to the phase acceptance criteria.
- Contrast: any content drawn over album artwork (mini-player, now-playing,
  review-sprint cards) must keep a verified-contrast scrim, replacing the
  current ad hoc black-gradient literals with the semantic scrim alias from
  §2.1.

---

## 9. Golden screenshot and regression-test strategy

1. **Close the coverage gap before restyling.** For every screen in
   `docs/VISUAL_OVERHAUL_BASELINE.md` §7's "zero coverage" list that a phase
   touches, add a widget test and a golden (light + dark, standard + compact
   viewport, matching the existing `tool/visual_review_test.dart` pattern)
   *before* changing its visual code, so the golden captures the true "before."
2. **Commit goldens for compared screens for the duration of the overhaul**,
   even though today's convention is CI-artifact-only; an overhaul needs a
   stable committed baseline to diff against across many PRs. Revisit whether
   to keep them committed long-term once the overhaul lands.
3. **Every phase PR must include:** updated/added widget tests proving
   preserved behavior (not just updated goldens), a before/after golden pair
   for each touched screen, and an explicit note of which
   `docs/VISUAL_OVERHAUL_BASELINE.md` "must-preserve behavior" bullets were
   re-verified.
4. **Dispatch `musify-regression-guard`** (read-only subagent,
   `.cursor/agents/musify-regression-guard.md`) on every phase before opening
   its PR, and **`musify-visual-auditor`**
   (`.cursor/agents/musify-visual-auditor.md`) after every visual change.
   Neither may edit files; both report findings back to the human writer.
5. Add the two missing widget/golden suites the baseline flags as highest-
   need first: Home and Settings (highest traffic + highest risk,
   respectively).

---

## 10. Implementation phases (independently verifiable)

Each phase is a separate branch/PR off this one, gated on the previous
phase's acceptance criteria (§15) and on both subagents reporting clean.

| Phase | Scope | Key files (indicative, confirm exact set at phase start) | Depends on |
|---|---|---|---|
| 0 | Resolve §0 branch-lineage decision | — (decision only) | Daniel |
| 1 | Foundation tokens (color/type/spacing/shape/motion/icon decision) | `lib/theme/app_themes.dart`, `lib/theme/app_colors.dart`, new `lib/theme/motion.dart` (or extension), `lib/constants/app_constants.dart` | Phase 0 |
| 2 | Golden/test coverage backfill for Home, Settings, Library, Search, Playlist, Now Playing, Mini Player | `test/screens/*`, `tool/visual_review_test.dart` additions | Phase 1 (tokens must exist so goldens capture the real target state, not a moving target) |
| 3 | Low-risk screens restyle (About, Time Machine, Offline placeholder, Playlist Folder) | `lib/screens/about_page.dart`, `time_machine_page.dart`, `lib/widgets/offline_search_placeholder.dart`, `playlist_folder_page.dart` | Phase 1 |
| 4 | Core shell + Home/Search/Library restyle | `bottom_navigation_page.dart`, `home_page.dart`, `search_page.dart`, `library_page.dart`, `user_songs_page.dart`, shared widgets (`SongBar`, `PlaylistBar`, `PlaylistCube`, `ArtistBar`) | Phase 2 |
| 5 | Settings + safety-surface visual pass (paired with §16 non-visual fixes, reviewed together) | `settings_page.dart`, backup/restore dialogs, update dialogs | Phase 2, explicit sign-off on pairing visual+behavioral changes |
| 6 | Player (Mini Player, Now Playing) | `mini_player.dart`, `now_playing_page.dart`, `lib/widgets/now_playing/*` | Phase 2 |
| 7 | Playlist/Artist detail restyle | `playlist_page.dart`, `artist_page.dart`, `lib/widgets/playlist_page/*` | Phase 4, Phase 6 (shares artwork/shadow tokens) |
| 8 | Spotify pipeline restyle (Import → Matching → Review → Manual Match → Quick Review) | `spotify_import_*`, `spotify_matching_page.dart`, `spotify_match_review_page.dart`, `spotify_manual_match_page.dart`, `spotify_review_sprint_page.dart`, `review_swipe_deck.dart`, `personalized_ui.dart` | Phase 0 decision resolved; regression-guard clean run required before merge |
| 9 | Cross-cutting a11y pass + dead-widget resolution + final consistency sweep | App-wide, `ShufflePlayButton`/`PlaylistActionButtons` | All prior phases |

---

## 11. Functional preservation contracts

The full contract list lives in `docs/VISUAL_OVERHAUL_BASELINE.md` §2 (one row
per screen/flow, "must-preserve behavior" column) and is the operative
checklist for the regression guard. The highest-stakes contracts, restated
here because they are the ones most likely to be broken by a "visual-only"
change:

1. Review Sprint swipe semantics: right=accept, left=reject=permanent
   `manual_unmatched` (no undo), up=postpone=session-only (not persisted).
2. Matching thresholds (auto ≥0.86 + eligibility, review-band ≥0.58) and the
   checkpoint-every-5 + truncate-past-`nextTrackIndex` resume contract.
3. Backup byte-for-byte re-verification after save; restore's journaled
   replace→verify→commit→delete-pre-restore sequence; both must remain
   provably safe, not just visually reassuring.
4. Debug vs production package/label/signer separation, everywhere it is
   surfaced (banner, backup manifest tagging, release workflow gates).
5. Router redirect behavior in offline mode (Search/Time Machine/undownloaded
   artist → Home).
6. Settings toggles continue reading/writing the same `settings_manager.dart`
   keys after any visual restructuring of the Settings screen.

---

## 12. Files likely touched per phase

See the "Key files" column in §10's table. Treat it as indicative — confirm
the exact set via the actual diff at the start of each phase, since shared
widgets (especially `SongBar`, `PlaylistBar`, artwork/shadow helpers) will be
touched by more than one phase.

---

## 13. Conflict zones inherited from PR #4 and PR #7

1. **Branch lineage** (see §0) — the single largest conflict. This branch's
   Review Sprint / swipe-deck / destination-flow code is materially older than
   what already exists on `master` via PR #17's "harden review and destination
   flows" work. Any phase-8 implementation must account for this before or
   during merge.
2. **`personalized_ui.dart` divergence** — `master` has at least 3 more shared
   primitives than this branch. Re-check the full symbol diff before phase 1/8
   implementation so the new token system is built against the actual final
   component set, not a stale one.
3. **PR #4/#7 open-PR status** — both are still open on GitHub despite
   governance recommending they be closed (unmerged) as superseded. Do not
   close, merge, or modify either PR from this workstream; that decision
   belongs to Daniel and is out of scope here.
4. **Documentation drift** — `docs/VISUAL_SYSTEM.md` references components and
   values that partially don't exist on this branch (§0). Treat the doc as
   aspirational/target-state for the token system in §2, and reconcile it with
   whichever branch lineage is chosen.

---

## 14. Rollback and before/after comparison strategy

- Every phase is its own branch/PR off `agent/full-visual-overhaul`, so any
  phase can be reverted independently via a normal PR revert without affecting
  earlier or later phases, provided phases don't share uncommitted state.
- Keep committed "before" goldens (per §9.2) so every phase PR can show a
  literal image diff, not just a code diff.
- Because this branch's base itself may need to be reconciled with `master`
  (§0/§13), avoid rebasing this branch onto a moving target mid-phase; pick
  the lineage once (Phase 0) and hold it for the duration of the overhaul,
  reconciling with any further upstream changes as a deliberate, reviewed step
  rather than an incidental rebase.
- Rollback of a bad visual change should never touch Hive data, backup files,
  or signing/release configuration — if a rollback ever seems to require that,
  stop and treat it as a data-safety incident, not a routine revert.

---

## 15. Acceptance criteria for declaring the overhaul complete

- Every screen/flow in `docs/VISUAL_OVERHAUL_BASELINE.md` §2 has been visited
  by a phase, has committed golden coverage (light+dark, standard+compact),
  and has a passing widget test for each of the 9 states in §6 that applies to
  it.
- Zero raw color/font-size/spacing/radius/duration literals remain outside the
  token definitions in §2 (spot-checked, not necessarily zero via exhaustive
  grep, but the systemic pattern from the baseline is gone).
- One consistent icon set per the decision in §2.5.
- `musify-regression-guard` reports zero open "lost capabilities" or "changed
  contracts" findings against the chosen baseline lineage (§0) for every
  phase's diff.
- `musify-visual-auditor` reports zero "Blocking" findings and a documented,
  accepted disposition for every "Important" finding.
- `ShufflePlayButton`/`PlaylistActionButtons` are either wired up or removed.
- The adjacent functional defects in §16 have been explicitly triaged
  (fixed-as-separate-work, deferred-with-reason, or accepted-as-is) — not
  silently carried forward.
- `flutter analyze` and `flutter test` pass on the final head; `flutter test
  tool/visual_review_test.dart --update-goldens` runs clean and the resulting
  goldens are reviewed, not just regenerated.

---

## 16. Adjacent functional defects (out of scope for visual implementation)

These were found during the audit and must **not** be fixed as a side effect
of a visual change. Track them as separately scoped, separately reviewed
follow-up work, each requiring its own explicit approval before touching
behavior:

1. **Update-checker URLs point at upstream `gokadzev/Musify`**, not this fork
   (`lib/services/update_manager.dart:39,41` —
   `raw.githubusercontent.com/gokadzev/Musify/update/check.json` and
   `api.github.com/repos/gokadzev/Musify/releases/latest`). Confirmed live in
   code. `docs/RELEASE_STATE.md` independently flags the related
   `pubspec.yaml` homepage/repository/issue-tracker fields pointing at the
   same upstream. Risk: could offer the wrong app/binary to this fork's users.
   Needs Daniel's explicit approval before changing, per `AGENTS.md`'s release
   contract stop-rule.
2. **Re-importing a Spotify CSV does not clear stale `spotifyMatchResults`**
   from a previous import (`spotify_import_page.dart` save path resets
   `matchingStatus`/`nextTrackIndex` but not prior match results) — possible
   stale-data contract violation of `docs/DECISIONS.md` D-004/D-005.
3. **Manual match save does not update `pendingResolutionCount`**
   (`spotify_manual_match_page.dart`), causing a metadata counter to drift
   until the next matching/workflow checkpoint recomputes it.
4. **Restore success is reported via a transient toast**, while backup success
   gets a full verified dialog with path+counts — an asymmetry that is partly
   visual and partly a safety-communication gap (`docs/TESTING_DATA_SAFETY.md`
   requires restore success to be as verifiable as backup success). This one
   sits on the boundary between "visual" and "functional" — flag it explicitly
   to Daniel when phase 5 is scoped, rather than deciding unilaterally which
   side of the line it's on.
5. **Settings "Data safety" section is unreachable while offline**
   (`settings_page.dart:72`), hiding backup/restore/recovery entirely offline.
   Likely an accidental consequence of nesting it under
   `_buildOnlineFeaturesSection` rather than an intentional safety gate — needs
   product confirmation, not a silent move.
6. **`SpotifyTrackMatchingService.resolveReviewItem`** still exists with an
   older decision vocabulary (`accepted`/`no_correct_match`) that the current
   UI no longer calls into (`SpotifyReviewWorkflowService` is used instead) —
   dead/legacy code path worth removing once confirmed truly unreachable.

None of these should be fixed inside a visual-overhaul PR. Each should become
its own `agent/{short-description}` branch with its own explicit scope
statement, per `AGENTS.md`'s branch discipline, once Daniel approves working on
it.
