# Musify Personalized decision log

## How to use this log

This file records decisions already established by the product doctrine,
roadmap, handover, runbooks, and repository workflows. It does not convert dated
observations into current facts. Add a new entry when a material product,
architecture, data, visual, or release choice is approved; do not silently edit
an older decision to make history look consistent.

Status values are `accepted`, `superseded`, or `proposed`. A proposed entry is
not implementation authority. Link the superseding entry when a decision
changes.

## D-001 — Local-first, single-user product

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot
- **Decision:** Musify Personalized is a private-feeling, local-first music
  system for one primary user. Data ownership, reliability, personal relevance,
  and control take precedence over mass-market, social, engagement, advertising,
  account, or SaaS assumptions.
- **Consequence:** New systems should work without mandatory cloud dependence
  unless the owner explicitly changes direction.
- **Evidence:** `docs/PRODUCT_VISION.md` and
  `docs/MASTER_AGENT_HANDOVER.md` sections 0-2.

## D-002 — User data safety outranks delivery speed

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot
- **Decision:** Do not uninstall either app, clear storage, overwrite the real
  library, repeat completed matching as a workaround, or trust unverified backup
  and restore signals.
- **Consequence:** Destructive work stops for explicit risk review. Backup and
  restore require structural, checksum, semantic, reopen, and restart proof.
  Synthetic data is required in repository tests.
- **Evidence:** `docs/MASTER_AGENT_HANDOVER.md` sections 3-4,
  `docs/DATA_RECOVERY_RUNBOOK.md`, and `docs/TESTING_DATA_SAFETY.md`.

## D-003 — Canonical recordings are separate from playback sources

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot
- **Decision:** A durable song represents a canonical musical identity. A
  YouTube or YouTube Music URL is a candidate lookup hint; it must resolve to a
  normal Musify song rather than become a special hard-coded URL record.
- **Consequence:** Matching and future multi-source playback must preserve
  recording/version identity and describe source quality honestly.
- **Evidence:** `docs/PRODUCT_VISION.md` and
  `docs/IMPORT_AND_MATCHING_ROADMAP.md` sections 2-3.

## D-004 — Import is a resumable, staged pipeline

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot
- **Decision:** Read source and playlist membership, match each unique
  recording, retain unresolved rows, allow later resolution or exclusion, route
  an explicit subset to an explicit destination, and record the result.
- **Consequence:** Import cannot silently mutate destinations, discard
  unresolved items, redo completed work, or produce uncontrolled duplicates.
  State changes need checkpoints, idempotency, and stale-state protection.
- **Evidence:** `docs/IMPORT_AND_MATCHING_ROADMAP.md` product contract and
  `docs/MASTER_AGENT_HANDOVER.md` section 8.

## D-005 — Unmatched and permanently excluded are different states

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot
- **Decision:** A missing or rejected current match remains recoverable. A
  permanent exclusion is an explicit, durable, audited decision that keeps an
  item out of review and routing unless deliberately restored.
- **Consequence:** UI copy, storage, filtering, retry, audit, and tests must not
  conflate unmatched, review, error, accepted, routed, and excluded states.
- **Evidence:** `docs/MASTER_AGENT_HANDOVER.md` sections 6 and 8 and
  `docs/IMPORT_AND_MATCHING_ROADMAP.md` section 1.

## D-006 — Premium-free import is the primary Spotify path

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot
- **Decision:** Flat files and playlist-aware ZIP/JSON/CSV/TSV exports are the
  primary import path. A direct Spotify connection may be added later using a
  compliant authorization approach, but remains optional and must not require
  Premium.
- **Consequence:** Do not make OAuth, a developer account, Spotify playback, or
  a paid tier a prerequisite for library migration.
- **Evidence:** `docs/IMPORT_AND_MATCHING_ROADMAP.md` sections 5-6 and delivery
  order; `docs/MASTER_AGENT_HANDOVER.md` section 8.

## D-007 — Production and debug identities remain isolated

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot
- **Decision:** The production package is
  `com.topcat432.musifypersonalized`; the debug package is
  `com.topcat432.musifypersonalized.debug`. The F-Droid package recorded by the
  handover is `com.gokadzev.musify.fdroid`.
- **Consequence:** Debug must remain visibly distinct and must not overwrite
  production storage. Package or signer changes are release-breaking decisions,
  not routine refactors.
- **Evidence:** `docs/MASTER_AGENT_HANDOVER.md` sections 4 and 9 and current
  identity checks in `.github/workflows/debug.yml`.

## D-008 — One approved user-facing production release path

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot; workflow inspected 2026-07-15
- **Decision:** The sole approved production path is
  `.github/workflows/signed-release.yml`, named
  `Build and publish signed production APK`.
- **Consequence:** Debug, unsigned, pre-release, and F-Droid artifacts must not
  be represented as Musify Personalized production updates. The signed workflow
  requires the exact default-branch tip and verifies version direction, package,
  label, non-debuggable state, signer, v2/v3 signatures, and APK hash before
  publication.
- **Evidence:** `docs/MASTER_AGENT_HANDOVER.md` section 9,
  `docs/RELEASE_SIGNING.md`, and `.github/workflows/signed-release.yml`.

## D-009 — Verification levels remain explicit

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot
- **Decision:** `merged`, `CI-verified`, `phone-verified`, and `unverified` are
  separate claims.
- **Consequence:** Compilation, unit/widget tests, and golden rendering do not
  prove Android installation, signer continuity, Storage Access Framework,
  playback, real-library survival, backup/restore, or in-app update behavior.
- **Evidence:** `docs/MASTER_AGENT_HANDOVER.md` sections 0, 10, and 12.

## D-010 — Personalized UI uses the shared visual language

- **Status:** accepted
- **Recorded:** 2026-07-14 handover snapshot; implementation inspected
  2026-07-15
- **Decision:** Continue the warm, dark, premium, album-driven direction while
  inheriting the active app color scheme, using shared personalized components,
  and respecting reduced motion and compact layouts.
- **Consequence:** New personalized screens receive typography, spacing, state,
  motion, safe-area, mini-player, accessibility, and golden-review passes.
- **Evidence:** `docs/MASTER_AGENT_HANDOVER.md` sections 2, 6, and 12;
  `lib/widgets/personalized_ui.dart`; `docs/VISUAL_SYSTEM.md`.

## New decision template

```text
## D-NNN — Short title

- Status: proposed | accepted | superseded by D-NNN
- Recorded: YYYY-MM-DD and source
- Decision: What was decided
- Consequence: What this requires or rules out
- Evidence: Approval, issue/PR, code, workflow, or document references
```
