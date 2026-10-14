# F04-B playlist membership draft model,2026-10-14

Status: source-model milestone only. No UI Save, durable membership or playlist
recreation is claimed. Existing YourLibrary/ZIP UI still rejects playlist JSON
instead of discarding its membership. Signed c249 remains independently sealed.

## Producer compatibility

The inspected [pinned caseychu/spotify-backup producer](https://github.com/caseychu/spotify-backup/blob/8507cceefa155f47a54199db50a2d513c8b95549/spotify-backup.py)
writes a playlists array with named source playlists and tracks wrappers around
Web API track objects, plus an albums array. This parser supports that concrete
envelope. It never runs the producer, authenticates or reads account credentials.
Spotify's [data guide](https://support.spotify.com/us/article/understanding-your-data/)
describes playlist content but is not a normative field-schema specification;
this does not claim Spotify account Playlist.json variant compatibility.

## Model and limits

- Reuse the existing strict8MiB UTF-8, duplicate-key and24-level JSON envelope.
  Existing YourLibrary schema/semantics remain unchanged and regression-tested.
- At most200 playlists and10,000 total memberships, checked before draft models.
  Empty named playlists remain represented. Unknown root sections/wrong envelopes
  reject. Albums are counted separately, never silently made into playlists.
- Preserve playlist array positions/names/optional validated Spotify playlist
  URI and every ordered member position, including repetitions and unavailable,
  local, non-song and incomplete items. Retain available title/artist/album/URI
  and original addedAt strings for future review. No raw owner/account fields.
- Matchable tracks require a validated Spotify track URI and title/artist metadata.
  Repeated URI shares the first source track row; distinct recording URIs remain
  distinct even when title/artist match. Conflicting same-URI metadata rejects;
  no scoring or guessed metadata identity merges.
- Memberships point to unique sourceRow or retain an explicit issue without a
  matchable reference. All output collections and metadata maps are immutable.
  Position-only playlist identity is not claimed stable across repeat imports.

## Acceptance and next gate

Analysis and88 focused model/JSON/session/archive/widget regressions PASS before
strict/exact-source CI. Cases cover duplicate names with distinct positions,
repeated recordings, gaps, unsupported source metadata, conflict rejection,
wrong shapes, total limits, malformed UTF-8, escaped duplicate keys and depth.
Existing UI must keep rejecting until a versioned durable membership contract,
old/partial reads, atomic rollback, source review, routing, backup/reopen and
restart tests connect the model end to end. That is the next implementation
milestone; this draft is not a flat-import fallback or account import completion.
