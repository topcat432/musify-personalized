# Musify Personalized — Master Agent Handover

> **Purpose:** Give any new coding agent or LLM enough product, safety, architectural, release, and project-history context to contribute without repeating past mistakes.
>
> **Snapshot:** 2026-07-14, America/Chicago. GitHub timestamps may appear as 2026-07-15 UTC.
>
> **Repository:** `https://github.com/topcat432/musify-personalized`
>
> **Owner:** Daniel / GitHub `topcat432`
>
> **License:** GPLv3, public repository

---

## 0. Read this first

Musify Personalized is a Flutter fork of Musify being turned into a private-feeling, local-first music system for one primary user. It is not merely a reskin. The work combines:

- safe preservation of a real personal music library;
- Spotify/export-file ingestion;
- YouTube Music/YouTube-backed recording matching;
- fast human review of uncertain matches;
- explicit routing into Liked Songs or playlists;
- verified Android production updates;
- premium, coherent mobile UI and motion;
- a longer-term taste model, DJ, smart-playlist, source-quality, and offline roadmap.

### Phase recorded at this snapshot

**PR #17 was recorded as reviewed, cleared, and merged into `master`. At this snapshot, the next identified operational task was to verify whether a signed production release existed and, only with Daniel's explicit approval, produce and phone-test one if needed.**

Known merged `master` commit at this snapshot:

```text
27256cedefd915e905d7478107104cebdbbecebc
```

That SHA is a historical snapshot, not a permanent release instruction. Before any build, fetch GitHub and use the current full 40-character `master` tip. The signed workflow deliberately rejects stale candidates.

### Source-of-truth warning

Do not inherit a random browser-session checkout or old feature branch. In the browser workspace used to prepare this handover, `pr17-work` was detached at `f6e0cbf...` with many uncommitted changes. It is stale and is **not** authoritative.

Start with a fresh clone or a clean worktree based on the verified current remote `master`. Never reset a dirty worktree or copy old workspace changes over the merged tree without proving they are still needed.

The recovery, testing, signing, and update documents referenced below contain conditional or historical procedures. They remain safety constraints, but they are not proof of current phone state or standing authorization to perform those procedures.

### Trust labels used in this document

- **Merged:** present in remote `master`.
- **CI-verified:** covered by automated checks on the exact reviewed commit.
- **Phone-verified:** Daniel personally exercised it on the real device.
- **Unverified:** code may exist and tests may pass, but the real-device outcome is not yet proven.

Compilation is not proof of data safety. A green widget test is not proof that Android Storage Access Framework behavior works on Daniel's phone. Never collapse these trust levels into “done.”

---

## 1. Product identity and comprehensive end goal

The product goal is a polished personal music system that lets Daniel own the organization, matching, playback choices, and portability of his library without requiring Spotify Premium or surrendering the library to a cloud service.

The end state should provide:

1. A durable canonical music library with stable song identities.
2. Multiple possible sources for a recording, with clear source-quality and version information.
3. Reliable Liked Songs and playlist membership that survive upgrades, imports, restarts, and backups.
4. Import from flat CSV, playlist-aware ZIP/JSON/CSV/TSV exports, and eventually optional direct Spotify authorization.
5. Spotify playlist-to-Musify playlist and song-to-song transfer, including choosing all tracks, an exact count, or a selected subset.
6. A permanent unresolved/unmatched library that can be revisited at any time without rerunning thousands of already-finished songs.
7. Manual, unrestricted YouTube Music-like search plus exact YouTube/YouTube Music URL hints. A pasted link identifies a candidate; it must still become a normal Musify song object rather than a permanently hard-coded web link.
8. Fast swipe-based review with playable previews, artwork, prefetching, reversible decisions where appropriate, and explicit permanent exclusion for non-song material.
9. A local taste model, context-aware smart playlists, an intentional DJ, smart queues, Late Night/Gym/Driving modes, and AutoMix.
10. Honest source-quality controls, including preference for original studio recordings, explicit versions where intended, trustworthy uploads, and eventually personal/local lossless sources.
11. A cinematic, colorful, album-driven interface with premium typography, spacing, motion, haptics, loading states, and reduced-motion support.
12. Offline use, Android Auto, a “Music Atlas” exploration layer, and portable user-owned data.

