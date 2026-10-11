# Musify Personalized current state

Recorded 2026-10-11. This is the living map; verify current GitHub heads/runs
and connected device identity before relying on dated observations.

Expanded production acceptance now has conditional owner authorization for
integration, the existing signed publication workflow and an in-place Samsung
update only after backup, product, visual and signed rehearsal gates pass.
See PRODUCT_ACCEPTANCE.md for the source-linked scope and per-path ledger.
The Samsung was unlocked and its actual app-supported export was saved and
independently inspected. The owner confirms its empty library was expected and
plans a fresh supported Spotify export/reimport. Do not substitute historical
imports for this current state. No merge, signing or live update has occurred.
Disposable real-export restore/full restart/native re-export passed with every typed key/value exact and no exceptions. Final signed in-place rehearsal remains a gate.

The current candidate also fixes two reproduced PlaylistPage defects: its
unavailable-state sliver must be hosted by a scroll view, and its Shuffle button
must submit natural-order songs with player shuffle enabled. Targeted regressions
(12 tests), aggregate tests (161) and local analysis pass. Final strict Linux CI
and actual final-APK runtime coverage remain required. Controlled disposable
same-name backup inspections read fresh counts 2/1/2 without restoring; the earlier
stale-selection observation did not reproduce in that bounded check.

The latest disposable runtime checkpoint is recorded in PRODUCT_ACCEPTANCE.md.
Native public-fixture decisions preserve the exact accepted alternate, reopenable
No match metadata, exclusion audit, all source rows and existing likes. All-resolved
routing and a repeated no-additions transfer ran with an unresolved row retained.
Additional playlist, restart, backup and playback paths remain open. A reproduced
covered-card accessibility defect has a candidate repair; local analysis and all
162 tests pass. Host ranged audio GET success does not satisfy native playback.

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

The actual app-supported export contains the compile-time GIT_SHA source stamp
0ea1b44dad777efd03c819becd31acffa996427f, verified against that source's
String.fromEnvironment implementation. Its legacy package/version labels are
hardcoded; Android package manager and the extracted APK establish identity.
Original preview run 29479259739's artifact expired, so comparison against that
original CI artifact remains unavailable. The stamp strengthens source
attribution without proving an exact historical CI-artifact hash match.
The old About 10.1.0 was hardcoded and cannot identify the binary.

Actual Samsung export SHA-256:
9f74763b07e2dbd89336d58c37a3379282a49bfcddf37cbb2dd773957770bc34.
Its 251,405 bytes contain four user keys and three settings keys: empty liked
playlists, two recent songs, two search entries, listening statistics and the
three existing settings. Imports, matches, favorites and custom playlists are
zero. Independent whole typed-map SHA-256:
ae6c1be7d8fe8aa9f1e3b9dc460626c7e7a4f0ab2dcc66410f362eba0468fa17.
Private exports and UI evidence remain outside Git and Library.

Latest tested candidate: 26bd0e98f4980f69c017aee52c62fd93965b1d16,
CI 38123616644 successful (analysis, 171 tests, 35 strict goldens and APK builds).
Its exact emulator debug APK hash is
785f0fadee679c4c2c3f811ebc1207abeb4ad7f4f1e3ca17dc7e0350c884d55b.
Native public-track playback still fails HTTP 403. Host finite-range GET
acceptance does not prove native decoding, preview timing or completion. The
provider accepts a finite 256 KiB range but rejects full and open-ended requests.
The owner subsequently approved a GitHub-flavor-only IPv4 loopback exception:
HTTP 127.0.0.1, includeSubdomains=false; external cleartext remains denied.
The pending candidate uses just_audio's standard byte source to supply finite
HTTPS ranges through its random-port loopback server and fresh UUID-v4 source
path. Requests are lazy, bounded to 256 KiB, limited to four concurrent reads,
validated against exact Content-Range, timed out and closed on cancellation.
No device-wide policy, credentials, cookies, proxy or client impersonation changed.
Local analysis and all 208 aggregate tests pass. Native healthy playback on this
new code remains blocked. Exact-source CI 38128871154 passed all required gates.
Its emulator APK SHA-256 is
8049a5bda7b5f7b415215eee9f8d7845c74d712a8081594830e2cd3068188c9b.
Native controlled PCM 1/2/3 advance and pause the completed tail correctly;
shuffle-off restores order and Play Next insertion survives queue replacement.
Public Here Comes The Sun and Dreams initially decode but truncate after the
first MiB. Bounded diagnostics of both native cached URLs return HTTP 403 at
offset 1048576 while accepting the first finite range. No denial workaround was
attempted. Sustained listening, preview timing, seeking and clean failure remain
release blockers. Pending repair connects just_audio 0.10.6's separate errorStream
API, stops repeated upstream requests to a failed source and cancels superseded
queue retries; exact-source/native acceptance must follow.

