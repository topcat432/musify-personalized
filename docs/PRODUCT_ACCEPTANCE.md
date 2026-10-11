# Product acceptance ledger

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

Initial state below is deliberately UNTESTED for this expanded acceptance round.
Earlier synthetic and CI evidence remains in RELEASE_STATE; rerun affected paths
on the final code and distinguish it from the real Samsung export.

| ID | Screen / entry / action | Acceptance, including repeats and errors | Initial level/status | Implementation / automated reference |
|---|---|---|---|---|
| D01 | Installed app and About | Retained .preview, actual Android version/code/signer; no hardcoded identity | D PASS package/version/code/signer and repeated APK hash; compile-time export source stamp verified; original CI artifact comparison unavailable | installed_app_identity; about_page |
| D02 | Settings → Create verified backup → local SAF Save | Preserve live data; validate actual saved bytes, schema, both boxes, inventories, semantic values | D PASS actual SAF export 251405 bytes; independent typed inventory; empty library confirmed expected by owner | musify_backup_service; backup service tests |
| D03 | Disposable Restore → review → confirm | Exact real-data counts/order/selected identities/exclusions/settings; rollback and reopen | E PASS actual Samsung export native inspection/confirm on 26bd; old signed baseline picker fails before restore | backup service / validated summary tests |
| D04 | Full Android restart → native re-export | Independent exact keyed semantics; explain every legitimate change | E PASS full Android reboot and native re-export: every typed key/value identical, no exceptions | manual backup_rehearsal tool |
| D05 | Interrupted/corrupt/repeated/same-name backup selection | Reject corrupt/partial safely; recover rollback; newly selected bytes stay fresh | E PASS bounded same-name inspection 2→1→2; corrupt/partial A prior CI; restart/current-code retest pending | backup service tests; Android file picker |
| P01 | Liked Songs row / Play / Shuffle | Full list, real track completion advances with repeat off; replacement queue keeps shuffle | E/D UNTESTED | user_songs_page; audio_service; queue_retry_utils |
| P02 | Playlist / Offline / Recents Play and row tap | Correct full source/order/start index; selected source not silently substituted | E partial: controlled playlist source/order PASS; sustained public stream FAIL at 1 MiB; Offline/Recents pending | playlist_page; user_songs_page |
| P03 | Now Playing / mini-player seek, pause, previous, next | State/position synchronized; rapid input bounded; long titles don't overflow | E FAIL source-error state on 9f92; controls/seek and repaired error handler retest pending | now_playing; mini_player; audio_service |
| P04 | Queue / Shuffle on then off | Natural order restored; current track retained; Play Next survives | E partial PASS shuffle on/off retains tone 3 and restores 1/2/3; Play Next inserts and survives replacement; toggles with inserted entry pending | audio_service / shuffle state tests |
| P05 | Track completion / failed stream / retries / repeat off-one-all | Advance once; no replay of failed tail; repeat modes intentional; healthy playback not hung | E controlled 1/2/3 natural completion/tail pause PASS; real stream/retry FAIL; repeat one/all native pending | audio_service playback retry / queue_retry_utils tests |
| P06 | Background/screen off/audio focus/output reconnect | Resume/control correctly, avoid duplicate playback; record attached speaker/wired/BT coverage | D UNTESTED; unavailable accessories explicit | audio_service; Android audio session |
| I01 | Library → Import CSV → pick/inspect/cancel/replace | Valid rows/provenance retained; no implicit likes changes; failed replacement retains old session | E UNTESTED | spotify_csv_importer; import_session tests |
| I02 | Matching start/pause/resume/reopen/error | Checkpoint progress; don't redo resolved tracks; fallback failure retains structured candidates | E UNTESTED | track_matching / scoring tests |
| I03 | Matching summary → No match / Review / Errors | Permanent reopen without restarting 2,643 rows; unresolved remains after routing | E/D UNTESTED | matching_page; review_workflow tests |
| I04 | Quick Review entry / artwork / preview / Accept / No match / Later / manual | Discoverable artwork-led cards; 12s preview; equivalent buttons/swipes; save before advance | E UNTESTED | review_sprint_page / swipe_deck tests |
| I05 | Detailed/manual YouTube and YT Music search | Show scorer-rejected results with warnings; artwork/metadata/preview; explicit correct recording | E UNTESTED | manual_match_page; manual_source tests |
| I06 | Exact YouTube/YT Music URL → confirmation | Resolve normal song+ytid; preview before save; invalid/private/deleted fails without mutation | E UNTESTED | manual_source / review_workflow tests |
| I07 | Accept alternate → route → audit → reopen | Exact selected alternative survives all checkpoints and restart | E UNTESTED | review_workflow / destination tests |
| I08 | Exclude → exact confirmation → repeated review/restart | Preserve source row/audit; drain all review/rescue/totals/destinations; retain existing likes | E UNTESTED | review_workflow / backup tests |
| I09 | Choose Destination all/first-N → liked/existing/new → preview/confirm | Correct counts/source order/dedupe; success after durable write; partial unresolved stays staged | E UNTESTED | import_destination_page/service tests |
| I10 | Retry routing / stale session / empty selection / restart | Idempotent; no uncontrolled duplicates/deletion; reject stale/empty safely; destination history retained | E UNTESTED | destination/session tests |
| I11 | Individually selected/newly resolved subsets | Determine whether current delivery promise or later roadmap; do not invent completion | CODE absent; scope AMBIGUOUS | import roadmap §4; current selectSongs(first-N) |
| L01 | Library → favorites / playlists / folders / pinned / artists | Membership/counts/order/filter persist; no silently missing real content | E/D UNTESTED | library_page; playlists_manager |
| L02 | New/edit/rename/delete playlist/folder, cancel, repeat | Changes only disposable data; cancellation safe; duplicate/empty validation; restart persists | E UNTESTED | playlist_folder tests; edit dialogs |
| L03 | Playlist unavailable/empty/loading → Back | Readable error/empty state, no RenderBox/Sliver exception or stranded navigation | A PASS targeted regression; E UNTESTED | playlist_page; EmptyPlaylistState |
| L04 | Share/import/export links | Correct entry/preview/cancel; no external sends without explicit authorization | E UNTESTED bounded | playlist_sharing; playlist_bar |
| S01 | Search query/suggestions/history/result/artist/album/playlist | Real loaded artwork/text, relevant playable result, empty/failure/cancel; offline behavior clear | E/D UNTESTED | search_page; artist/playlist route services |
| O01 | Download song/playlist → Offline → play/remove/cancel | Correct file/state, interruption/retry bounded; real offline playback; no misleading quality claim | E UNTESTED | playlist_download_service; offline widgets |
| O02 | Offline switch → navigation/search/local lists | Downloaded-only sources usable; clear empty state; toggle back restores navigation | E/D UNTESTED | router_service; offline_search_placeholder |
| T01 | Settings themes/quality/shuffle/repeat/update/preferences | Every visible toggle uses correct key; reversible settings persist after restart | E/D UNTESTED | settings_manager; settings_page |
| T02 | Cache/history/recents/stats/download clear dialogs | Correct scope/confirmation/cancel; execute only on disposable state | E UNTESTED bounded | settings_page; common_services |
| T03 | Equalizer/lyrics/listening recap/Time Machine | Correct entry/data/empty/error; don't imply unsupported features; no crashes | E/D UNTESTED | equalizer_page; lyrics; time_machine_page |
| T04 | About/licenses/translation/sponsor | Accurate identity/upstream attribution; working safe entry/Back; no external action/purchase | E/D UNTESTED bounded | about_page; settings_page |
| U01 | Check personalized update / current/error/invalid manifest | Exact retained package/pinned signer/hash; reject legacy/debug/unsigned/wrong identity; sensible UI | A prior CI; E/D UNTESTED | personalized_update_service/dialog tests |
| U02 | Signed workflow + disposable in-place rehearsal | Exact default tip; monotonic version; v2/v3/pinned signer/hash; real-data survives | R UNTESTED gated | signed-release.yml; RELEASE_SIGNING |
| U03 | Samsung in-place install → APK re-extract/data inventory/smoke | No uninstall/clear/live restore; exact artifact and persisted real data; daily critical paths | R/D UNTESTED gated | explicit approved release/install evidence |
| V01 | Real artwork / long labels / compact + large text / themes | Artwork-led; no Aquaz3y/orbit/KEEP-NOPE branding; readable, no clipping/overflow | E/D UNTESTED | VISUAL_SYSTEM; both strict visual suites |
| V02 | Scroll/keyboard/mini-player/safe insets/back/rapid gestures | No obscured controls, trapped overlays, stale views or lost decisions | E/D UNTESTED | actual screen recordings + widget regressions |

## Current execution evidence

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
