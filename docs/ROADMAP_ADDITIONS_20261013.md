# Optional roadmap additions,2026-10-13

## Preserved baseline and authority

The owner authorized small feasible roadmap work after host-actionable baseline
fixes were exhausted. This does not qualify the baseline's outstanding runtime
acceptance. Sole candidate remains agent/local-stable-consolidation / draftPR23.
Keep signed product24a2cb38a84bf141d8884ec98b6e6eb69e2bf717 and CI-verified
test/documentation checkpointd12f932d92e34266c03bc1331f693ce5e0e4d8c6 independently
of optional additions. The preserved APK version300000014/hash92991078806f3a0ad0cb604eb28ec5c67ac4c63da8c702bd529194e456c3a940
contains the baseline, not these additions. Do not sign every minor change.

## Actual inventory

| Scope | Actual state |
|---|---|
| Permanent unmatched access, Quick Review, manual unrestricted search/exact-link lookup | Implemented; current provider/native limits remain in the38-row baseline matrix. |
| Explicit destinations, all/firstN/individual/newly resolved, chosen alternatives/order and reliable successful snapshots | Implemented, including honest legacy-unknown and restart/idempotence coverage. |
| Flat CSV, optional validated Spotify metadata identity, backup/recovery, saved/offline surfaces and bounded Home/accessibility work | Implemented; host-verified does not mean current signed/phone acceptance passed. |
| Previously chosen small additions awaiting implementation | No separate unimplemented small selection was found in the inspected decision/acceptance history. D-018 Spotify playback is an unproven stretch, not a selected low-risk implementation. |
| Roadmap§5 flat compatible TSV song lists | Selected in this pass as F01. Complete local intake/preview/save/handoff through existing machinery; no account or network service needed. |
| Playlist-aware ZIP/JSON/membership/repeat synchronization and share/open intents | Later work; not fulfilled by F01 and not silently flattened. |
| Spotify PKCE/playback, canonical multi-source library, taste/DJ/AutoMix/Atlas, local/server lossless and Android Auto | Later design/architecture/service work. No credentials, dependencies or schemas added here. |

## F01: flat TSV song-list import

A .tsv filename (case-insensitive) selects tabs. .csv retains comma parsing;
embedded tabs in CSV values do not change its interpretation. The picker accepts
both extensions, and the intake page identifies the supported formats. Existing
quoted fields, escaped quotes, embedded newlines, UTF-8 BOM/CRLF handling,
required title/artist validation, rejected-row positions, order, duration and
validated optional Spotify identity apply to both. Known playlist-membership
columns in TSV reject with a clear explanation because playlist-aware import is
not implemented. This is compatible flat-column support, not a claim to support
every Spotify-backup/Converter or account-data export shape.

Save uses the existing explicit controlled replacement, write guard, rollback
and four import keys. No matching score, routing/source choice, library contents,
Hive/backup/journal version, dependency or schema changes. CSV sessions, old or
partial stored maps and prior completed work retain their existing behavior.
Titles/order survive Hive close/reopen; likes remain unchanged. Invalid preview
cannot replace the current import. Matching and routing continue from the normal
saved records without a new adapter or duplicated pipeline.

CSV-focused text on the existing import hub remains a valid entry to the same
workflow; the file-selection screen exposes TSV before selection. Existing
pixel-reference surfaces are unchanged. The Restart matching dialog now says song list; existing empty-state guidance stays unchanged.

## Separate optional acceptance rows

| Row | Required behavior | Host evidence | Runtime gate |
|---|---|---|---|
| F01-A | CSV compatibility, TSV quoting/metadata/order and explicit richer-input rejection | Parser regressions; final exact CI required | Native file read with .tsv/.TSV and compatible synthetic columns |
| F01-B | Picker advertises CSV/TSV; preview never writes before Save | Actual intake widget with mocked picker; current completed import exact after rejection | Android picker/select/Cancel/error and compact text inspection |
| F01-C | Offline explicit save, ordinary matching session and independent reopen preserve source identities/order/likes | Hive-backed widget/service and old/partial/rollback/backup identity regressions | Process/cold restart, route a selected alternative, backup/reopen/re-export semantics |
| F01-D | Baseline checkpoints remain independently usable; optional feature can be withheld | One separate additive commit; no schema/dependency migration; baseline source/artifact preserved | Never attribute F01 to the sealed24a APK; pin any later feature APK/source explicitly |

F01 is additive and can be withheld as a complete commit without rebuilding the
preserved baseline. Do not reset a dirty checkout or publish a baseline binary
as containing F01. Pending baseline verification stays in
[RELEASE_VERIFICATION_QUEUE.md](RELEASE_VERIFICATION_QUEUE.md); optional native
qualification runs only on its own exact source/artifact after baseline gates,
with the same owned5558/26GiB/80% controls. No phone, merge or publication.
## Host validation at additive commit

51 focused parser/widget/session/legacy identity/rollback/backup checks PASS; clean aggregate analysis and497 full tests PASS. Both strict Windows suites FAIL16+24, with all40 actual PNGs byte-exact to the established control after restoring the unrelated matching-empty copy. Before/current/isolated-diff images inspected; no references/comparators/dependencies changed. Exact-source Linux CI is required after push. Native F01 remains unverified; baseline checkpoints and their gates remain distinct.
