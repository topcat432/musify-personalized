# F04-A: explicit bounded archive entry selection,2026-10-14

Current successor: [F04-C membership intake/review](SPOTIFY_PLAYLIST_MEMBERSHIP.md) connects compatible named-playlist JSON to controlled Save and retained source review. Earlier statements below describe their checkpoint scope. Full account schemas, playlist recreation, synchronization and native qualification remain unfulfilled.

Roadmap5 calls for account ZIP/playlist import. This milestone extends intake to
multiple candidate files with explicit selection, before membership support.
It does not claim full account archives, playlists or repeat synchronization.
Share/open remains deferred because Android URI ownership and intent lifecycle
need native qualification; this bounded parser/UI milestone can be host-tested.

## Implemented contract

- Own an immutable copy of at most8MiB selected ZIP bytes; at most32 entries,
  at most8MiB combined declared decoded bytes. No extraction or downloads.
- Every entry is an ordinary safe ASCII root-level CSV/TSV/JSON basename;
  case-insensitive duplicate names, paths, directories, symlinks, encryption,
  descriptors, extra fields/comments, ZIP64 and unsupported methods reject.
- All local/central records agree; ranges are contiguous/non-overlapping with
  no leading/trailing bytes. Header validation includes unselected entries.
- Multi-entry archives always require a choice. Only chosen payload is decoded
  and CRC/parser-validated; unselected payloads are not decoded or imported.
  A corrupt unselected payload is not asserted valid by its header inventory.
- Existing strict Android DEFLATE finished/consumption/size/CRC/deadline and
  cancellation controls are reused in a rebased in-memory single-entry envelope.
  Other platforms fail closed for compressed choices; row budgets remain.
- Choice Cancel/dismiss returns to the previous preview. Reading and Save remain
  mutually exclusive. Preview discloses all other files were not imported.
  Unsupported playlist JSON/membership reject; no flattening or source guessing.
- Explicit Save retains sourceEntryName alongside fileName in the existing
  metadata map. Old/partial sessions without it need no migration; replacement
  with a flat file removes it. Controlled rollback preserves old maps exactly.
  No adapter, backup format, permission, dependency or score changes.

## Acceptance

Synthetic independent Python ZIP fixtures and host service/widget tests cover
entry order/selection, all truncation prefixes, duplicate/count/path rejection,
malformed unselected headers, selected CRC, wrong native completion, cancellation,
caller mutation isolation, old/partial-state rollback, restart and explicit Save.
Saved-file backup inspect/restore/reopen must retain entry provenance and the full
synthetic inventory. Analysis, strict suites and exact-source CI qualify source;
Android real picker/dialog/decode/cancel and signed backup/restart remain pending.

The signed c249 baseline is unchanged and contains none of F03/F04. Runtime
qualification stays separate. No phone, signing, publication, merge or baseline
replacement is authorized by this host milestone.

## Next membership milestone

Spotify's [data guide](https://support.spotify.com/us/article/understanding-your-data/)
describes playlist names, ordered song/artist/album data, local tracks and episodes,
but not a normative JSON field schema. The existing
[pinned backup producer](https://github.com/caseychu/spotify-backup/blob/8507cceefa155f47a54199db50a2d513c8b95549/spotify-backup.py)
is another concrete named-playlist/nested Web API format. A supported variant
must be identified precisely, with ordered memberships and unresolved/non-song
items preserved, unique recording identity reused conservatively, and old/partial,
rollback/backup/restart coverage before acceptance. Never use flat import as a
silent substitute for that contract.
