# F04-C durable named-playlist intake and source review,2026-10-14

Status: host implementation; signed/native qualification pending. The precise
caseychu/spotify-backup compatibility envelope in SPOTIFY_PLAYLIST_DRAFT.md is
now connected to direct JSON and explicit ZIP entry selection. This does not
claim Spotify account Playlist.json schemas, automatic multi-file merging,
playlist recreation or repeat synchronization.

## Durable contract

Preview retains source playlist names/positions/optional validated URIs and all
ordered membership positions. Each unique validated recording URI is matched
once; repeated memberships reference its original unique sourceRow. Missing,
local, non-song, incomplete and supplied-ID/URI conflicting items retain their
positions, available source labels, original added-date text and explicit issue.
Same-URI normalized artist names are compared structurally; comma-joined display
text cannot hide different artist-list structures. Display formatting remains.

Explicit Save stores a nested sourcePlaylists version1 payload in the existing
spotifyImportMetadata map using the same four-key writer and rollback. There is
no Hive adapter/global schema/backup-format migration. Absent payload means old
flat import and is read without writes; unknown versions, broken positions or
malformed known payloads produce a retained-data error. Reference rows and their
recording URIs must agree with preview tracks before any durable write. Replacing
an import with a flat file explicitly removes membership metadata. Library and
previous completed work stay unchanged on preview, Cancel or failed Save.

Source review is available before Save and from the import hub after Save,
including after restart. The hub reacts to metadata commits. Review lazily lists
ordered items, retains unsupported items visibly, supports playlist selection,
and scrolls its header at compact/large text. It never guesses that unsupported
items are matched or recreates/synchronizes playlists. Only the selected ZIP
entry is imported; original archive/other source files are never modified.

## Host acceptance

- Legacy/partial rollback, missing reference rejection, unknown version/position
  validation and explicit replacement/reopen.
- Saved-file backup checksum/inspection, controlled restore and full synthetic
  user inventory/reopen; no native/phone data-safety proof inferred.
- Matching handles only unique source rows and retains memberships at checkpoint,
  explicit matching restart and Hive reopen; lookups are synthetic, no provider
  requests. Chosen alternative routing/retry preserves every source membership.
- Direct JSON preview stays unsaved, source review/Save/reopen; explicit ZIP choice
  retains selected source entry and membership, independently of YourLibrary.
- Same-URI artist join collision and nested supplied-ID mismatch regressions.
- Compact412x915 with2x text, reactive saved link, legacy absence and retained
  corrupt/forward-version data. Strict references/comparators remain unchanged.

Source-specific routing/recreation and repeat synchronization are subsequent
roadmap milestones. Native picker/stream/dialog/DEFLATE cancellation, signed
backup/independent restore/process/full cold restart remain separate gates.
The immutable signed c249 baseline contains none of F03/F04; no new signing,
publication, merge or phone operation is authorized here.