This is a single-user, local-first product. Avoid SaaS assumptions, social graphs, engagement tricks, ads, or artificial account requirements unless the owner explicitly changes direction.

---

## 2. Owner preferences and communication contract

### Product preferences

- Prefer accuracy, automation, and honest status over flashy claims.
- Preserve data first. Never trade library safety for implementation speed.
- Keep Spotify import usable without Spotify Premium.
- The direct Spotify path may be added later, but must remain optional.
- Avoid Aqua, space, Orbit, or similarly unrelated branding.
- Maintain the current warm, dark, premium visual direction established by the personalized import/review work.
- New screens must look native to the redesigned app, not like developer tools bolted onto it.
- Animation matters: elements should transition, expand, dismiss, load, and confirm with polish rather than simply popping in and out.
- Do not allow floating actions to overlap the mini-player, content cards, bottom navigation, or system insets.

### Communication preferences

- Lead with the outcome and the next decision.
- Use plain language. Explain GitHub/Android steps literally when manual action is required.
- State what is verified, what is inferred, and what remains unknown.
- Do not make Daniel repeat work because an agent failed to inspect existing state.
- Before a long implementation, summarize the plan and wait for approval when Daniel asks to approve the plan first.
- Do not burn usage by repeatedly polling a review bot. Check only when asked or on a sensible interval, and report the last known state.

---

## 3. Non-negotiable safety and security rules

These rules override convenience and velocity.

### Never instruct Daniel to do these casually

- Do not uninstall either Musify app as a troubleshooting step.
- Do not clear app storage or app data.
- Do not rerun the completed 2,643-track match merely to reopen unresolved items.
- Do not replace or overwrite the real library with a test dataset.
- Do not claim backup success because a file picker closed or a toast appeared.
- Do not claim restore success until semantic contents and post-restart state are verified.

If a destructive operation ever becomes genuinely necessary, stop and explain the exact data at risk, the verified recovery path, and why no non-destructive alternative works.

### Secrets

GitHub repository Actions secrets are configured with these names:

```text
MUSIFY_SIGNING_KEY_BASE64
MUSIFY_SIGNING_PASSWORD
```

The expected signing alias is:

```text
musify-personalized
```

Never print, log, commit, re-encode in public output, or request the secret values. Secret names and alias are configuration metadata; values are confidential.

### Public-repository hygiene

Never commit:

- Daniel's Spotify CSV/ZIP/JSON exports;
- real search or playback history;
- Hive database files from the device;
- backup archives containing personal data;
- signing material or passwords;
- tokens, Client IDs intended to remain private, or device diagnostics containing personal paths/data.

Use synthetic fixtures in tests.

---

## 4. Historical incident that explains the safety posture

The original personalized work created two Android application identities:

```text
Production: com.topcat432.musifypersonalized
Debug:      com.topcat432.musifypersonalized.debug
```

Android isolates their storage. The debug app held the first major Spotify-import matching run while production appeared empty. That run contained:

| Result | Count |
|---|---:|
| Imported tracks | 2,643 |
| Strong matches | 2,128 |
| Review | 353 |
| Unmatched | 162 |

Early builds also made several unsafe or confusing choices:

- debug and production were not visually distinct enough;
- a data export did not reliably transfer the actual personalized data;
- file picking accepted arbitrary inputs and could report “data imported” without sufficient format/semantic validation;
- backup creation could show success or failure based on filename behavior rather than verified data;
- the first backup implementation made large in-memory/Base64 copies and later failed on-device with `Out of Memory`;
- manually downloaded GitHub artifacts were sometimes unsigned, incorrectly signed, stale, or otherwise rejected by Android as an invalid package.

Daniel ultimately chose the safer reset-and-reimport route rather than risky ADB/database surgery. The full match was completed again in production and the accepted songs were moved into Liked Songs.

