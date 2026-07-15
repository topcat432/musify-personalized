# Musify Personalized agent instructions

These instructions apply repository-wide. Nested instructions may add
constraints but may not weaken the safety or release stops below.

## Before editing

Inspect the branch, worktree, remotes, and files in scope. Always read
`docs/MASTER_AGENT_HANDOVER.md` and `docs/RELEASE_STATE.md`, then read the
task-relevant source documents:

- product/import: `docs/PRODUCT_VISION.md` and
  `docs/IMPORT_AND_MATCHING_ROADMAP.md`;
- recovery/real data: `docs/DATA_RECOVERY_RUNBOOK.md` and
  `docs/TESTING_DATA_SAFETY.md`;
- signing/updates: `docs/RELEASE_SIGNING.md`, `docs/UPDATE_DELIVERY.md`, and the
  actual `.github/workflows/` definitions;
- UI: `docs/VISUAL_SYSTEM.md` and the existing shared widgets;
- repository conventions: `docs/DECISIONS.md`, `CONTRIBUTING.md`, and
  `pubspec.yaml`.

The handover and recovery/testing documents are dated or conditional. They are
not proof of current GitHub, release, or phone state. Verify current claims at
the authoritative source and label them merged, CI-verified, phone-verified, or
unverified.

## Mandatory stops

Stop and ask Daniel before:

- any destructive Git, device, storage, backup, restore, or real-data action;
- uninstalling either app, clearing storage, replacing the real library,
  removing the debug fallback, or rerunning the completed 2,643-track match;
- changing a package identity, signing configuration, release/update contract,
  durable data model, or migration when the safe path is unclear;
- accessing, reconstructing, printing, or requesting secret values or signing
  material;
- resolving material product ambiguity that would change user-visible behavior,
  data meaning, scope, or architecture; or
- merging, enabling auto-merge, signing, publishing, releasing, installing on
  the owner's phone, changing repository settings, or touching production.

A general request to code, review, commit, push, or open a PR does not authorize
merge or production work. Those actions require Daniel's separate, explicit
approval for the exact action and current state.

Never commit personal exports, histories, device Hive files, `.musifybackup`
archives, private diagnostics, signing material, passwords, tokens, or private
client identifiers. Use synthetic fixtures. Secret names and the configured
alias may be documented; their values must never be exposed.

## Product and data invariants

- A song is a canonical recording identity, not merely a video URL or ID.
- Import must not silently mutate destinations or discard unresolved rows.
- Unmatched, review, error, accepted, routed, and permanently excluded are
  distinct states.
- Retry/resume preserves completed work; routing is explicit, audited, and
  idempotent.
- Existing library contents, user-selected candidates, source order, and
  playlist membership must survive applicable operations.
- File import remains usable without Spotify Premium or mandatory cloud access.
- Backup/restore success requires structural, checksum, semantic, reopen, and
  restart proof—not a picker result, filename, toast, or file existence.
- Hive changes require forward migration, failure/rollback behavior, restart
  coverage, and tests against partial or older data.

## Ownership and Git discipline

Use one active writer per file. Other agents may research or review, but file
ownership must be handed off explicitly before another agent edits it. Preserve
unrelated changes and do not force-push over active work.

Use one coherent task per `agent/{short-description}` branch unless Daniel
chooses otherwise. Do not base work on stale/detached checkouts or superseded PR
branches. Do not commit, push, open/close a PR, delete a branch, or modify remote
state unless Daniel requested that specific action.

Before implementation, state scope, likely files, data risk, and verification.
Documentation/workflow tasks do not authorize product-code changes.

## Implementation and verification

Follow existing Flutter architecture. Reuse
`lib/widgets/personalized_ui.dart` and `docs/VISUAL_SYSTEM.md` for personalized
surfaces. Preserve truthful status language, compact layouts, theme behavior,
safe areas, mini-player/navigation clearance, error/empty/loading states, and
reduced motion.

Use commands supported by the current workflows and task scope:

```bash
flutter pub get
flutter analyze .
flutter test
flutter test tool/visual_review_test.dart --update-goldens
git diff --check
git status --short
```

Run targeted checks first and the full suite before merge for product changes.
Documentation-only changes need text/link/state checks, not an APK build. If a
required tool is unavailable, report it; do not install software without
authorization. Current workflow definitions override summarized commands.

## Production workflow

The only approved user-facing production path is
`.github/workflows/signed-release.yml`, named
`Build and publish signed production APK`. `debug.yml`, `fdroid.yml`,
`pre_beta.yml`, and `pre_fdroid.yml` are not substitutes for that path.

Never dispatch the production workflow without Daniel's explicit approval. Its
candidate must be the exact current default-branch tip and pass its package,
label, version, non-debuggable, signer, v2/v3 signature, and hash gates. A phone
update must be in place; never uninstall or clear storage to make it succeed.

## Handoff

Report exact files, behavior/data implications, checks and results, verification
level, contradictions, unresolved risks, PR/review state, and the single next
action.
