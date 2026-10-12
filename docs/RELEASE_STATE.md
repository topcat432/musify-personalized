# Musify Personalized current state

## Import subset routing verification, 2026-10-12

The owner approved I11 individual and newly resolved selectors for the current
version. The candidate preserves all/first-N modes, chosen alternate recordings,
source order, existing destination contents and staged import decisions. Newly
resolved compares source-row/recording identities against every resolved row at
the last successful confirmed transfer, including rows not selected then.
Legacy count-only audits and interrupted/unverified writes remain unknown;
explicit selection is available to establish a real baseline.

The additive versioned metadata is confined to existing import metadata maps;
there is no Hive adapter/schema migration or live-data operation. A pending
marker precedes destination writes, final tracking failure reports saved music
with unknown tracking, and matching/review checkpoints preserve newer routing
state. All 14 Hive-backed feature tests and four actual destination-page tests
pass; full analysis is clean and all 311 aggregate tests pass. Both unchanged
strict Windows visual suites fail. Deliberate destination changes were inspected
in before/after/diff images; reference Linux visual verification and exact-source
CI/native acceptance remain required. No golden or comparator was changed.

The takeover preserved all seven inherited dirty files at 251f5c43. The ignored
D05 native scratch source was preserved outside Git in the existing private
acceptance evidence directory so full analysis does not scan that rehearsal.
Protected master remains a7863235 and PR #23 remains draft. Provider completion,
physical acceptance and signed delivery remain held; no new provider request,
phone action, merge, signing or publication is authorized by these checks.

## Normal Search categories and owned background checkpoint, 2026-10-12

Normal Search now displays provider-typed songs under Songs / YouTube Music
and retains generic results under YouTube videos. A generic video is no longer
implicitly labelled a song. Only exact IDs already in the song category are
removed from the video category; unknown and long results remain discoverable.
There is no duration cutoff. Metadata, result order and explicit recording
choices remain intact. Generic lookup and unrestricted manual matching are
unchanged. A failed category does not discard the other category, and available
videos avoid repeated failed artist-song lookups. Existing lifecycle guards
cover both categories; no media transport, account or data schema changed.

All 13 actual-Search category/lifecycle checks, clean analysis and 294 aggregate
tests pass. The initial Windows aggregate run passed the 294 test assertions but
failed at shuffle-test Hive teardown with an OS file lock; the unchanged isolated
suite and aggregate rerun pass. Both strict Windows suites remain FAIL, with all
35 actual images byte-exact to the retained control. No goldens/comparator changed.
Exact Linux CI and native metadata runs are stamped separately to their source/APK;
these checks cannot establish provider listening or physical playback.

Retained normal-entrypoint source 5721bb181a9674e2a7ca16e4a0f062f734cfc1f0 passed
owned-file Home/background/screen-off queue advance and natural final pause on
emulator-5556. Native media-session dispatch paused at 26,501 ms, held position,
resumed the same item and paused at 29,975 ms while Android reported Asleep.
Input-key attempts were inconclusive and are not product-failure evidence.
Offline mode was restored to false, the app stopped and all three owned WAV
hashes retained. Only fixture recents/listening stats changed; all other keyed
values, original recents/order and non-fixture stats remain exact. Audibility,
focus, output accessories and complete provider playback remain unverified.

## Search lifecycle repair and native metadata verification, 2026-10-12

Search now rejects obsolete completions after a newer submission, input change,
clear or disposal. Old requests cannot replace current results, clear the current
loading indicator, touch disposed notifiers or continue obsolete artist fallback.
A new search clears the previous results so a failure cannot present old songs
under the new query. Existing metadata services remain the production defaults;
optional loaders keep the actual-widget lifecycle fixtures offline.

Four original lifecycle failures and the stale-results-on-failure case were
reproduced before repair. All seven lifecycle/fallback checks, clean analysis and
288 aggregate tests pass. Both strict Windows suites still fail; every one of
35 actual images is byte-exact to the retained control. No golden/comparator,
media transport, client identity, credentials or user-data schema changed.