### Current real-user data state known from Daniel

- Matching completed in the production app.
- Songs were successfully moved to Liked Songs.
- A screenshot showed 2,454 songs in Liked Songs.
- Five unwanted voice-over items remained in the detailed review queue.
- A permanent-exclusion action for such items was implemented and merged.

Do not assume the latest merged exclusion build is already installed unless Daniel confirms it. Do not reinterpret the difference between 2,643 imported rows and 2,454 liked songs without inspecting the routing, duplicate, exclusion, and unresolved audit data.

The debug app/data may still exist as a fallback. Do not delete it.

---

## 5. GitHub state recorded at the snapshot

### Merged work

PR #17 is the consolidation PR for the current feature stack:

```text
PR:          #17
Head:        ee62c84075429a0ca7b715fafb65ca6446250806
Merge/master snapshot:
             27256cedefd915e905d7478107104cebdbbecebc
Review:      44 threads resolved
Latest Codex exact-head review:
             "Didn't find any major issues."
Scale:       96 commits, 77 files, +15,840 / -906
```

Exact-head CI run `29383734944` passed:

- Flutter analyzer;
- full unit/widget test suite;
- visual screenshot rendering;
- debug APK build and identity checks;
- F-Droid permission-boundary checks;
- unsigned release APK build.

PR #16, “Add verified in-app production updater,” is merged and is included in the PR #17 stack.

The signed release gate work is merged. Legacy release/pre-release paths were removed or guarded so they cannot masquerade as the permanent production build path.

### Open PR cleanup

PRs #4 and #7 were still open at the snapshot but are superseded by PR #17. They should be inspected only to confirm they contain no unique unmerged work, then **closed without merging**. Do not revive or stack them onto current `master`.

There were no open issues at the snapshot.

### Release status

The merged stack had **not yet been confirmed as published through the signed production workflow** when this handover was prepared.

The next agent must inspect GitHub Actions and Releases before claiming otherwise.

---

## 6. What the merged product stack contains

### Import and matching

- Spotify CSV ingestion with Soundiiz/Exportify-oriented parsing.
- Import-session persistence and transactional reset/rollback behavior.
- Catalog-first matching using structured YouTube Music results.
- Ordinary YouTube fallback.
- Scoring across title, primary/featured artists, album, duration, version terms, long-form/live/karaoke traits, and source reliability.
- Strong/review/unmatched/error state handling.
- Pause/cancel/resume and checkpoint behavior.
- Protection against stale sessions and stale routing snapshots.
- Reliable-source requirements for automatic acceptance; untrusted fallbacks require review.
- Preservation of structured candidates if a fallback request fails.

### Manual resolution and Quick Review

- A permanent unmatched/review workspace.
- Fast swipe-card review inspired by TikTok/Tinder interaction patterns.
- Card drag/rotation, next-card reveal, motion, and haptic feedback.
- Playable candidate previews.
- Prefetch and artwork caching.
- Detailed comparison mode.
- Manual search.
- YouTube/YouTube Music link parsing and exact-candidate hinting.
- Permanent exclusion for voice-overs, commentary, unavailable items, or tracks Daniel intentionally does not want.
- Rescue/retry flows that do not require replaying already-resolved tracks.

“No match” and “permanently remove” are not interchangeable. A temporary unresolved item must remain recoverable; an explicit permanent exclusion must be audited and kept out of future review/import routing unless deliberately restored.

### Destination routing

- Route imported/matched tracks to Liked Songs.
- Route to an existing custom playlist.
- Create a new playlist from an import.
- Choose all tracks, an exact count, or a selected subset where supported by the flow.
- Duplicate preview/idempotency protections.
- Routing history and stale-snapshot checks.
- A compact Library “Spotify Import” entry that avoids overlapping the current music card/mini-player.

Flat-file playlist routing is substantially present. Playlist-aware ZIP/JSON multi-playlist sync and optional direct Spotify connection remain roadmap work.

### Backup and restore

