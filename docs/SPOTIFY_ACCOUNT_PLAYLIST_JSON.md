# Account playlist JSON compatibility

Source milestone2026-10-15; exact CI and current-source Android acceptance pending.

## Evidence before implementation

Spotify's [Understanding your data](https://support.spotify.com/us/article/understanding-your-data/)
describes the account-data playlist category and its names, songs, artists,
albums, local items, descriptions and follower counts. It is a content inventory,
not a versioned machine-readable schema specification.

The author of [The Data Spotify Collected On Me Over Ten Years](https://jrtechs.net/data-science/the-data-spotify-collected-on-me-over-ten-years)
publishes a first-hand account export example (2026-01-18, inspected2026-10-15).
It establishes Playlist1.json naming, a root playlists array, each named source's
lastModifiedDate and items array, trackName/artistName/albumName/trackUri within
track, nullable episode/audiobook/localTrack variants and day-only addedDate.
This is the primary observed structural evidence, not a promise that all past or
future account export versions use it. No personal export was obtained or copied.
The fixture uses invented titles, artists, dates, IDs and names; opaque empty
objects exercise unsupported variants without guessing their internal schema.

## Supported boundary

The production song-list dispatch recognizes the document structure, independent
of the file's name. Account sources require name, lastModifiedDate and items;
optional description, numberOfFollowers and collaborators are ignored. Root
fields other than playlists, mixed account/Web-API backup sources and unknown
playlist or track fields reject explicitly. The existing caseychu/spotify-backup
format continues through its existing parser. An account track uses only the four
evidenced fields; absent/incomplete identity stays an unsupported source slot.
Any non-null non-track variant, including mixed track/episode evidence, stays
unsupported. Null/unavailable/malformed items retain their original positions.

Shared URI recordings are matched once, while every membership and repeat keeps
its source position. Conflicting metadata for one URI rejects the complete file.
Names never establish identity: no playlist URI/ID is supplied in this observed
shape, so existing session-plus-source-position scoping applies. Supplied unknown
identity fields reject rather than being silently discarded. Day-only dates are
retained as text, never promoted to precise UTC occurrence anchors. No duration,
audio, source ID, queue ID or ownership proof is invented.

Existing bounded JSON transport/depth/scalar checks,200-playlist and10000 total
membership limits apply, counting unsupported items before translation. Preview
has no write; explicit Save retains the existing version1 membership encoding and
session lifecycle. Genuinely empty sources remain distinct from unsupported-only
sources. Existing source review, unique-recording routing and explicit empty-source
creation are reused. This does not fulfill repeated-slot destination recreation,
repeat-import synchronization, account OAuth, all account export schemas, actual
Android picker/share/ZIP behavior or any playback/release gate.

## Verification

Synthetic tests cover the production dispatch, ordered repeats/shared identities,
unsupported variants and gaps, day-only dates, empty versus unsupported, identity
conflicts, mixed/unknown structure, limits, explicit Save/reopen, partial-save
rollback with legacy key absence, and saved-file checksum inspection followed by
independent restore/reopen of the complete user inventory. Exact-source Linux
analysis, aggregate tests, both strict visual suites and required builds remain
required. Local workers remain held by host admission; injected exceptions do not
prove physical ENOSPC, torn-write or power-loss safety.