The same repair pauses a completed non-repeating queue tail, preserves
SponsorBlock seeking for byte sources, starts manual preview's 30-second timer
without awaiting playback completion, and uses public YouTube oEmbed metadata
for exact-video lookup. Quick Review keeps its existing 12-second preview.
oEmbed has no duration; the candidate does not invent one. Denial, redirect,
oversized metadata and timeout fail without authentication fallback or saving.

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
using existing licenses and rejecting new prompts.
Run 38114487224 passed the same strict gates after the restore fix and reached
native compilation, then stopped because CMake 3.22.1 was missing. That exact
component is now explicit too. Verification also checks out the candidate SHA
directly and embeds it, instead of attributing a temporary PR merge ref to the
candidate branch.

Run 38115096390 on exact candidate 953e652c3031abd0dc3e3e59e3ca22875981786d
completed successfully: analysis, aggregate tests, 35 strict goldens, universal
debug identity, F-Droid permission boundary and unsigned release integrity/
package/version/non-debuggable checks. The three obsolete publishing workflows
fdroid.yml, pre_beta.yml and pre_fdroid.yml are removed in the subsequent
consolidation: their analysis/build roles have canonical coverage; their upload
steps incorrectly targeted gokadzev/Musify and are intentionally retired. No
legacy publication is recreated. The retained F-Droid code/identity remain.

Run 38117095235 on 73ff5421e3f941909e4e164a6b43c9660b3afa0d also completed
SUCCESS after both restore fixes and workflow retirement: clean analysis,
aggregate tests, all 35 strict goldens, debug/F-Droid builds and unsigned release
verification. The intervening 2f61715e run stopped only on import ordering;
73ff corrected that directive. No signing or update artifact was published.

The visual suites now share one loader. The official DejaVu pinning experiment
did not match the stored Linux baseline and was backed out. CI captures its
exact selected font/toolchain for bounded rendering diagnosis. Windows is not
the pixel reference. Do not report a visual PASS until strict comparisons pass.

Official emulator 37.2.12 and Android 35 Google APIs x86_64 image installed on
DESKTOP-OPE9IIV with existing accepted licenses unchanged and usable WHPX.
Task-owned AVD musify_rehearsal_api35, emulator-5556, is separate from other
projects. Actual Samsung export and disposable restore/full reboot/re-export
passed as recorded above. Historical 2,643/2,454 counts are not today's inventory.
Signing/publication and live-phone update remain held.

The preserved installed APK failed synthetic file-picker restore on the
disposable emulator: the selected temporary file was removed before asynchronous
inspection completed. The candidate now awaits inspection before cleanup; a
picker regression reproduces the old failure and all 17 backup service tests
pass after the fix. Candidate emulator inspection then exposed a second defect:
LayoutBuilder in AlertDialog's intrinsic layout left the validation modal blank.
The extracted summary now uses an intrinsic-compatible Table; its failing-before/
passing-after dialog regression and all 17 service tests pass.