- Dedicated `.musifybackup` extension.
- Schema and checksum validation.
- Semantic counts and required-database validation.
- Streaming archive creation/restore to avoid giant Base64/in-memory copies.
- Tamper rejection, rollback, and interrupted-startup recovery logic.
- Exclusion/import state preservation in automated tests.

Important: the old on-device build failed backup creation with `Out of Memory`. The merged streaming implementation is CI-verified, but real-phone backup creation and independent restore verification are still required. Daniel previously said loading from backup appeared to work and asked not to block current feature work on further questioning. Record that as an observation, not proof.

### Production update delivery

- A signed-release-only user-facing path.
- In-app update discovery and download UI.
- Manifest/schema validation.
- Package-name, version, signer-hash, APK-hash, and release-URL verification.
- Cancellable downloads.
- Protection against installing debug/F-Droid/foreign-signed artifacts as production updates.

The updater can only be proven end-to-end after at least one valid signed production release is installed and a newer valid signed release is available.

### Visual system

- Warm dark palette and peach/copper accent direction.
- Large, expressive headings and rounded layered cards.
- Import hub, matching, review, destination, dialog, and updater visual passes.
- Compact-layout and dark-layout golden coverage for important personalized screens.
- Reduced-motion-aware behavior.
- Intentional motion added to swipe/review and recent flows.

Continue tightening typography, spacing, button hierarchy, empty/loading/error states, animation continuity, and mini-player/system-inset behavior. Every new feature should receive a visual consistency pass before release.

---

## 7. Technical architecture

### Core stack

```text
Flutter: 3.44.5
Dart:    >=3.12.0 <4.0.0
State/data: Hive
Audio: audio_service, just_audio
Navigation: go_router
File access: file_picker / Android Storage Access Framework
Catalog/search: local youtube_music_explode_dart and youtube_explode_dart packages
Android: minSdk 24, targetSdk 36, Java 17
```

### Important screens

```text
lib/screens/spotify_import_page.dart
lib/screens/spotify_import_hub_page.dart
lib/screens/spotify_matching_page.dart
lib/screens/spotify_match_review_page.dart
lib/screens/spotify_manual_match_page.dart
lib/screens/spotify_review_sprint_page.dart
lib/screens/spotify_import_destination_page.dart
lib/screens/library_page.dart
lib/screens/settings_page.dart
```

### Important services

```text
lib/services/spotify_csv_importer.dart
lib/services/spotify_import_session_service.dart
lib/services/spotify_track_matching_service.dart
lib/services/spotify_match_scoring.dart
lib/services/spotify_review_workflow_service.dart
lib/services/spotify_manual_source_service.dart
lib/services/spotify_import_destination_service.dart
lib/services/musify_backup_service.dart
lib/services/personalized_update_service.dart
lib/services/review_sprint_audio_player.dart
lib/services/review_sprint_prefetch_cache.dart
```

### Important personalized UI

```text
lib/widgets/personalized_ui.dart
lib/widgets/review_swipe_deck.dart
lib/widgets/library_spotify_import_action.dart
lib/widgets/personalized_update_dialog.dart
```

### Hive storage

Primary boxes opened by the app include:

```text
settings
user
userNoBackup
cache
```

Important keys in the `user` data domain include:

```text
spotifyImportTracks
spotifyImportMetadata
spotifyMatchResults
spotifyExcludedImportRows
likedSongs
customPlaylists
playlistFolders
```

Treat these as durable user state. Any schema change needs forward migration, rollback/failure behavior, and tests against partial or older data.

`spotify_import_session_service.dart` resets import-session keys as a transaction and restores the previous import if writing the replacement fails. Do not bypass that contract with ad hoc `box.put`/`delete` sequences.

---

## 8. Import/matching domain rules

The approved conceptual pipeline is:

```text
Read source + playlist membership
    -> identify/match a unique recording
    -> retain every unresolved row
    -> let the user resolve or exclude it
    -> route an explicit subset to an explicit destination
    -> record an audit result
```

### Required invariants