Normal-entrypoint source 663f22dbf0d593f1496f6d89fbc1ba375404f8da was separately
rehearsed on owned emulator-5556: Search displayed real artists and songs without
a captured parser/search error. All four Hive files were byte-exact across the
in-place debug update; after metadata browsing, user/settings/offline registries
remain byte-exact and the only cache-value difference is one derived timestamp.
No song/preview/download was activated. This verifies metadata/UI, not provider
playback. Exact repaired source 5721bb181a9674e2a7ca16e4a0f062f734cfc1f0 passed
[Linux CI 38195882671](https://github.com/topcat432/musify-personalized/actions/runs/38195882671)
and normal-entrypoint native loaded results, clear and Library return. All four
Hive files remained byte-exact through that Search/navigation phase. Controlled
widget fixtures establish obsolete/disposed completion safety; native browsing
alone does not force those races. Later fixture-play changes are recorded above.

## Owner clarification and attribution correction, 2026-10-12

The owner is implementation-flexible, with avoidance of approaches risking a
YouTube account ban as the stated implementation constraint. The mission is to
restore the original listening result; engine/provider/routing may change while
preserving YouTube-primary preference, no subscription dependency, native queue
and background/screen-off playback, intended recording identity and all library
data. The boundary against evading verification/access restrictions is an
assistant execution constraint, not an owner-imposed no-spoofing rule. Unofficial
software or public protocols are not inherently classified as evasion.
See [decision D-015](DECISIONS.md#d-015---listening-outcome-and-execution-boundary-attribution).

This is a documentation correction only. Technical/native/CI evidence keeps its
original source stamp; provider recovery remains unproven. No media, account,
device, product-code or data action is part of this correction.

## Upstream remedy review and Search metadata correction, 2026-10-11

The actual PR 390 patch and linked alternatives use Apple/VISIONOS identity
substitution for their reported streaming remedy. That was not applied under
the assistant execution boundary against evading verification/access restrictions;
it was not an owner-imposed no-spoofing preference. Availability/header corrections
are already present; WEB/HLS hunks do not repair the captured fifth-range refusal.
Official Musify's related buffering PR 955 was merged then reverted; its current
cleartext-proxy correction is separate from this provider denial.

A small ordinary date-parser correction from the linked branch was isolated after
reproducing the retained Search FormatException. Compact streamed date labels now
leave an unknown optional date while retaining the full results. Four new offline
fixtures pass (three reproduced failures before repair); analysis and all 281
aggregate tests pass. Windows strict failures remain, with all 35 actual renders
exactly unchanged. Original headers, resolver identity, URLs, user-data schema and
terminal 403 handling are unchanged. The 0bcb90f1 / 4e9325d0 native evidence is
preserved; no new provider request, APK install or deployment occurred.
See [the source/patch review](YOUTUBE_UPSTREAM_REMEDY_REVIEW.md) for actual changes,
release status, reproduction limits and the protected boundary. The Search repair
is not a provider-completion pass; future roadmap and production gates remain held.

## Owned native pass and fresh provider denial, 2026-10-11

Runtime source 4e9325d07c0bd0fae4295e6c9226c1a6d904292c retains the production
transport correction from 54c3ed85 and adds only an isolated test entrypoint.
[Exact Linux CI 38179065225](https://github.com/topcat432/musify-personalized/actions/runs/38179065225)
passed analysis, 277 tests, 35 strict visuals, flavor boundaries and unsigned assembly.
On owned emulator-5556 / musify_rehearsal_api35, generated Opus/WebM passed full
70-second playback, 35-second seek, 68-second tail/completion and natural advance
through a full 8-second second file. Independent range inspection verifies every
first-file byte, a completed tail beyond 1 MiB and no source failure. No provider
was requested during the owned test; volume zero does not prove audibility.

After restoring the normal entrypoint, exactly one never-denied fresh recording
initialized native Opus and advanced, then the originating headers-phase response
was HTTP 403 for bytes 1048576-1310719 of a 5,108,604-byte source, after exactly
1 MiB delivered. The proxy source/responseDone chain retains the same origin;
synthesized runtime nativeCode is null. The URL was unexpired, its original
User-Agent has exact-URL provenance, and the resolver configuration was unchanged.
The owned app was stopped immediately, with no manual replay or denied retry.
This establishes that denial, not its account/IP/token cause or a global outage.
Complete provider listening/download/preview remains FAIL/BLOCKED.

All four normal Hive files were byte-exact through both owned runs and installs.
After normal browsing/playback, only search history, recents/listening stats and
eight derived cache additions changed. Every other user value, all settings,
usernobackup and original cache values remain exact; no keys were removed.
The normal app is installed and stopped on the owned AVD. No phone operation,
merge, signing/publication, deployment or migration ran. See
[AUDIO_TRANSPORT_DIAGNOSTICS.md](AUDIO_TRANSPORT_DIAGNOSTICS.md) for the native gate,
fixture setup correction, private evidence location and separate search parser failure.

## Originating audio failure evidence, 2026-10-11

Checkpoint 77f339a697e0a752db505d93cdf64f695c7fc023 passed exact
[Linux CI 38173114591](https://github.com/topcat432/musify-personalized/actions/runs/38173114591):
261 tests, 35 strict visuals, analysis, flavor boundaries and unsigned assembly.
Its normal fresh owned-emulator playback failed after Opus initialization; the
primary HTTP status was not retained. This does not prove a new 403. The app was
stopped at the first error with no manual replay; full-song/next-song remain held.

The follow-up preserves safe structured originating HTTP/range/body failures and
proxy completion chains. It fixes demonstrated valid Content-Range rejection
and prevents an already active read yielding bytes after another read fails.
Original URLs/agents and true-403 terminal handling remain unchanged. Diagnostic
fields exclude URLs, tokens, arbitrary header/body text and private metadata.
The old player code 0 can be synthesized by the app and is not HTTP evidence.
[Transport diagnostics](AUDIO_TRANSPORT_DIAGNOSTICS.md) records contract comparison,
offline fixtures and the specific next discriminating tests, which have not run.
Clean analysis and all 277 aggregate tests pass; 60 focused tests cover the
transport/provenance/runtime paths. Four private offline controls against the
preserved 77f339a6 source reproduce the old defects. Both strict Windows suites
still fail all 35 images; 33 images exactly match the retained unchanged-source
control, with the two About differences confined to prior identity/version fixture
labels. Representative expected/actual/diff images were inspected. No goldens or
comparator changed. Exact Linux checks on the new source remain required.
No phone install, deployment, data migration or new public-media request occurred.

Recorded 2026-10-11. This is the living map; verify current GitHub heads/runs
and connected device identity before relying on dated observations.

## Header provenance and independent upstream comparison, 2026-10-11

The last committed checkpoint is f8702efee24711aa2e40f95f3ff61eef447a982b.
Its exact [Linux CI](https://github.com/topcat432/musify-personalized/actions/runs/38165158295)
passed analysis, 253 tests, 35 strict visuals, flavor boundaries and unsigned assembly.
The follow-up repair preserves the User-Agent from the existing resolving request
through manifest/length probes, downloads, native playback and exact-URL derived
cache contexts. It changes no client profile or authentication, forwards no session
credentials and keeps real HTTP 403 terminal. Unknown/partial cache contexts are
retained but never assigned a guessed identity. No user-data schema changes.

Local analysis and all 261 tests pass, including eight new provenance fixtures and
restart coverage. Both unchanged strict Windows suites still fail their 35 images;
the current render artifacts are compared against the retained source control.
No goldens or comparator were changed. Exact Linux checks for this follow-up and
a native complete-provider pass remain required.

Official upstream 10.5.3, source a5edc73c501aea5428b419ec14eaa46bc2fef83e,
was separately installed on the task-owned musify_rehearsal_api35 emulator.
Startup ANRs preceded playback and recovered after the host reboot and normal
Wait action. One fresh normal source selection then failed natively because
Android rejected cleartext HTTP to 127.0.0.1, used by upstream's header proxy.
The app was stopped after the error. This independently confirms a local upstream
transport defect; it does not establish a global YouTube failure or candidate
playback recovery. The fork uses supported native URI headers while preserving
its existing GitHub-only bounded-source loopback allowance. No security policy,
phone installation, signing, publication or merge changed.

## Playback compatibility investigation, 2026-10-11

Checkpoint 70b96f8e93e319da9ccdac4a284788a6e5d77f50 remains recoverable.
The selected Samsung is available again; its unchanged preview APK has the
previous recorded hash and source stamp. A normal baseline online attempt
failed at manifest availability (HEAD, stream 313). Existing downloaded audio
completed and naturally advanced; background/screen-off playback remained active.
Playback was paused and Offline Mode restored to false. This validates baseline
local behavior, not candidate physical acceptance or audible output.

Retained candidate URL metadata rules against expiry at the recorded failures:
the two URLs expired after 14:26 UTC, while failures occurred before 10:07 UTC.
Signed query strings are unchanged; ranges fit their declared sizes; neither URL
contains an n challenge. A service requirement on the anonymous media-delivery
path is the leading remaining hypothesis, not a proven account/IP/token cause.
The upstream PR #390 discussion independently reports a similar initial-buffer /
later-range failure. Its proposed identity switching to avoid verification
was excluded by the assistant execution boundary, not an owner preference.

Scoped compatibility changes replace the fresh manifest HEAD preflight with a
one-byte GET, cancel its response body, and treat genuine 403 as terminal without
client fallback or download URL refresh. A retained same-URL HEAD 403 / GET 206
pair justifies the method correction. Download requests also use uppercase GET
and clamp their range to the remaining file length; those defects were reproduced
by the owned 16-byte fixture. The native bounded transport already did both, so
these downloader corrections do not explain its earlier mid-song failure.

Local analysis and all 253 aggregate tests pass, including eight new extractor /
download fixtures. Both strict Windows visual suites retain their prior bounded
rendering failures; no goldens/comparator changed. Exact Linux CI is required;
read the current source-pinned checks on PR #23 for its result.
No denied media was requested again, no credentials or
security settings changed, and no new native complete-provider playback pass is
claimed. See PRODUCT_ACCEPTANCE.md for hypotheses and supported integration
options. Merge, signing, publication and live installation remain held.

## Prior local acceptance checkpoint (70b96f8e)

Sole candidate remains draft PR #23. Latest tested code is
769d60f404f7b7ad041a6708916dec194574c831; protected master remains
a786323556275a0de745ffca4d3affc088ac2055. Clean local analysis and all 245 tests
pass. Both Windows strict visual suites still fail with the previously bounded
text-rendering differences; no goldens/comparator were regenerated or weakened.
Reference CI is [38145671652](https://github.com/topcat432/musify-personalized/actions/runs/38145671652).
It completed SUCCESS: 245 tests, both strict Linux suites (35 images), all
debug/F-Droid boundaries and unsigned release assembly. Prior exact a3f12e89 CI
[38143273232](https://github.com/topcat432/musify-personalized/actions/runs/38143273232)
passed 241 tests, 35 strict Linux images, debug/F-Droid boundaries and unsigned
release assembly. CI builds are not signed updates.

The latest verified disposable debug APK has SHA-256
ccf2c8d9fb0a6e4c1ad08e8774e1c690ae1255cd466c1f46cf1a1032a877024a,
package com.topcat432.musifypersonalized.preview.debug, code 300000002 and an
embedded exact 769d60f4 source stamp. Both recent owned-emulator in-place
updates preserved all three synthetic Hive files byte-for-byte before launch.
No Samsung update occurred. Private evidence stays outside Git under
musify-source-comparison/emulator-rehearsal; see runtime-debug-769d60f4-proof.json
and 769d60f4-install-preservation-proof.json.

Three additional native defects were reproduced and repaired: destination refresh
expanded an approved first-N count to all resolved songs; deleting a folder from
its nested page popped the root shell and left a blank screen; offline Library
showed undownloaded custom playlists and hid its local-song entry. Actual-widget
regressions and durable import/cleanup/settings/updater fixtures cover the fixes
and scope boundaries. First-one confirm/refresh/review passes natively on a3,
and full Android reboot preserves every Hive byte and selected/excluded state.
The folder repair passes natively on 58f1edbb; downloaded-only Library and
local Offline/Recents playback pass on 769d60f4. Final full Android reboot
preserves all three Hive bytes. Independent closure-final-preservation-proof.json
retains exact original playlists/likes/imports/results/selected/excluded state
and nine settings, explicitly accounting for routing audits, local playback
Recents/stats, selected High quality, empty generated-folder/pin keys and three
owned fixture cache entries. No provider download is represented by that cache.

PRODUCT_ACCEPTANCE.md now reconciles all 38 matrix rows with named A/E/D/R
subgates; chronological pending/failure prose below it is historical. All 28
safe rows have bounded local or fixture evidence; that does not turn online,
physical-output or exact signed-release subgates into passes. Complete provider
listening/download/preview remains FAIL/BLOCKED after the observed later-range
403; no denied media was requested again. Selected Samsung availability,
physical focus/output/accessories, the I11 subset-delivery scope decision and
exact signed in-place rehearsal remain prerequisites. Master, signing,
publication and live-phone changes stay on hold.

The earlier checkpoints below retain source/data/channel history. Treat their
old test counts and pending repair statements as historical supporting evidence;
the current checkpoint and reconciled matrix supersede them.

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
and exposes a Library action with a sanitized error. This repair is committed
at d3d353fc1a2ac5483ffb0a74048513b2de7318b1; exact CI 38134013870 passes all
225 aggregate tests, 35 Linux strict goldens and all build boundaries. All 35
unchanged Windows strict goldens fail; inspected differences concentrate in
text rendering. Disposable native damaged-local-file error and Library action
pass, then the original WAV hash is restored and selecting healthy local audio
clears the error. This does not prove native denied-source handling or complete
external streaming. No provider was requested again.

The same native local-control check reproduced two existing defects: zero seek
reports position 0 to Android but leaves 00:09 on the slider, and completed-tail
Replay seeks zero but remains paused. A bounded follow-up updates zero/duration
states without retaining a previous widget's global position and resumes the
healthy Replay through the existing play handoff. Automated and native checks
must pin this follow-up's exact committed SHA. No release/Samsung update occurred.

Read AGENTS.md and CONTRIBUTING.md; use debug.yml for Linux verification and
signed-release.yml only for separately approved release. Product vision/import
roadmap and VISUAL_SYSTEM.md remain useful design references. This map tracks
facts, not blanket permission. Next gates: verify current-head CI and full product
runtime/visual acceptance, exact signed in-place real-data rehearsal, reviewed
integration and publication, then conditional in-place phone acceptance.
