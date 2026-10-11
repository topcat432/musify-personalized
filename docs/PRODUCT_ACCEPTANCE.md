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
| D01 | Installed app and About | Retained .preview, actual Android version/code/signer; no hardcoded identity | D verified baseline version; exact APK recheck pending | installed_app_identity; about_page |
| D02 | Settings → Create verified backup → local SAF Save | Preserve live data; validate actual saved bytes, schema, both boxes, inventories, semantic values | D BLOCKED: unlock required | musify_backup_service; backup service tests |
| D03 | Disposable Restore → review → confirm | Exact real-data counts/order/selected identities/exclusions/settings; rollback and reopen | E UNTESTED real data | backup service / validated summary tests |
| D04 | Full Android restart → native re-export | Independent exact keyed semantics; explain every legitimate change | E UNTESTED real data | manual backup_rehearsal tool |
| D05 | Interrupted/corrupt/repeated/same-name backup selection | Reject corrupt/partial safely; recover rollback; newly selected bytes stay fresh | E PASS bounded same-name inspection 2→1→2; corrupt/partial A prior CI; restart/current-code retest pending | backup service tests; Android file picker |
| P01 | Liked Songs row / Play / Shuffle | Full list, real track completion advances with repeat off; replacement queue keeps shuffle | E/D UNTESTED | user_songs_page; audio_service; queue_retry_utils |
| P02 | Playlist / Offline / Recents Play and row tap | Correct full source/order/start index; selected source not silently substituted | E/D UNTESTED | playlist_page; user_songs_page |
| P03 | Now Playing / mini-player seek, pause, previous, next | State/position synchronized; rapid input bounded; long titles don't overflow | E/D UNTESTED | now_playing; mini_player; audio_service |
| P04 | Queue / Shuffle on then off | Natural order restored; current track retained; Play Next survives | E/D UNTESTED | audio_service / shuffle state tests |
| P05 | Track completion / failed stream / retries / repeat off-one-all | Advance once; no replay of failed tail; repeat modes intentional; healthy playback not hung | E/D UNTESTED | audio_service playback retry / queue_retry_utils tests |
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

- Baseline Samsung package/version rechecked; screen locked. Unlock requested.
- Previous exact code CI and synthetic restore evidence are historical supporting
  checks, not passes for the real-data/current expanded matrix above.
- No real Samsung export, integration, signing or update performed in this round.

- Playlist unavailable-state and real Shuffle toolbar regressions reproduced on the prior code. Candidate fixes wrap the sliver error in a scroll view and route natural-order songs through player shuffle. Focused tests cover actual widgets; they do not prove real track completion.
- Disposable Android repeated selection of the same synthetic document showed favorites 2, then 1 after replacement, then 2 after replacement back; all inspections cancelled. Earlier stale-selection observation was not reproduced in this controlled probe. No cache purge/plugin change or live restore was used.