1. Importing does not silently mutate Liked Songs before finalization.
2. Unresolved rows are never discarded merely because the current search found nothing.
3. A retry resumes from saved state; it does not redo thousands of successful results.
4. Manual URL input is a candidate lookup hint, not a raw URL masquerading as a durable song.
5. Source reliability affects whether a result may be automatically accepted.
6. User-selected alternatives must survive review and routing.
7. Routing occurs only after the destination write succeeds.
8. Repeating an import/routing operation must not create uncontrolled duplicates.
9. Playlist membership from a playlist-aware export must remain attached to source rows through matching.
10. Exclusion is explicit, durable, auditable, and reversible only through a deliberate management action.
11. Errors, unmatched, review, excluded, accepted, and routed are distinct states.
12. Stale UI snapshots must not overwrite newer decisions.

### Spotify constraint

Daniel does not want Spotify Premium and is using Musify partly to avoid it. Build the most capable Premium-free path first:

- Spotify account export files;
- Soundiiz/Exportify-style CSV;
- playlist-aware ZIP/JSON/CSV/TSV;
- repeat sync with stable source identifiers;
- clear playlist mapping and deduplication.

An optional Spotify OAuth flow may follow using Authorization Code with PKCE and a user/developer Client ID. Do not promise endpoints or playback access that Spotify limits by account tier or policy. Direct connection must never become a prerequisite for file import.

---

## 9. Android identities, signing, and release delivery

### Application identities

```text
Production package: com.topcat432.musifypersonalized
Debug package:      com.topcat432.musifypersonalized.debug
F-Droid package:    com.gokadzev.musify.fdroid
```

The debug build must have:

- the `.debug` package suffix;
- a visibly distinct icon;
- the label `Musify Personalized DEBUG`;
- no ability to overwrite production storage.

### Workflows

`.github/workflows/debug.yml` runs analyzer/tests/visual checks and builds debug plus unsigned candidates. It is **not** a user-facing production release path.

The only approved production path is:

```text
.github/workflows/signed-release.yml
Workflow name: Build and publish signed production APK
```

The workflow is manually dispatched with:

- the exact, full, lowercase 40-character current `master` SHA;
- release notes.

It:

- verifies the candidate equals the current default-branch tip before building;
- analyzes and tests;
- builds in an isolated production context;
- signs with the permanent key;
- verifies v2/v3 signing;
- verifies package, label, non-debuggable state, signer, and APK hash;
- rechecks the branch tip immediately before publication;
- publishes the APK, checksum, update manifest, and release proof to the latest GitHub Release.

The monotonic version code is based on:

```text
100000000 + GITHUB_RUN_NUMBER
```

Never hand Daniel an unsigned artifact and call it production. Never rename an unsigned file to look signed. The `.sha256` and `release-proof.txt` are supporting artifacts, not installable apps.

The APK Daniel should install is named like:

```text
musify-personalized-production.apk
```

Installation must occur over the existing production app without uninstalling it. Android will accept an in-place update only if package identity, signer continuity, and version direction are valid.

---

## 10. Existing automated coverage

The repository contains targeted tests for at least the following:

### Import/parser

- Soundiiz and Exportify shapes;
- required columns;
- CSV quoting and embedded newlines;
- explicit millisecond durations, including short tracks;
- ambiguous-duration conversion;
- session reset and rollback.

### Matching

- structured YouTube Music/Topic results;
- collaborations and featured-artist suffixes;
- album and duration comparisons;
- long-form, live, karaoke, and version terms;
- trusted/untrusted source boundaries;
- pause, cancel, and exclusion persistence;
- fallback failure while retaining structured results.

### Review and routing

- unmatched/excluded handling;
- rescue pause/cancel;
- candidate clusters and selected alternatives;
- stale sessions/snapshots;
- destination selection;
- duplicate previews;
- unresolved rows;
- permanent exclusion and queue draining.

### Manual source input

- YouTube/YouTube Music link parsing and lookup behavior.

### Backup/restore

- arbitrary renamed-file rejection;
- SAF paths;
- semantic counts including a 2,643-row fixture;
- streaming behavior;
- exclusion preservation;
- missing databases;
- checksum tampering;
- extension enforcement;
- legacy input rejection;
- rollback and startup recovery.

