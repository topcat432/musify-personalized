# Musify Personalized release state

## Purpose

This file is the concise release-status ledger for agents and maintainers. It
must distinguish local repository facts, dated handover evidence, external
GitHub state, and phone verification. Update it only from evidence; include the
date and source of every material change.

## Local workspace — verified 2026-07-15

- Repository: the local `musify-personalized` checkout
- Current branch: `agent/agent-workflow-bootstrap`
- Base commit before the bootstrap commit:
  `27256cedefd915e905d7478107104cebdbbecebc`
- `origin` fetch/push: `https://github.com/topcat432/musify-personalized.git`
- `upstream` fetch: `https://github.com/gokadzev/Musify.git`
- `upstream` push: disabled
- Before this bootstrap, `docs/MASTER_AGENT_HANDOVER.md` was the only untracked
  file reported by `git status --short`.
- Before this bootstrap, none of the requested agent-workflow setup files had
  been committed.
- `pubspec.yaml` declares `10.1.0+175`, Flutter `3.44.5`, and Dart
  `>=3.12.0 <4.0.0`.

These are local-worktree facts. They do not establish the current remote
default-branch tip, open PRs, Actions results, Releases, or installed phone
version.

## Historical GitHub evidence — handover snapshot 2026-07-14

`docs/MASTER_AGENT_HANDOVER.md` records:

- PR #17 was reviewed and merged into `master`.
- The known merge/master snapshot was
  `27256cedefd915e905d7478107104cebdbbecebc`.
- PR #16 was merged and included in that stack.
- Exact-head CI run `29383734944` passed analyzer, tests, visual rendering,
  debug identity checks, F-Droid permission checks, and an unsigned release
  build.
- PRs #4 and #7 were still open and described as superseded candidates to
  inspect and close without merging if they contained no unique work.
- No open issues were known at that snapshot.

This is historical evidence, not a current GitHub query. The recorded SHA must
not be reused as a release candidate unless it is independently proven to be
the current exact default-branch tip.

## Publication state — unknown until externally verified

The handover states that publication of the merged PR #17 stack through the
signed production workflow had not been confirmed. This bootstrap did not query
GitHub Actions or Releases and did not run a release workflow.

Therefore, do not currently claim that:

- a signed production release containing PR #17 exists;
- the latest GitHub Release contains the required APK, checksum, manifest, and
  release proof;
- the current installed production app came from that workflow; or
- the in-app updater has passed end-to-end phone testing.

The only approved production workflow in the repository is
`.github/workflows/signed-release.yml`, named
`Build and publish signed production APK`. It is manually dispatched with an
exact full lowercase 40-character candidate SHA and verifies that candidate
against the current default-branch tip. No workflow was dispatched during this
bootstrap.

## Follow-up facts — not release claims or authorization

- `.github/workflows/debug.yml`, `fdroid.yml`, `pre_beta.yml`, and
  `pre_fdroid.yml` remain in the checkout. Some retain upstream-era release
  behavior or metadata. They are not substitutes for the approved personalized
  production path and were not changed by this bootstrap.
- `pubspec.yaml` still points its homepage, repository, and issue tracker at
  `gokadzev/Musify`, while this checkout's `origin` is
  `topcat432/musify-personalized`. This is a follow-up metadata fact, not proof
  of release ownership or permission to modify the package manifest.
- Current Actions, Releases, open PRs, and installed-phone state remain external
  facts that require direct verification.

These items may be investigated in a separately approved task. They do not
authorize workflow, `pubspec.yaml`, signing, release, or repository-setting
changes.

## Known phone/data evidence — dated, not refreshed

The 2026-07-14 handover records the owner's observations that:

- matching completed in the production app;
- accepted songs were moved into Liked Songs;
- a screenshot showed 2,454 songs in Liked Songs;
- five unwanted voice-over items remained in detailed review; and
- permanent exclusion for those items was implemented and merged.

The same handover says not to assume that the merged exclusion build was
installed. It also says the debug app/data may still exist as a fallback and
must not be deleted.

The streaming backup implementation is recorded as CI-verified, but real-phone
backup creation and independent restore remained unverified. A prior observation
that loading from backup appeared to work is not semantic and restart proof.

## Release gates still requiring evidence

Before anyone calls the merged stack released or phone-verified, all applicable
evidence must be recorded:

1. Current remote default-branch tip and PR #17 merge state.
2. Current Actions and Releases state.
3. Successful approved signed-production workflow on the exact tip.
4. Published production APK, checksum, update manifest, and release proof.
5. Verified package, label, non-debuggable state, version direction, signer,
   v2/v3 signatures, and APK hash.
6. In-place installation over the existing production app without uninstalling
   or clearing data.
7. Launch and restart with Liked Songs, playlists, exclusions, import state,
   settings, counts, and playback intact.
8. Streamed backup with semantic validation and an independent restore on a
   disposable installation.
9. In-app updater proof using a genuinely newer signed production release.

Each item must be labeled CI-verified, phone-verified, or unverified as
appropriate. Stop before signing, publishing, installing, merging, or any other
production action unless the owner explicitly authorizes it.

## Update entry template

```text
Date/time and timezone:
Evidence source:
Commit/workflow run/release tag:
State changed:
Verification level:
Remaining unknowns:
Recorded by:
```
