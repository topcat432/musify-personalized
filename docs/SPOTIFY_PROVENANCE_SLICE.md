# Optional Spotify identity intake slice

Status: authorized low-risk stretch preparation, 2026-10-13. Verified baseline
`733a5a9409695298348c023ecbb6e46f511ae036` remains the recovery reference. The sole
candidate stays on agent/local-stable-consolidation/PR23. This slice is metadata
retention, not Spotify playback, recording verification, universal coverage or
an additional release gate.

## Implemented boundary

Two optional string fields, `spotifyTrackUri` and `spotifyTrackId`, are added to
new CSV track serialization and copied to matching checkpoint results. Existing
track maps without them retain their exact serialized shape. No required key,
Hive adapter, archive schema version or migration is introduced. There is no
backfill, on-read write, reset, reimport requirement or historical reclassification.
Scoring, query text, candidate selection, verification, routing/library payloads
and playback remain unchanged. Optional fields participate in live source stale
checks only when present; legacy six-field fingerprints are unchanged.

Supported intake: conventional `spotify:track:<22 base62 characters>`, HTTPS
open.spotify.com track URLs (including intl-xx prefix, trailing slash, port 443),
and a valid ID from an explicit Spotify ID column. Generic Track ID is not
interpreted as Spotify identity. URI/ID must agree exactly; ID case is preserved.
URL query/fragment values are not persisted. User-info, wrong scheme/host/port,
album/episode/redirect forms, malformed IDs and encoded host/path spelling are
rejected as optional metadata. A usable title/artist row is still imported with
the same classification/counts as before. No URL is opened or resolved.

Matching copies already-stored partial fields as-is, without inferring a missing
partner ID or a verification claim. Normal, excluded and failed lookup result
construction all pass through the optional fields. Existing review/rescue maps
copy their current result, preserving fields. Fields are kept outside the chosen
candidate, so routed songs remain unchanged and existing ytid dedupe/order applies.

## Acceptance and contract-case disposition

25 new synthetic tests cover the slice, alongside existing regression families.
All provider lookups are controlled fixtures; no actual catalog IDs, requests,
accounts or credentials are used. Saved schema-1 backup bytes are validated and
independently restored/reopened with exact optional and baseline keyed values.

| Contract case | This slice |
|---|---|
| 1 Legacy absent metadata | Exact old serialized shape and unchanged selected outcomes; no writes/backfill |
| 2 Partial metadata | Existing URI-only/null fields copied unchanged through match/reopen |
| 3 Invalid/conflicting URI/ID | Rejected optional metadata; usable song retained |
| 4 Canonical forms/case/privacy | Supported forms, ID case, query removal, spoof/credential/encoded-path rejection |
| 5 Unknown future version map | Deferred: no versioned provenance map is introduced; only two optional scalars |
| 6 Duration interpretation | Existing explicit-ms/generic-duration tests retained; code unchanged |
| 7 Version conflict verification | Deferred: scoring/verification must remain unchanged in this slice |
| 8 ISRC propagation verification | Deferred: no verification claim/state or propagation change is introduced |
| 9 Selected alternative | Existing review/routing persistence regressions retained; URI fields are outside candidates |
| 10 URI without playable match | Controlled failures preserve URI/ID and original error/excluded classifications |
| 11 Denial/missing file health | Existing offline/runtime failure guards unchanged; no source-health metadata is added |
| 12 Multiple origins/one audio ID | Separate import rows retain their fields; routing payload/dedupe explicitly unchanged; collection merging deferred |
| 13 New-session stale result | Existing session/cancellation guards retained |
| 14 Optional identity changes during lookup | Stale checkpoint rejected; no edit/supplementation UI is added |
| 15 Partial write/reopen/rollback | Exact previous key/value set restored, including optional fields and selected recording |
| 16 Repeat/reopen/selectors | Pause/reopen/resume does not repeat completed lookup; existing four-mode routing tests remain |
| 17 Saved backup/restore/restart | Production bundle validation plus independent payload restore/two reopens preserve metadata |
| 18 Older binary rollback | Baseline commit retained; no live downgrade. Optional map fields require no adapter. Older writers may discard fields on a later replacement/rebuild; provenance is not promised durable through every older writer |

Native acceptance uses a fresh isolated owned namespace on emulator-5556:
new CSV import, paused first checkpoint, failed replacement rollback, cold resume,
then completed-state cold reopen with zero repeated lookups. Normal four Hive
files must remain byte-exact through rehearsal installation and stopped captures.
Independent typed comparison checks track/result identity, source order, selected
candidate, unrelated library/settings/cache/offline values and exact rollback.
Native acceptance and exact-source CI pass at b1dc64fa; source-pinned receipts
and normal restoration are recorded in RELEASE_STATE. Three stopped independent
reopens preserve the completed recording, source row order and unrelated data.

Local aggregate: 418 tests PASS; analysis clean. Strict Windows visuals remain
FAIL 16+24 with all40 actual renders byte-exact to the established control and
references unchanged. Linux is the strict reference gate, not an inferred Windows
PASS. Source-pinned CI/native/normal-restoration evidence belongs in RELEASE_STATE.

## Risk, rollback and deferred work

Risks are optional metadata loss during rebuild, URI/ID conflict, stale metadata
overwrite and accidental change to baseline classification. Tests cover these
boundaries; no ranking, selection or routing policy changed. The prior session
writer's rollback restores the exact old key set after partial writes.

Code rollback reference is 733a5a94. Preserve pre-change and new metadata evidence;
do not clear/reimport or strip user maps to perform a rollback. Older code reads
plain optional-map additions without an adapter migration, but later old writers
can omit these fields, so retain recovery copies rather than claiming universal
forward preservation. Production rollback/live restore requires separate approval.

No larger provenance collection, source UI, verification state, audio broker,
new service, OAuth/client grant, rights determination, playback-ad/paid-access
bypass or external handoff is included. The three-recording batch stays held.
Do not automatically start those later slices after this checkpoint.