### Updater

- update availability/current version;
- signer mismatch;
- hash/install flow;
- URL restrictions;
- cancellation.

### Visual/widget coverage

- swipe gestures;
- compact missing-suggestion states;
- Library import-button placement;
- update cancellation;
- golden screenshots for import hub, destination variants/dialogs, Quick Review, and compact dark updater states.

There is no evidence in this handover of a complete real-Android-emulator integration suite. Device-level install, signer continuity, Storage Access Framework, process restart, playback, and large-real-library survival still require explicit manual or new integration coverage.

---

## 11. Required development workflow for Cursor and multiple agents

### Boot sequence for every new agent

1. Read this document completely.
2. Read these repository documents:

   ```text
   docs/PRODUCT_VISION.md
   docs/IMPORT_AND_MATCHING_ROADMAP.md
   docs/DATA_RECOVERY_RUNBOOK.md
   docs/TESTING_DATA_SAFETY.md
   docs/RELEASE_SIGNING.md
   docs/UPDATE_DELIVERY.md
   ```

3. Fetch remote `master` and record the exact SHA.
4. Inspect `git status`, current branch, open PRs, and recent CI before proposing changes.
5. State the task scope, files likely affected, data-safety risk, and verification plan.
6. Create a fresh branch named `agent/{short-description}` unless Daniel chooses another name.

### Multi-agent roles

Agents can work faster when their responsibilities are explicit:

| Role | Responsibility |
|---|---|
| Planner/architect | Clarifies invariants, data flow, migration, and acceptance criteria before code changes. |
| Implementer | Makes the scoped change and targeted tests on one branch. |
| Safety/release reviewer | Audits storage, backups, package IDs, signing, update delivery, and destructive behavior. |
| Visual reviewer | Checks hierarchy, spacing, motion, compact layouts, mini-player overlap, and consistency. |
| Final reviewer | Reviews the exact pushed head and confirms all actionable threads/checks are resolved. |

Do not allow two agents to edit the same files concurrently without coordination. Parallelize research, test planning, visual review, and code review; serialize overlapping implementation.

### Branch and PR discipline

- One coherent task per branch/PR.
- Never build new work on PR #4 or #7.
- Never merge a PR merely because a bot stopped responding.
- Review the exact pushed head, not a prior commit.
- Address each actionable review thread, explain the fix, push, request rereview, and repeat until the exact head is clear.
- Do not merge with failing required checks or unresolved actionable review threads.
- Preserve unrelated user changes in dirty worktrees.
- Do not force-push over another agent's active work unless ownership was explicitly transferred.

### Standard handoff block between agents

Every agent should leave:

```text
Objective:
Repository / branch:
Base SHA:
Current head SHA:
Files changed:
Behavior changed:
Data/schema implications:
Tests run and exact results:
Visual review performed:
Known risks / unverified device behavior:
PR/review status:
Single next action:
```

This makes the work portable between Cursor, Codex, Claude, GLM, and human review.

---

## 12. Definition of done

A change is not “done” merely because code exists.

### For every change

- Formatter is clean.
- Analyzer passes.
- Relevant targeted tests pass.
- Full test suite passes before merge.
- New failure states have useful, honest user messages.
- Existing user data is preserved on success, cancellation, failure, and restart.
- No secret or personal fixture enters git.
- PR review applies to the exact final head.

### Additional requirements for UI work

- Test standard and compact phone sizes.
- Test dark theme and any supported light theme.
- Test long titles, missing artwork, empty states, loading, errors, and disabled actions.
- Confirm no mini-player, navigation, keyboard, or safe-area overlap.
- Add/update widget and golden coverage.
- Check animation entrance, exit, interruption, back navigation, rapid taps, and reduced-motion behavior.
- Keep motion purposeful; do not slow high-volume review.

### Additional requirements for data/import work

