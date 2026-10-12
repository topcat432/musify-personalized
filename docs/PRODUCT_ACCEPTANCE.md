# Product acceptance ledger

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

## Exact request context and upstream result, 2026-10-11

An owned fixture demonstrated that the resolving player request used one
User-Agent while media preflight used a generic browser agent. The scoped repair
carries only that existing public transport header, with original stream-object
or exact-URL cache provenance. It preserves signed URLs, client configuration,
selected recording/source order and terminal 403 handling. Legacy, partial,
ambiguous and credential-bearing cache contexts are not guessed; originals remain
retained. Eight new fixtures cover complete finite ranges, downloader/preflight
headers, length discovery, cache restart and a permitted refresh followed by a
transient retry. Analysis and all 261 local tests pass. This proves propagation,
not sustained provider access.

The verified official upstream 10.5.3 APK reached normal search after an emulator
startup ANR recovered. One fresh playback selection failed on Android's local
127.0.0.1 cleartext restriction, independently reproducing the header-proxy issue
reported in [upstream #983](https://github.com/gokadzev/Musify/issues/983).
That local failure is distinct from the retained candidate's server-side 403.
Complete candidate listening/download/preview and physical acceptance remain held;
there is no new complete-provider pass. Premium-dependent Spotify playback remains
excluded: Free companion/context capabilities do not guarantee on-demand playback
of the same recording. Existing export/file import remains independent of Premium.

## Playback investigation update, 2026-10-11

The prior 70b96f8e checkpoint remains preserved. The selected Samsung baseline
received a HEAD-stage manifest 403 before decoding; an existing downloaded file
completed and advanced naturally. Background/screen-off session behavior was
observed, then playback paused and Offline Mode restored to its original false.
This is baseline evidence, not a candidate physical pass. Audible output,
accessories and competing audio focus remain unconfirmed.

Ranked hypotheses and discriminating evidence:

1. **Anonymous media-delivery requirements (leading inference).** Candidate
   Opus streams decoded initially, then a retained finite-range request received
   403 with declared zero body length. An [upstream engineering report](https://github.com/Hexer10/youtube_explode_dart/pull/390)
   describes a similar initial-buffer / later-offset failure and attributes it
   to proof-of-origin requirements. Our retained response does not identify the
   exact cause: full response headers, provider reason text and native per-chunk
   request timestamps were not captured. Do not call this proven provider-wide,
   account, regional or IP blocking. The proposed upstream patches #388-390 use
   alternate identities to avoid verification and were excluded by the assistant
   execution boundary, not by an owner-imposed implementation preference.
2. **HEAD preflight mismatch (demonstrated compatibility defect).** The retained
   same-URL probe has HEAD 403 and bounded GET 206. Fresh manifest resolution
   still used HEAD on the first stream, potentially a video stream rather than
   the selected audio. The scoped correction uses one-byte GET with the same
   URI, cancels the body and makes genuine GET/player/download 403 terminal.
   This addresses preflight behavior, not sustained delivery. A small successful
   range still does not certify the entire recording; a preflight may consume a
   provider request allowance and must be evaluated on a permitted source.
3. **Expiry/query/range/decoder defects (lower for the native failure).** Both
   retained candidate URLs were valid for over four hours after their cache
   timestamps and until after 14:26 UTC; failures were before 10:07 UTC. Query
   strings survive URI/request construction exactly, contain signatures, and
   have no n challenge. Observed ranges fit the declared file lengths; initial
   Opus decoding and local natural advancement weaken a universal decoder issue.
   Downloader fixtures separately exposed lowercase get and an unclamped
   10 MB request on a 16-byte source; both are corrected. The native bounded
   source already used uppercase GET and clamped ranges, so those corrections
   cannot be presented as its root-cause repair.

Eight new fixtures verify exact request method/query/range, body cancellation,
terminal denials, complete byte delivery and next-source delivery. Local analysis
and all 253 aggregate tests pass. Both Windows strict visual suites retain their
prior bounded failures; exact Linux strict CI remains the reference gate.
Native full-song/next-song acceptance still
needs a permitted complete source. No previously denied media is requested again.
If such a permitted attempt is approved later, capture its initial request shape,
clock/expiry, range, status, safe response headers and bounded reason metadata;
stop on its first real denial. Do not retrofit missing observations into old logs.

Supported integration choices require an owner decision rather than new cookies:

- **YouTube visible player:** the [IFrame API](https://developers.google.com/youtube/iframe_api_reference)
  supplies playback/queue/end events through the provider's player. An Android
  WebView must identify Musify using its real app ID as described in
  [embedded-player identity requirements](https://developers.google.com/youtube/terms/required-minimum-functionality).
  Public playback does not inherently require an OAuth account, while Data API
  search needs a registered Google project/key. This is feasible for a visible
  player, with minimum viewport 200x200, provider ads/restrictions and foreground
  viewing. [Developer policies](https://developers.google.com/youtube/terms/developer-policies)
  exclude separated audio, background players and unauthorized downloads; adding
  a Data API key or Premium account does not supply a raw-audio integration.
- **Spotify companion/control backend:** register an Android developer app,
  client ID, redirect URI and Musify package/fingerprint; user installs/signs in
  to Spotify and grants app-remote-control. [Android SDK setup](https://developer.spotify.com/documentation/android/tutorials/getting-started)
  controls playback in Spotify, with state subscription/next/seek adapters in
  Musify, rather than providing extractable audio. Web API control additionally
  uses user-read-playback-state and user-modify-playback-state; its
  [play endpoint](https://developer.spotify.com/documentation/web-api/reference/start-a-users-playback)
  requires Premium. Mobile [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow)
  avoids embedding a client secret. Current [development mode](https://developer.spotify.com/documentation/web-api/concepts/quota-modes)
  requires a Premium app owner and allows up to five allowlisted users, fitting
  a personal prototype. This adds account/service dependence and catalogue
  matching; provider audio stays in Spotify, and Musify cannot treat it as its
  own downloadable cache. Local file/CSV import remains independent.
- **Owned/licensed local or HTTPS media:** keeps the existing background player
  model without a service account, but broad commercial catalogue playback needs
  a licensed provider agreement or user-owned files. Arbitrary HTTPS media needs
  an explicit provider/source adapter and product approval; synthetic byte tests
  are engineering evidence only, not a replacement catalogue or live release.

No integration above is enabled, registered, authorized or deployed by this work.
Complete provider playback remains FAIL/BLOCKED; deployment holds still apply.

Scope recorded 2026-10-11 for the single canonical candidate, PR #23. This is
an execution ledger, not a claim that every row has passed. Pin the tested SHA,
APK hash/package/signer, device, fixture/export hash and evidence for each run.
Keep private exports, device serials, images and music metadata outside Git and
Library. A passing unit test is not a runtime or real-data pass.

## Owner intent and scope

Current scope: existing Home/Search/Library/Settings/playback/download/offline
surfaces plus implemented CSV import, resumable matching, permanent unresolved
review/manual matching, explicit destination routing, exclusions, streamed
backup/recovery and verified updater. Stabilize the current visible product.

Owner sources retrieved by the parent (historical requirements, not test proof):

- [Current full-app acceptance request](https://chatgpt.com/c/6a546a11-7290-83ea-8b12-3e8c3912dac4?messageId=6ea97cc3-2876-4d30-8ec6-0f25735e513c).
- [Permanent unresolved access](https://chatgpt.com/c/6a546a11-7290-83ea-8b12-3e8c3912dac4?messageId=bbb21ab7-b2d7-46dc-96ed-390313a99c02).
- [Unrestricted manual source search](https://chatgpt.com/c/6a546a11-7290-83ea-8b12-3e8c3912dac4?messageId=bbb2194e-fdd7-473e-a3ac-9dc2c8653330).
- [Quick Review](https://chatgpt.com/c/6a546a11-7290-83ea-8b12-3e8c3912dac4?messageId=bbb21c40-d746-4b15-9504-7d45cc43b8bd).
- [Permanent Exclude approval](https://chatgpt.com/c/6a546a11-7290-83ea-8b12-3e8c3912dac4?messageId=fc747825-b33d-5e16-84c0-d08db7f0e11e), [follow-up](https://chatgpt.com/c/6a546a11-7290-83ea-8b12-3e8c3912dac4?messageId=bbb21d06-74f5-4102-ae21-124c77adac2f).
- [Destination selection](https://chatgpt.com/c/6a546a11-7290-83ea-8b12-3e8c3912dac4?messageId=bbb21516-1fdc-4b47-8d5c-fcaa1de394fd).
- [Artwork-led visual intent](https://chatgpt.com/c/6a546a11-7290-83ea-8b12-3e8c3912dac4?messageId=f50448f8-2c15-5fa3-be94-3b11f6a033db), [approval](https://chatgpt.com/c/6a546a11-7290-83ea-8b12-3e8c3912dac4?messageId=86b6098b-3cec-4ffd-a141-a73fc29775a0).
- [Playback corrected triage](https://chatgpt.com/c/6a57147c-6ba4-83ea-8e20-75d1b90cd82c?messageId=5fb2931c-7622-4223-a166-3dceadb3d2bb).

Superseded interpretation: No match is reopenable, unresolved items do not block
routing resolved items, and only explicit Exclude removes an item permanently
from review/rescue/routing. A selected YouTube URL is only a lookup hint; persist
the normal song and ytid, not a raw stream URL. Historical 2,643 imports versus
2,454 likes is not loss without explaining unresolved, exclusions and duplicates.

Deferred future scope (do not implement or call shipped during stabilization):
playlist-aware ZIP/JSON/CSV/TSV/repeat synchronization and file share intents;
optional Spotify PKCE; canonical multi-source/library intelligence; local/server
lossless; taste/DJ/AutoMix/Music Atlas/radio similarity; Android Auto. #22's
Home/shell work is recoverably deferred. PRODUCT_VISION and the import roadmap
describe ambitions beyond delivered scope.

Selection ambiguity: current destination code exposes all/first-N. The roadmap
also promises individually selected/newly resolved subsets; their delivery stage
requires an owner-scope decision before treating their absence as a current bug
or silently representing them as implemented.

## Evidence levels and release gate

Use PASS/FAIL/UNTESTED/BLOCKED separately for A (automated), E (disposable Android),
D (selected Samsung), R (exact signed release/in-place). Add file/log/image/clip
references and the exact run. CODE is implementation observation only. A green
golden with placeholder art does not prove actual artwork, scrolling or playback.
Do not test external sharing/purchases by sending/ordering; inspect entry and
cancel safely. Do not destructively mutate live data or rerun completed matching.

Before integration/sign/install, report exact candidate SHA and this ledger to
the parent, with known limitations and the existing signed-release workflow.
Conditional deployment authorization applies only after the required backup,
restore, product, visual and signing conditions are satisfied. It does not permit
secret reads, new credentials/security permissions, unsafe downgrade, uninstall,
clear-data, live restore or unexplained data loss. Never assert zero undiscovered
bugs or exhaustive coverage without traceable evidence.

## Feature, screen, button and pathway matrix

Current reconciliation dated 2026-10-11. PASS applies only to the named subgates,
not automatically to every acceptance clause. All 38 rows have evidence or a
specific prerequisite. The 28 safe rows have local/fixture evidence; complete
provider, physical-device and exact signed-release subgates remain separate.
D/R HOLD means D BLOCKED for current full-product phone acceptance (selected
Samsung unavailable) and R BLOCKED by product/signing/in-place release gates.
D01/D02 retain their already completed phone identity/export evidence.

Current automated code: 769d60f404f7b7ad041a6708916dec194574c831, analysis clean,
245 aggregate tests PASS. Reference Linux CI is
[38145671652](https://github.com/topcat432/musify-personalized/actions/runs/38145671652),
completed SUCCESS: 245 tests, both strict suites (35 images), debug/F-Droid
boundaries and unsigned release assembly.
The prior exact a3f12e89 code passed
[38143273232](https://github.com/topcat432/musify-personalized/actions/runs/38143273232),
including 241 tests, 35 strict Linux images and all APK/channel boundaries.
Windows strict comparisons remain FAIL; goldens/comparator were not weakened.

Evidence root outside Git: musify-source-comparison/emulator-rehearsal.
Current native first-N/reboot source a3f12e89a0c0c2be9bbf6d0965ac797209f83aec:
APK 7f5bb1a4346abb20a42e13ce25bd58260fefe261d441eb48b5a59bda74bd59ae,
isolated .preview.debug, code 300000002, task-owned API 35 AVD. Previous runtime
sources are explicitly qualified in the historical checkpoints below: 49d17310
(controls/repeat), bc702978 (source-error UI), 5da26d94 (paused snapshot/settings).
Unchanged backup evidence at 2f61715e is retained rather than rerun needlessly.
No current live-phone or production-signer rehearsal is represented by these APKs.

| ID | Screen / entry / action | Acceptance, including repeats and errors | Current level/status and remaining subgates | Implementation / automated reference |
|---|---|---|---|---|
| D01 | Installed app and About | Retained .preview, actual Android version/code/signer; no hardcoded identity | D PASS package/version/signer/APK hash and export source stamp; historical CI artifact expired; R HOLD | installed_app_identity; about_page |
| D02 | Settings → Create verified backup → local SAF Save | Preserve live data; validate actual saved bytes, schema, both boxes, inventories, semantic values | A/D PASS saved real export and independent typed inventory; owner confirms empty library; R HOLD | musify_backup_service; backup service tests |
| D03 | Disposable Restore → review → confirm | Exact real-data counts/order/selected identities/exclusions/settings; rollback and reopen | A PASS validation/rollback; E PASS real export restore on 26bd; live restore excluded; R HOLD | backup service / validated summary tests |
| D04 | Full Android restart → native re-export | Independent exact keyed semantics; explain every legitimate change | E PASS real restore/reboot/re-export exact typed semantics on 26bd; synthetic full reboot a3 also byte-exact; D/R HOLD | manual backup_rehearsal tool |
| D05 | Interrupted/corrupt/repeated/same-name backup selection | Reject corrupt/partial safely; recover rollback; newly selected bytes stay fresh | A PASS corrupt/partial/rollback; E PASS same-name 2/1/2 on unchanged backup implementation at 2f61715e; D/R HOLD | backup service tests; Android file picker |
| P01 | Liked Songs row / Play / Shuffle | Full list, real track completion advances with repeat off; replacement queue keeps shuffle | A PASS queue/shuffle fixtures; E PASS controlled local queue; complete provider listening FAIL/BLOCKED; D/R HOLD | user_songs_page; audio_service; queue_retry_utils |
| P02 | Playlist / Offline / Recents Play and row tap | Correct full source/order/start index; selected source not silently substituted | A PASS source/order/start-index fixtures; E PASS controlled playlist, offline/recents local entries; sustained provider playback FAIL/BLOCKED; D/R HOLD | playlist_page; user_songs_page |
| P03 | Now Playing / mini-player seek, pause, previous, next | State/position synchronized; rapid input bounded; long titles don't overflow | A PASS error ownership, zero/duration, paused snapshot, rapid-input fixtures; E PASS 49d controls, bc error, 5da paused duration; D/R HOLD | now_playing; mini_player; audio_service |
| P04 | Queue / Shuffle on then off | Natural order restored; current track retained; Play Next survives | A PASS manual-entry shuffle/restoration; E PASS 9f92 current retained, natural order restored and Play Next insertion/replacement; D/R HOLD | audio_service / shuffle state tests |
| P05 | Track completion / failed stream / retries / repeat off-one-all | Advance once; no replay of failed tail; repeat modes intentional; healthy playback not hung | A PASS stop/stale/three-failure/repeat; E PASS 49d healthy Replay and repeat one/all, natural tail pause; provider terminal callback remains BLOCKED; D/R HOLD | audio_service playback retry / queue_retry_utils tests |
| P06 | Background/screen off/audio focus/output reconnect | Resume/control correctly, avoid duplicate playback; record attached speaker/wired/BT coverage | E PASS owned 5721 screen-off queue completion and native media pause/hold/resume; audibility/focus/accessories unverified; D BLOCKED selected phone/output accessories unavailable; R HOLD | audio_service; Android audio session |
| I01 | Library → Import CSV → pick/inspect/cancel/replace | Valid rows/provenance retained; no implicit likes changes; failed replacement retains old session | A PASS parser/provenance/session replacement; E PASS native CSV picker Cancel at 5da; no replacement or matching rerun; D/R HOLD | spotify_csv_importer; import_session tests |
| I02 | Matching start/pause/resume/reopen/error | Checkpoint progress; don't redo resolved tracks; fallback failure retains structured candidates | A PASS checkpoint/cancel/resume/error; E PASS completed 4/4 checkpoint and current restart retention; D/R HOLD | track_matching / scoring tests |
| I03 | Matching summary → No match / Review / Errors | Permanent reopen without restarting 2,643 rows; unresolved remains after routing | A PASS reopenable No match/errors after routing in durable fixture; E PASS completed/empty review access without restart matching; D/R HOLD | matching_page; review_workflow tests |
| I04 | Quick Review entry / artwork / preview / Accept / No match / Later / manual | Discoverable artwork-led cards; 12s preview; equivalent buttons/swipes; save before advance | A PASS actual review widgets/swipes/prefetch; E PASS review entry/empty return and prior decision persistence; complete online preview BLOCKED; D/R HOLD | review_sprint_page / swipe_deck tests |
| I05 | Detailed/manual YouTube and YT Music search | Show scorer-rejected results with warnings; artwork/metadata/preview; explicit correct recording | A PASS manual unrestricted candidates/warnings/scoring/exact choice; E persisted selected public alternate; complete preview BLOCKED; D/R HOLD | manual_match_page; manual_source tests |
| I06 | Exact YouTube/YT Music URL → confirmation | Resolve normal song+ytid; preview before save; invalid/private/deleted fails without mutation | A PASS exact ID/oEmbed/denial/timeout/no raw-stream persistence; E selected exact URL decision retained; complete preview BLOCKED; D/R HOLD | manual_source / review_workflow tests |
| I07 | Accept alternate → route → audit → reopen | Exact selected alternative survives all checkpoints and restart | A PASS selected alternate -> route/audit -> Hive reopen; E PASS exact selected IDs and audit survive a3 full reboot; D/R HOLD | spotify_import_persistence_test; closure-full-reboot-proof.json; closure-after-reboot-inventory.json |
| I08 | Exclude → exact confirmation → repeated review/restart | Preserve source row/audit; drain all review/rescue/totals/destinations; retain existing likes | A PASS explicit exclusion/source/audit/backup/reopen; E PASS all four source rows and excluded outcome survive reboot; D/R HOLD | spotify_import_persistence_test; review/backup tests; closure-after-reboot-inventory.json |
| I09 | Choose Destination all/first-N → liked/existing/new → preview/confirm | Correct counts/source order/dedupe; success after durable write; partial unresolved stays staged | A PASS all/first-N to liked/new/existing with source order; E PASS a3 first-one amount retained after confirm/refresh; earlier 5da expansion FAIL repaired; D/R HOLD | spotify_import_destination_page_test; spotify_import_persistence_test; private-ui/closure-a3-first-confirmed and closure-a3-first-repeat-review |
| I10 | Retry routing / stale session / empty selection / restart | Idempotent; no uncontrolled duplicates/deletion; reject stale/empty safely; destination history retained | A PASS empty/stale target rejection and reopened idempotence; E PASS a3 repeat still 0 new/1 existing and no duplicate library change; D/R HOLD | spotify_import_persistence_test; private-ui/closure-a3-first-repeat-review; closure inventory proof |
| I11 | Individually selected/newly resolved subsets | Determine whether current delivery promise or later roadmap; do not invent completion | CODE absent; A/E BLOCKED owner delivery-scope decision, not a shipped subset-selection feature; D/R HOLD | import roadmap §4; current selectSongs(first-N) |
| L01 | Library → favorites / playlists / folders / pinned / artists | Membership/counts/order/filter persist; no silently missing real content | A PASS folder filtering/liked models; E PASS generated folder/member/pin plus original membership across full reboot; D/R HOLD | library_page; playlists_manager |
| L02 | New/edit/rename/delete playlist/folder, cancel, repeat | Changes only disposable data; cancellation safe; duplicate/empty validation; restart persists | A PASS nested-navigation Cancel/Delete and child retention/reopen; E PASS create/rename/move/pin/unpin/validation/delete Cancel; E PASS repaired folder Delete returns to Library on exact 58f1edbb APK; D/R HOLD | playlist_folder_page_test; closure-folder-navigation-before/after.log; private-ui/closure CRUD captures |
| L03 | Playlist unavailable/empty/loading → Back | Readable error/empty state, no RenderBox/Sliver exception or stranded navigation | A PASS unavailable/empty widget regressions; E PASS generated empty-folder entry/Back; provider unavailable state represented by local source-error fixture; D/R HOLD | playlist_page; EmptyPlaylistState |
| L04 | Share/import/export links | Correct entry/preview/cancel; no external sends without explicit authorization | E PASS local share-link copy, no external send, CSV SAF entry/Cancel; CODE compact link expansion uses metadata service; live recipient delivery excluded; D/R HOLD | playlist_sharing; playlist_bar |
| S01 | Search query/suggestions/history/result/artist/album/playlist | Real loaded artwork/text, relevant playable result, empty/failure/cancel; offline behavior clear | A PASS search/artist/playlist visual fixtures; E PASS native query/suggestions/keyboard Back and offline local navigation; complete playable provider result BLOCKED; D/R HOLD | search_page; artist/playlist route services |
| O01 | Download song/playlist → Offline → play/remove/cancel | Correct file/state, interruption/retry bounded; real offline playback; no misleading quality claim | A PASS cleanup shared-file ownership and durable registry scope; E local synthetic file playback only; complete provider download/play BLOCKED; D/R HOLD | offline_cleanup_persistence_test; closure-offline-cleanup.log; controlled-audio sessions |
| O02 | Offline switch → navigation/search/local lists | Downloaded-only sources usable; clear empty state; toggle back restores navigation | A PASS offline placeholder/folder filtering; E PASS 5da three/four-tab toggle and local-file controls; E PASS 769d60f4 downloaded-only Library, Offline Songs entry/3-song Play/pause, online restoration and full reboot; D/R HOLD | router_service; offline_search_placeholder |
| T01 | Settings themes/quality/shuffle/repeat/update/preferences | Every visible toggle uses correct key; reversible settings persist after restart | A PASS theme/audio shuffle/repeat fixtures; E PASS quality Low/Medium/High restored to High, full settings-byte restart retention; provider/proxy/security changes excluded; D/R HOLD | settings_manager; settings_page |
| T02 | Cache/history/recents/stats/download clear dialogs | Correct scope/confirmation/cancel; execute only on disposable state | A PASS all clear-dialog Cancel, history/recents/stats confirmed scope after reopen, owned offline cleanup; E PASS native history Cancel; originals retained; D/R HOLD | settings_data_scope_test; offline_cleanup_persistence_test; closure-settings-scope-final.log |
| T03 | Equalizer/lyrics/listening recap/Time Machine | Correct entry/data/empty/error; don't imply unsupported features; no crashes | A PASS recap and disabled/empty Time Machine fixtures; E PASS Equalizer entry/Back and synthetic Lyrics unavailable; E PASS native Time Machine current-month recap entry/Back at 58f1edbb; no external share; D/R HOLD | equalizer_page; lyrics; time_machine_page |
| T04 | About/licenses/translation/sponsor | Accurate identity/upstream attribution; working safe entry/Back; no external action/purchase | A PASS actual About identity widget; E PASS About debug version/upstream attribution, Licenses/Back, translation/sponsor entries inspected without sends/purchases; D/R HOLD | about_page; settings_page |
| U01 | Check personalized update / current/error/invalid manifest | Exact retained package/pinned signer/hash; reject legacy/debug/unsigned/wrong identity; sensible UI | A PASS 14 updater rejection checks incl. old/debug identity, checksum, interrupted body and inspection failure; E PASS disallowed manifest rejection/dismiss with no install; D/R HOLD | personalized_update_service_test; personalized_update_dialog_test; closure-updater-rejection-final.log; private-ui/closure-updater-result |
| U02 | Signed workflow + disposable in-place rehearsal | Exact default tip; monotonic version; v2/v3/pinned signer/hash; real-data survives | A PASS production workflow/channel/invalid-artifact boundaries; CI unsigned builds only; R BLOCKED exact signed in-place rehearsal and full product gates | signed-release.yml; RELEASE_SIGNING |
| U03 | Samsung in-place install → APK re-extract/data inventory/smoke | No uninstall/clear/live restore; exact artifact and persisted real data; daily critical paths | D/R BLOCKED phone unavailable and signed/product release gates; no live install/restore/uninstall/clear-data | explicit approved release/install evidence |
| V01 | Real artwork / long labels / compact + large text / themes | Artwork-led; no Aquaz3y/orbit/KEEP-NOPE branding; readable, no clipping/overflow | A Windows strict FAIL unchanged text-rendering differences; Linux 769d60f4 all 35 strict PASS; E real-artwork/long-label evidence plus readable native screens; D/R HOLD | VISUAL_SYSTEM; both strict visual suites |
| V02 | Scroll/keyboard/mini-player/safe insets/back/rapid gestures | No obscured controls, trapped overlays, stale views or lost decisions | A PASS actual review, error/text-scale and slider widgets; E PASS keyboard, content scroll, safe Back, paused mini-player; folder-delete root pop FAIL repaired with A proof and native 58f1edbb Library return PASS; D/R HOLD | actual screen recordings + widget regressions |

## Current closure findings

The first-N destination refresh silently reset 1 to all 3 after a transfer on
5da26d94. The generated playlist then gained the other 2 after explicit second
confirmation; this is defect evidence, not a passing first-one repeat. a3f12e89
preserves the approved count and clamps only if available songs shrink. The
actual widget regression and native confirm/refresh/review all retain 1; the
repeat preview remains 0 new and 1 existing, and was cancelled.

Native folder deletion from inside its page popped the root shell and produced
a blank screen on a3f12e89. The nested-navigation regression reproduces missing
Library before the fix and passes on 58f1edbb. The repair dismisses the root
dialog, then pops the folder page's Library navigator. It preserves child
playlists, with Cancel/Delete and Hive-reopen checks. Native 58f1edbb Delete returns to the Library branch with all four tabs;
Cancel and child retention remain covered by the actual-widget/Hive regression.
Generated-fixture cleanup is independently proven in the final inventory.

New durable fixture coverage exercises the actual import/review/destination
services: accepted alternate identity, original source order, reopenable No
match/error, explicit exclusion, all/first-N liked/new/existing targets, audits,
idempotence, stale/empty rejection and independent Hive reopen. Offline cleanup
proves exclusive files are removed while shared/liked/custom-owned files remain;
Delete Downloads leaves library/import/settings state intact. Actual Settings
widgets prove clear-dialog Cancel and confirmed history/recents/stats scope.
Updater tests reject old/debug package identities, corrupt/interrupted bytes and
Android-inspection failure, cleaning partial APKs before any install affordance.

The a3 native in-place update and full Android reboot preserve all three Hive
files byte-for-byte before launch. Boot IDs differ; the reopened Library retains
the generated folder/member/pin, original three playlists, five likes, four
imports/results and selected/excluded outcomes. Quality is explicitly High.
Evidence: a3f12e89-install-preservation-proof.json, closure-full-reboot-proof.json,
closure-after-reboot-inventory.json and private-ui/closure-a3-reboot-*.

The final code 769d60f4 also repairs offline Library filtering: root custom
playlists obey the same downloaded-playlist rule as folders/pins, stored online
content no longer hides the offline empty message, and local-only songs retain
the existing Offline Songs entry. Three actual-widget regressions pass without
mutating stored playlists/folders. Native exact-APK Library hides the three
undownloaded custom playlists and opens the three synthetic local songs; Play
has queue size 3 and pauses at 8.982 seconds. Returning online restores all four
tabs and original playlists. A Recents row plays only the selected local tone
in its six-item source queue and pauses at 14.909 seconds before public rows.
Evidence: closure-offline-library-before/after.log, private-ui/closure-final769-*,
controlled-audio/closure-final769-offline-* and closure-final769-recents-*.

Final debug APK SHA-256:
ccf2c8d9fb0a6e4c1ad08e8774e1c690ae1255cd466c1f46cf1a1032a877024a.
runtime-debug-769d60f4-proof.json verifies source, package, debug signer, archive
and compiled network policy. 769d60f4-install-preservation-proof.json and
closure-final-769d60f4-full-reboot-proof.json prove all three Hive files exact
across in-place debug update and full Android reboot before launch. The boot ID
changes; the post-launch final snapshot retains the same three hashes.

Independent closure-final-inventory.json / closure-final-preservation-proof.json
retain exact original maps/order for three playlists, five likes, four imports
and four results, selected alternatives/exclusions and all nine original settings.
Every baseline key remains. The only baseline user changes are three expected
appended routing audits, local tone 1 moving to the front of Recents with three
more plays and a newer typed timestamp, and current listening total +26 seconds;
all per-song stats and other stats fields remain exact. Generated playlists,
folders and pins are removed, leaving empty folder/pin keys. The only new setting
is explicitly selected High quality. The disposable offline cache now contains
only three registered owned synthetic WAV fixtures, all original hashes exact.
This deliberate fixture registration proves local offline navigation/playback;
it is not a successful provider download. No original/library/import data was
cleared and no physical phone or unrelated device was modified.

The current matrix has no pending safe-local native repair listed. Remaining
online/provider, physical, delivery-scope and signed-release subgates are explicit
prerequisites; named partial passes do not imply complete product acceptance.

Remaining prerequisites: allowed complete media for online listening/download
and previews (stopped after denial); reconnect the selected Samsung's existing
USB/ADB connection and leave it unlocked for phone/focus/output checks; available
physical outputs/accessories; owner decision for I11 subset delivery; full product
gates followed by exact signed in-place rehearsal. No merge, signing/publication,
live-phone update/restore, secret/security/provider workaround or matching rerun.

## Historical execution evidence (superseded statuses)

The sections below retain chronological failures and pending observations.
Use the reconciled matrix above for current subgate status. Earlier failures
are retained for traceability and must not override their exact repair evidence.

### Remaining-work classification after ee5ea7c9

The 34 incomplete rows have different subgates. Primary grouping below covers
each exactly once; a provider-dependent row can still have safe local tests.
No external-source denial prevents fixture or local navigation/control checks.

| Primary group | Rows | What remains safe / what actually blocks the full row |
|---|---|---|
| Complete media dependency (3) | P01, P02, O01 | Liked/playlist/recents order, local files, offline membership and error/cancel behavior are fixture-testable. Complete online listening/download requires allowed complete media; initial 206 does not prove it. |
| Safe local or synthetic coverage (28) | D05; P03-P05; I01-I10; L01-L04; S01; O02; T01-T04; U01-U02; V01-V02 | Backup corruption/cancel, review/routing/exclusions, library CRUD, local playback/repeat/seek/queue, navigation, themes/text scaling, clear-dialog cancellation, updater rejection and visual checks can progress independently. I04-I06 online previews and S01 playable-online-result have media subgates; metadata/search can be tested separately. U02 code/invalid-artifact checks are local, but exact signed in-place rehearsal stays gated on CI/signing/product acceptance. |
| Physical phone only (2) | P06, U03 | Audio focus, screen-off/output/real accessories and exact live in-place smoke require Samsung availability. U03 also requires the conditional release gates. Do not install to manufacture a comparison. |
| Future-delivery decision (1) | I11 | Individually selected/newly resolved subsets are absent. Their current vs future delivery scope needs an owner decision, not an assumed pass or silent implementation. |

Signing/publication is a separate conditional release gate, not an external
audio denial and not a reason to skip safe U01/U02 fixture checks. A single
ordinary unchanged-Samsung playback comparison is authorized if accessible;
Samsung was absent from ADB at this checkpoint. Reconnect the existing USB/ADB
connection and leave it unlocked; no debugging/security change is requested.

- Samsung package/version/signer and repeated APK hash rechecked; actual native export saved and independently inspected after unlock. Compile-time source stamp verified.
- Previous exact code CI and synthetic restore evidence are historical supporting
  checks, not passes for the real-data/current expanded matrix above.
- Actual real export preserved; the owner confirms its zero-library inventory is expected. No integration, signing or Samsung update performed.

- Playlist unavailable-state and real Shuffle toolbar regressions reproduced on the prior code. Candidate fixes wrap the sliver error in a scroll view and route natural-order songs through player shuffle. Focused tests cover actual widgets; they do not prove real track completion.
- Disposable Android repeated selection of the same synthetic document showed favorites 2, then 1 after replacement, then 2 after replacement back; all inspections cancelled. Earlier stale-selection observation was not reproduced in this controlled probe. No cache purge/plugin change or live restore was used.

### Native public-fixture checkpoint (2026-10-11)

Latest bounded error follow-up: clean local analysis and 225 aggregate tests
pass, including real loopback truncated/disconnected-response handling, prompt
Stop during pending headers, no replay after source denial, three-failure
repeat-all stopping, and selection during an old failure callback. The error
banner fits widths 320/412 at normal and doubled text size and opens Library.
Exact d3d353fc CI 38134013870 passes all 225 aggregate tests, 35 Linux goldens
and build boundaries. Both unchanged Windows strict visual suites fail all 35
comparisons; inspected text differences are retained outside Git. Native local
damaged-file error, disabled failed-source control and Library navigation pass.
The synthetic WAV is restored to its original hash; fresh healthy selection
clears the error. Local Play/resume/pause, Next and tail completion pass with
queue size 3. Zero seek and completed-tail Replay FAIL on that native APK:
Android is at 0 while the slider retains 00:09, and Replay remains paused at 0.
Bounded corrections and final exact-source verification follow. Native Google
source cancellation remains unproven; synthetic service and loopback tests do
not replace that evidence. No denied provider source was requested again.

Tested Android code: 8f886901cfe018b8c4698c3cd3f2ad51f5ec434f, isolated
`.preview.debug`, task-owned API 35 emulator. APK SHA-256
70637f871d7cb9c7e0b517bc7118c47660f516f242eea1bc4fe07360303052ba.
This evidence uses four synthetic/public-metadata source rows and two existing
synthetic likes. It is not a Samsung data or signed-release pass. Local evidence
is under `musify-source-comparison/emulator-rehearsal` outside the checkout.

- I01/I02: native CSV validation showed four valid rows and one rejected row;
  saved source rows survived the debug update/reopen. Matching finished 4/4,
  initially one strong/two review/one unmatched. Pause was not exercised: the
  run had already finished when its control was sought.
- I04/I07: actual Quick Review loaded alternate artwork and saved Accept for
  alternate `BCGH8eU-_lA`; independent copied Hive inspection confirms that
  exact identity and `review_sprint_accept`. No match saved `manual_unmatched`
  with retained alternatives. Existing likes and all source rows remained exact.
- I08: exact-track Exclude was confirmed on the invented fixture recording.
  Copied persistence confirms source row 5 retained, `excluded_from_import`,
  timestamps and excluded-row list. Matching totals became two strong/one
  unresolved/one excluded. Restart/re-export and exclusion from every downstream
  surface remain open, so this is a partial E pass.
- I09/I10: native all-resolved routing added two songs while one remained
  unresolved. Repeating the actual transfer reported zero additions/two already
  present. Independent post-routing inventory and playlist/first-N/restart paths
  remain open. Evidence: `private-ui/emulator-5556-runtime-liked-review.xml`,
  `runtime-liked-transfer.xml`, `runtime-liked-repeat-review.xml`,
  `runtime-liked-repeat-confirm.xml` with matching screenshots.
- Independent review proof: `runtime-review-persistence-proof.json`, backed by
  `runtime-inventory-before-review.json` and
  `runtime-inventory-after-review-exclude.json`. These copied-box assertions pass
  without writing to the app or exposing live data.
- I04/V02 accessibility FAIL on tested 8f: covered next-card semantics announced
  a different recording under the visible current card. Candidate repair hides
  the covered card's semantics; a before-failing/after-passing widget regression
  confirms promotion still exposes the next card. Native final-APK retest remains
  required. Singular import-summary grammar is also corrected.
- Audio/preview remains FAIL on tested native code: forced ANDROID_VR extraction
  timed out/reported HTTP 403. Fresh ordinary ranged GETs using the existing
  library defaults returned 206 and 1,024 bytes for both `lYBUbBu4W08` and
  `BCGH8eU-_lA` on the host. This is compatibility evidence, not native playback,
  preview duration, audible output or completion proof. A HEAD 403 alone is
  inconclusive. No proxy, credential, authentication or security change was used.

Current local repair validation: analysis passes and all 162 tests pass, including
the actual review-card semantics regression. Exact pushed CI and native retests
must be recorded after the next candidate commit.

Follow-up: exact CI 38122981222 for 43fa69c8003965ecdeb9aef415d03ff44ac2d6ae
passed analysis, 162 tests, both strict visual suites, debug/F-Droid boundary and
unsigned release build. Independent post-routing copied-box assertions now pass:
imported songs retain source order and exact alternate; older likes retain their
values/order; source rows, unresolved/excluded counts and both routing audits
remain intact (`runtime-liked-routing-proof.json`). Native Quick Review reopened
the sole saved No match without rerunning matching and omitted the excluded row.
Ordinary manual search loaded 39 results. Exact-URL lookup instead failed with
watch-page metadata retrieval, then a bounded 18-second retry timeout; no decision
was saved. Exact-URL native acceptance therefore remains FAIL/open.

On one fresh Dreams stream URL, host HEAD returned 403 and bounded ranged GET
returned 206/1,024 bytes (`runtime-range-stream-PgagPdVM7bk-host-probe.json`).
Candidate media repair validates cached URLs with GET `Range: bytes=0-0`, accepts
200/206, closes the client immediately after headers, retains a 10-second bound
and rejects access-denied/other failures. Direct extraction uses the vendored
library's ordinary defaults instead of forcing the failing VR-only configuration;
proxy settings/implementation, credentials and authentication are unchanged.
Nine regression tests cover HEAD rejection versus GET success, ignored Range
without consuming the body, denied/error responses, timeout and client closure.
Analysis and all 171 tests pass. Native playback/preview/completion proof is still
required before treating this compatibility repair as a runtime pass.

### Actual Samsung export rehearsal (2026-10-11)

D02/D03/D04: actual native export 251405 bytes, SHA-256
9f74763b07e2dbd89336d58c37a3379282a49bfcddf37cbb2dd773957770bc34,
restored only into task-owned isolated candidate 26bd0e98. Its native validated
counts matched the independent inventory. Full Android reboot was confirmed by
distinct boot IDs. Native post-reboot re-export 251451 bytes, SHA-256
3e80ea244a3eca5c98617776c21e23f640221965e22e2d07d5bf5da81b00f8cd,
has exactly the same whole typed-map SHA-256
ae6c1be7d8fe8aa9f1e3b9dc460626c7e7a4f0ab2dcc66410f362eba0468fa17.
Every key, value and type compares exactly, including both history entries, both
search entries, listening statistics and all three settings; no ignored changes.
The owner confirms the empty library is expected and plans a fresh supported
Spotify export/reimport. Private evidence: phone-real-backup/
real-restore-reboot-reexport-proof.json and disposable-post-reboot-comparison.log;
emulator-rehearsal/real-android-reboot-proof.json. No live phone restore/update.
The old signed baseline reproduced its known pre-inspection temporary-file
cleanup failure; it did not complete a restore. Final exact signed in-place
rehearsal remains required.

### Pending bounded transport and completion repair (2026-10-11)

The owner explicitly approved an app-only GitHub-flavor HTTP 127.0.0.1 allowance
with includeSubdomains=false, external cleartext denied and no device-wide
change. The candidate uses just_audio 0.10.6's IPv4 loopback random-port server
and crypto UUID-v4 source path; upstream requests stay HTTPS. Lazy finite ranges
are at most 256 KiB, enforce exact length/Content-Range, bound four active reads,
propagate backpressure, time out and cancel the client before awaiting cleanup.
F-Droid keeps the existing URI source and has no network-security exception.
Automated negative boundaries include HTTP/lookalike hosts/ports/invalid lengths,
denied/redirect/error responses, mismatched/truncated/oversized data, stalled
headers/body, early cancellation and capacity recovery. Native boundary and
decoded playback checks are still pending; static XML checks alone are not a
device security-policy pass.

Native controlled 45-second PCM fixtures on 26bd advanced naturally from track
1 to 2 to 3, then retained playing=true at the completed final track. This is a
P05 FAIL, recorded in controlled-audio/natural-completion-session.json. The
candidate pauses the completed non-repeating tail while retaining song/queue;
a regression failed before and passes after, and repeat-all still wraps.
Controlled tones do not prove public-track playback or audible output; the
task-owned headless emulator has audio output disabled.

Manual preview now arms its existing 30-second stop timer when playback starts,
instead of after the play future completes. Quick Review remains 12 seconds.
SponsorBlock's bounded-source path seeks over validated absolute segments;
native timing and SponsorBlock acceptance remain open.

Exact YouTube URL lookup now requests registered public YouTube oEmbed metadata
over ordinary HTTPS, without watch-page challenge workarounds. It preserves
the exact ytid and normal metadata, ignores returned embed HTML, and leaves
duration unknown. Redirect/401/403/404, oversized response and timeout are tested
to fail without fallback or saved decisions. Host public-metadata success is
supporting evidence only; I06 native acceptance remains open.

Local candidate validation: clean analyzer and all 208 aggregate tests pass.
Evidence outside Git: bounded-transport-analysis-final.log and
bounded-transport-aggregate.log under emulator-rehearsal. Exact pushed CI,
new APK identity and all affected native paths must be recorded before a pass.

### Exact 9f92 native result and later-range denial (2026-10-11)

Exact candidate 9f92bf55dcdf5377f0bdd797f0d4b4b6023a4264 passed CI
[38128871154](https://github.com/topcat432/musify-personalized/actions/runs/38128871154):
analysis, 208 aggregate tests, both strict visual suites (35 images), debug,
F-Droid boundary and unsigned release verification. Its isolated debug APK
SHA-256 is 8049a5bda7b5f7b415215eee9f8d7845c74d712a8081594830e2cd3068188c9b.
Compiled Android XML has base cleartext=false and only 127.0.0.1 with
includeSubdomains=false. Its in-place disposable update preserved all three
synthetic Hive files byte-for-byte before launch. This is not signed-release or
Samsung acceptance.

Controlled native PCM 1/2/3 advance naturally; final tone 3 remains PAUSED at
45007 ms for at least 24 seconds, with Replay and queue size 3. Shuffle-on
reorders to 3/1/2 while retaining tone 3; shuffle-off restores 1/2/3. Native
Play Next inserts tone 1 immediately after current tone 3, preserving 1/2/3/1.
Later public-playlist replacement retains the manual entry. The native toggle
test with that inserted entry is still pending. Evidence: controlled-audio/
9f92-first-play-session.json, 9f92-natural-advance-session.json,
9f92-natural-tail-session.json, 9f92-completed-tail-session.json and private-ui/
runtime-9f92-shuffle-on-queue, runtime-9f92-shuffle-off-queue,
runtime-9f92-play-next-queue XML/PNGs.

Real online Here Comes The Sun (BCGH8eU-_lA) decodes past 4 seconds and buffers
57481 ms with actual artwork, then fails around 57 seconds. Dreams
(m8i5WiWCN-c) also decodes past 4 seconds, then fails. Both actual cached native
URLs are ordinary ANDROID Opus tag 251. Independent bounded diagnostics on
copied disposable URLs accept bytes 0-262143 with exact 206/body length but deny
1048576-1310719 with HTTP 403 and no body. No provider parameter, client identity,
credential, cookie or proxy changes were attempted after denial. This is initial
decoding evidence and sustained-listening FAIL, not a healthy native stream pass.

The just_audio 0.10.6 loopback server also surfaces truncated-response exceptions
and native retries after the stream error. Musify did not listen to the current
errorStream API, leaving stale playing controls after the native session became
NONE. Pending repair handles runtime errors once, pauses before bounded queue
advance, rejects further requests to a source after its first failed range, and
cancels stale retries after new selection/explicit stop. Initial truncated
response handling and sustained provider access still require acceptance;
unit success must not hide either failure. Evidence: native-online/
9f92-public-native-session.json, 9f92-dreams-native-session.json,
9f92-dreams-sustained-session.json, cached-range-host-diagnostic.json,
cached-range-m8i5WiWCN-c-host-diagnostic.json and URL/token-redacted native logs.

Runtime-error repair validation: clean local analysis and all 212 aggregate tests
pass, including later-range terminal failure, duplicate runtime-error ownership,
new-selection cancellation and explicit-stop cancellation. The new exact-source
APK/CI and native error-queue retest remain pending.

Four ledger rows have documented baseline/export/restore/restart passes; the
remaining 34 are open, partial or failed in this expanded round. No signing,
merge or Samsung update is allowed to proceed on the present listening result.

### Native loading lifetime regression (2026-10-11)

Exact bfbda9657b977de50666648d48417510f9c81797 debug APK built and was installed
only on the disposable AVD. APK SHA-256:
beb27d6f2c6f915ff6d0301c81a1ada52516f63fb13869e3fbce026c7b6c2a28.
All three Hive files were byte-identical before launch. Here Comes The Sun
again decoded initially, then reached native NONE without queue advance.
The terminal source guard prevented new upstream requests from that source;
just_audio still retried local requests and emitted two truncated-response
exceptions. P02/P03 remain failed. Evidence outside Git: native-online/
bfbda965-public-first-session.json, bfbda965-public-late-session.json,
bfbda965-public-late-redacted.log and bfbda965-install-preservation-proof.json.

The real load path awaited just_audio's play future for the entire track,
leaving the loading guard active and suppressing runtime error ownership.
The follow-up repair starts playback without awaiting its lifetime and guards
duplicate failures for the entire transition. A regression exercises the real
offline load/handoff with a pending play future and the subscribed errorStream:
history updates promptly, loading completes, one pause occurs, and one advance
occurs despite two separately timed reports. New-source native acceptance is
still required; this does not resolve the observed provider 403 or the first
truncated-response exception in just_audio.