Synthetic Android restore/restart/native export is now verified on that disposable
AVD using isolated .preview.debug. Tested APK source is
2f61715e26cda6a3e01e66cfa09f647f0929478e (73ff only reorders an import), SHA-256
1f8900cc060cafc180da132c03fa9c7a4aa9b5fe90d85b6ba6581410e2d61e09. Its signature,
embedded source SHA and ZIP integrity passed. Picker/review/restore succeeded;
UI verified 2 favorites and the custom playlist's recording 2 before recording 1,
including after a full Android reboot. Android System UI initially stalled but
recovered after a bounded Wait; the subsequent app restart and export succeeded.
Native saved-file reopen and an independent Hive inspection proved 5 imported
tracks/results, 2 strong matches, 1 review, 1 unmatched, 1 excluded, 0 errors,
2 favorites, 1 playlist and exact original typed key/value/list preservation.
The explicitly selected first-run No response added only
settings.shouldWeCheckUpdates=false; whole-map equality without accounting for
that action correctly failed, and the exact expected addition comparison passed.
Export SHA-256 b1811e90da8a1b4b9d0f3d941da82a453c02bc9d949f56bfe5dc6194bd9e7af7.
This is synthetic evidence, not real Samsung data acceptance or playback proof.

Bounded observations to review before production: overwriting a selected backup
under the same filename appeared to reuse the earlier picker payload; a distinct
filename restored the corrected synthetic fixture. Root cause is unproven.
An invalid playlist lookup also exposed a RenderBox/Sliver mismatch in the
error-screen branch of PlaylistPage. These were recorded, not silently passed
or expanded into unrelated engineering. Use a distinct export filename meanwhile.

## Recovery and retired work

Before cleanup, all 25 original branches, tags and 22 PR heads were bundled,
restored with identical refs and passed git fsck --full.
Task-local bundle: musify-source-comparison/repo-recovery-20261011/
musify-pre-cleanup.bundle (outside the checkout), 40,945,016 bytes.
SHA-256: 10eb04fe3319d31ac5bc6af08862f8c923ae0eb3524cdd10d9bdf75c325e325a.
Adjacent inventory/classification/proof records contain exact branch/PR heads.
Cleanup dispositions were verified after each authorized action.
PRs #4/#7/#19/#20/#21/#22 were closed unmerged with factual dispositions.
All 24 original non-master branches were retired with fresh guards and exact-SHA
leases after verified preservation. Fresh reconciliation proves only protected
master and agent/local-stable-consolidation remain, with only draft PR #23 open.
Master is unchanged; no tag, release or artifact was removed. The initially
rejected cleanup passed fresh review after explicit authorization; diagnostic
and transient DNS pauses were reconciled without repeating completed actions.
Exact retired heads and deferred #22 are indexed in REPO_RETIREMENTS.md.
No unique commits are discarded; #22 remains a roadmap reference, not an active
parallel candidate. Recovery instructions are in CONTRIBUTING.md.

## Single operating path

Runtime checkpoint: ee5ea7c93ecda846c7b3921dc6d134031b5e412d passed exact-source
CI 38131947201 (213 aggregate tests, 35 strict goldens and all build boundaries).
Its verified disposable debug APK was installed with byte-exact Hive
preservation. Native public playback now advances once per failed track and
stops at the failed tail after exactly three failures. Complete streaming still
fails: first ranges return 206, but the first nonzero 1 MiB range returns 403
for two independently checked sources. Probes stopped at denial. A third source
also truncates in native playback; independent 403 attribution is unproven.

Bounded follow-up observes just_audio stream-response completion errors using
a licensed local copy of the already pinned 0.10.6 package, cancels failed source
reads, stops native retries promptly, blocks replay of a known failed source,
and exposes a Library action with a sanitized error. Synthetic real-loopback
valid/truncated/disconnected tests and service stop/selection races pass.
Local analysis is clean and all 225 aggregate tests pass. All 35 Windows strict
goldens fail; comparisons are unchanged and exact Linux CI is required. No
provider access workaround, release or Samsung update has occurred. Runtime
and CI verification of this follow-up must be recorded against its committed SHA.

Read AGENTS.md and CONTRIBUTING.md; use debug.yml for Linux verification and
signed-release.yml only for separately approved release. Product vision/import
roadmap and VISUAL_SYSTEM.md remain useful design references. This map tracks
facts, not blanket permission. Next gates: verify current-head CI and full product
runtime/visual acceptance, exact signed in-place real-data rehearsal, reviewed
integration and publication, then conditional in-place phone acceptance.