- Test duplicate import.
- Test partial write/failure.
- Test cancellation and process restart.
- Test stale session/snapshot rejection.
- Test empty/malformed/renamed files.
- Test unresolved and excluded rows.
- Verify exact semantic counts, not just file existence.
- Prove routing is idempotent.

### Additional requirements for release/update work

- Use only the signed production workflow.
- Candidate must equal current `master` tip.
- Verify signer, package name, label, non-debuggable state, hash, and version code.
- Install over the existing production app without uninstalling.
- Launch and restart.
- Confirm Liked Songs, playlists, exclusions, import state, settings, and counts survived.
- Test the in-app updater with a genuinely newer signed release.

---

## 13. Snapshot follow-up list — not standing authorization

These were ordered at the snapshot to reduce risk and unblock future testing.
They are follow-up facts, not standing authorization. Recheck current external
state and obtain Daniel's explicit approval before closing PRs, dispatching
Actions, signing, publishing, installing on a phone, or changing production.

1. **Verify the current remote state.** Fetch `master`, confirm PR #17 is merged, record the current tip, inspect Actions/Releases, and determine whether a signed PR #17 release already exists.
2. **Publish the merged stack if needed and explicitly approved.** With Daniel's approval, run `Build and publish signed production APK` against the current exact `master` tip with clear release notes.
3. **Audit release proof.** Confirm the workflow passed tests and the release contains the production APK, checksum, update manifest, and proof; confirm signer/package/version metadata.
4. **Perform a non-destructive phone update.** Install the production APK over the existing production app—no uninstall, no storage clearing.
5. **Run a phone smoke/data-survival test.** Launch, restart, play a song, inspect Liked Songs count, playlists, remaining review/exclusion state, settings, and current-player behavior.
6. **Verify permanent exclusion on-device.** Remove the unwanted voice-over items, restart, and confirm they do not return to review or enter a destination.
7. **Verify backup creation and independent restore.** Create a streamed `.musifybackup`, validate semantic counts, and restore it only into a disposable emulator/test installation before relying on it for disaster recovery.
8. **Prove in-app updates end-to-end.** After a subsequent safe merged change produces a newer signed release, use the installed app's updater and verify hash/signer/package checks plus data survival.
9. **Clean GitHub state if explicitly approved.** Close superseded PRs #4 and #7 without merging after confirming no unique work; remove obsolete branches only when safe and authorized.
10. **Begin the next feature slice: playlist-aware import.** Add Premium-free ZIP/JSON/CSV/TSV playlist ingestion and stable repeat-sync semantics, then give the result a full visual/motion and device-size pass.

---

## 14. Forward roadmap after the immediate release

### Phase A — Complete Premium-free playlist migration

- Define a source-neutral import model carrying playlist identity and membership.
- Parse Spotify account export ZIP/JSON plus supported CSV/TSV formats.
- Preview playlists, track counts, duplicates, missing metadata, and unresolved rows before mutation.
- Map each source playlist to Liked Songs, an existing playlist, a new playlist, or skip.
- Support all tracks, exact counts, and selected subsets.
- Preserve stable source identifiers for repeat sync.
- Show added/unchanged/unresolved/excluded/removed results without silently deleting local songs.

### Phase B — Optional direct Spotify connection

- Authorization Code with PKCE.
- User-configurable Client ID if required by Spotify policy.
- Import metadata and playlist membership only within available account/API permissions.
- Never require Premium.
- Never make OAuth the only import route.
- Provide disconnect and token-removal controls.
- Be explicit about Spotify API limitations instead of inventing workarounds.

### Phase C — Library and source intelligence

- Canonical song identity separated from playback source.
- Multiple verified sources per recording.
- Source-health checks and automatic safe fallback.
- Original studio/explicit/version preferences.
- Better album and compilation handling.
- Personal/local-server lossless source support.

### Phase D — Personal intelligence

- Local taste model.
- Context-aware smart playlists.
- Intentional DJ and smart queues.
- Late Night, Gym, Driving, rediscovery, and novelty controls.
- AutoMix and transition intelligence.
- Explainable recommendations with user-editable controls.

### Phase E — Experience expansion

