# Musify Personalized current state

Recorded 2026-10-11. This is the living map; verify current GitHub heads/runs
and connected device identity before relying on dated observations.

## Source and channels

| Item | Proven state |
|---|---|
| Repository | topcat432/musify-personalized |
| Integration | Protected master, observed a786323556275a0de745ffca4d3affc088ac2055 |
| Sole active candidate | Draft PR #23, agent/local-stable-consolidation |
| Initial candidate commit | 16d06d92d4da8354a0d03e765ec77a53dbd2f626; check PR HEAD for later commits |
| Foundation | #20 head 395ecace3da567ef1437c7a2229252ef84ee94de |
| Playback intent | #21 head 76201eeb409594117c873716a41f7ebc6dd3224d, with both P1 defects corrected |
| Deferred Home/shell | #22 head f14a73fb7b9b56682d72fa9868a9dec3ffb1a2ac; preserved, not integrated |
| Retained stable identity | com.topcat432.musifypersonalized.preview |
| Debug isolation | com.topcat432.musifypersonalized.preview.debug |
| F-Droid | Existing com.gokadzev.musify.fdroid identity/permission boundary preserved |

Get the current candidate with gh pr view 23 --repo topcat432/musify-personalized
--json headRefOid,statusCheckRollup. Do not confuse PR test merge refs, branch
HEAD, installed baseline and published source.

## Installed binary baseline

Selected Samsung SM_G998U1, Android 15/API 35. Read-only evidence proved
the daily package com.topcat432.musifypersonalized.preview, label
Musify Personalized PREVIEW, versionName preview.0.1.1, versionCode 300000001.
Installed APK SHA-256:
2dd3360db7f5376fbe6768709554c2ebc8991a1588d87750d474ffe55e3ab1ea.
Public signer SHA-256:
58c5316466da7a426c4411beb33b3b594ef58875bcfa31e092a5afce8cf9999e.
The signed APK is preserved outside the repo; it is not a data backup.

Strongest source candidate: 0ea1b44dad777efd03c819becd31acffa996427f, original
preview run 29479259739. Its original artifact expired, and the APK has no
supported VCS metadata. Exact binary-source attribution remains unproven.
The old About 10.1.0 was hardcoded and cannot identify the binary.

## Signed published release is a different package

Historical tag personalized-v0.1.100000010, source
27256cedefd915e905d7478107104cebdbbecebc, package
com.topcat432.musifypersonalized, versionCode 100000010.
APK SHA-256:
d77204a480a56cd5dfb5a62d27b9a8910a148528ec97adf3de37bf4b498059bc.
Same public signer, different Android data container. It is not an in-place
update for the current Samsung app. No consolidated candidate has been signed,
published, merged or installed on that phone.

## Validation and acceptance

Local initial candidate: 157 aggregate tests passed, targeted regressions and
analyzer passed; unsigned assembly succeeded. Unsigned APK code 300000002,
versionName 0.1.300000002, retained package, correct label, non-debuggable.
Linux reference run 38112105227 on initial candidate: aggregate checks passed;
33 unchanged strict goldens passed, only the two intentional About images failed.
Both Linux About before/after pairs were reviewed; only those two PNG baselines
were deliberately replaced. Subsequent exact-head CI must prove the result.

Run 38113993655 on 12e709c6 passed analysis, aggregate tests and all 35 strict
goldens. Its Android build stopped because the runner lacked the pinned NDK;
both canonical workflows now prepare that exact SDK component explicitly,
using existing licenses and rejecting new prompts. Full build proof is pending.
Run 38114487224 passed the same strict gates after the restore fix and reached
native compilation, then stopped because CMake 3.22.1 was missing. That exact
component is now explicit too. Verification also checks out the candidate SHA
directly and embeds it, instead of attributing a temporary PR merge ref to the
candidate branch. A full run remains required before retiring legacy workflows.

The visual suites now share one loader. The official DejaVu pinning experiment
did not match the stored Linux baseline and was backed out. CI captures its
exact selected font/toolchain for bounded rendering diagnosis. Windows is not
the pixel reference. Do not report a visual PASS until strict comparisons pass.

Official emulator 37.2.12 and Android 35 Google APIs x86_64 image installed on
DESKTOP-OPE9IIV with existing accepted licenses unchanged and usable WHPX.
Task-owned AVD musify_rehearsal_api35, emulator-5556, is separate from other
projects. Real backup/restore/restart evidence is pending; Samsung disconnected
after the initial check. Historical 2,643/2,454 counts are not today's inventory.
Signing/publication and live-phone update remain held.

The preserved installed APK failed synthetic file-picker restore on the
disposable emulator: the selected temporary file was removed before asynchronous
inspection completed. The candidate now awaits inspection before cleanup; a
picker regression reproduces the old failure and all 17 backup service tests
pass after the fix. Android restore/restart/export acceptance remains pending.

## Recovery and retired work

Before cleanup, all 25 original branches, tags and 22 PR heads were bundled,
restored with identical refs and passed git fsck --full.
Task-local bundle: musify-source-comparison/repo-recovery-20261011/
musify-pre-cleanup.bundle (outside the checkout), 40,945,016 bytes.
SHA-256: 10eb04fe3319d31ac5bc6af08862f8c923ae0eb3524cdd10d9bdf75c325e325a.
Adjacent inventory/classification/proof records contain exact branch/PR heads.
Cleanup dispositions will be recorded after each authorized action is verified.
Remote cleanup is currently blocked by approval review; no prior PRs or branches
have been closed/deleted. The six superseded PRs and 24 original non-master
branches remain until that action is approved. Draft #23 is the canonical path.
No unique commits are discarded; #22 remains a roadmap reference, not an active
parallel candidate. Recovery instructions are in CONTRIBUTING.md.

## Single operating path

Read AGENTS.md and CONTRIBUTING.md; use debug.yml for Linux verification and
signed-release.yml only for separately approved release. Product vision/import
roadmap and VISUAL_SYSTEM.md remain useful design references. This map tracks
facts, not blanket permission. Next gates: exact-head CI, disposable real-data
restore/restart, reviewed integration, approved signing/publication, then
separately approved in-place phone acceptance.