- Album-driven home/library redesign.
- Music Atlas exploration.
- Offline reliability.
- Android Auto.
- Continued accessibility, performance, animation, and battery/network optimization.

---

## 15. Known risks and anti-patterns

### Data risks

- Treating a file's extension as sufficient validation.
- Treating successful file-picker return as successful backup/export.
- Loading an entire large backup into multiple in-memory byte/Base64 copies.
- Resetting import keys without transactional rollback.
- Losing playlist membership between parsing and routing.
- Conflating unmatched, skipped, excluded, failed, and routed states.
- Reusing stale UI snapshots after a background operation changes the session.
- Clearing existing library state before replacement data is fully validated.

### Matching risks

- Accepting a title-only or artist-only result automatically.
- Promoting long-form, live, karaoke, compilation, or unrelated uploads without version checks.
- Treating any YouTube video as a trustworthy song source.
- Losing structured results when a fallback network request fails.
- Re-running the whole library to surface a small unresolved queue.

### Android/release risks

- Confusing debug, unsigned release, F-Droid, and permanently signed production APKs.
- Changing production application ID or signer.
- Reusing/decreasing version codes.
- Publishing from a stale candidate SHA.
- Installing the `.sha256` or artifact archive instead of the APK.
- Assuming a GitHub artifact is installable because it has an `.apk` suffix.

### UI risks

- Floating actions obscuring the mini-player or last card.
- Large headings truncating without compact alternatives.
- Controls that abruptly appear/disappear with no spatial continuity.
- Excessive motion in a high-volume review flow.
- New personalized screens drifting from established typography, radii, palette, and button hierarchy.
- Disabled controls without explanatory copy.

### Agent-process risks

- Starting from a dirty detached checkout.
- Reapplying already-merged review fixes.
- Trusting a stale bot approval after new commits.
- Polling repeatedly and consuming usage without new state.
- Letting multiple agents edit overlapping files without a handoff.
- Saying “all good” without naming the checks, commit, and remaining real-device gaps.

---

## 16. Useful operational commands

Run from a clean repository root with the project's supported Flutter toolchain.

```bash
git fetch origin
git switch master
git pull --ff-only origin master
git status --short --branch
git rev-parse HEAD

flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

For a scoped change, run the relevant targeted tests first, then the full suite. Use the repository workflow definitions as the authoritative CI commands because they may include visual or Android identity scripts beyond the generic commands above.

Before asking for final review:

```bash
git status --short
git diff --check
git log -1 --oneline
```

Do not run destructive git commands against a dirty user worktree. Do not copy signing secrets into local shell history.

---

## 17. Suggested first prompt for a new coding agent

Use this with Cursor, Claude, GLM, Codex, or another agent after giving it this document and repository access:

> Read `docs/MASTER_AGENT_HANDOVER.md` and the six referenced files under `docs/` before changing code. Then fetch remote `master`, report the exact SHA, current PR/CI/release state, and whether the signed production build containing PR #17 has been published. Do not use an old feature branch or dirty detached workspace. Do not uninstall/clear either Android app, expose secrets, or claim backup/restore success without semantic and restart verification. First give me a concise plan, safety risks, affected files, and tests. Wait for approval before implementing if the scope is larger than a small isolated fix.

---

## 18. Final north star

The point of this project is not simply to import a Spotify CSV or make Musify prettier. It is to build a trustworthy personal music environment where Daniel can move his library out of a subscription ecosystem, resolve difficult recordings with excellent tools, organize music exactly as he wants, update the app without risking his data, and gradually gain a deeply personalized DJ/library experience.

Every engineering choice should be judged by five questions:

1. Does it preserve and clearly account for the user's real music data?
2. Does it improve the accuracy or controllability of song identity and source selection?
3. Does it remain useful without Spotify Premium or mandatory cloud dependence?
4. Does it feel coherent, fast, and premium on the actual phone?
5. Can the next agent prove what happened through tests, audit state, release proof, and honest verification labels?

If the answer to any of those is unclear, stop, inspect, and make the uncertainty visible before shipping.
