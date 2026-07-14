# Musify import, matching, and destination roadmap

This document records the approved product direction for bringing external music into Musify. It is the source of truth for the import workflow so individual implementation changes do not lose the end goal.

## Product contract

Importing is a resumable pipeline with four independent stages:

1. Read tracks and playlist membership from a source.
2. Match each unique source recording to a playable Musify song.
3. Let the user revisit every unresolved track for as long as needed.
4. Send any chosen subset of resolved songs to an explicit destination.

No import may silently discard an unresolved song, move songs without confirmation, duplicate previously routed songs, or require matching the same source recording again merely because it appears in another playlist.

## Approved roadmap

### 1. Permanent unmatched library

- Make the unmatched count on the matching summary tappable.
- Treat both machine-unmatched and user-marked-unmatched tracks as reopenable.
- Provide Quick Review and Detailed Queue entry points whenever either kind exists.
- Keep unmatched tracks after other resolved tracks are sent to a destination.
- Allow a later successful manual match to be routed without repeating the original import.

### 2. Unrestricted manual source search

- Search structured YouTube Music songs and ordinary YouTube results.
- In manual mode, never hide a result solely because the automatic scorer rejects it.
- Continue showing confidence and identity warnings as information.
- Show artwork, title, artist or channel, album when available, duration, source, and playback preview.
- Let the user explicitly choose the correct recording.

### 3. Exact YouTube link lookup

- Accept common YouTube and YouTube Music video URLs.
- Extract the video ID and fetch the exact video's current metadata.
- Require a previewable confirmation card before saving.
- Save the normal Musify song object and canonical YouTube ID, not a special hard-coded URL entry.
- Reject malformed, deleted, private, or unplayable videos without changing the import.

### 4. General destination routing

Replace the narrow idea of "move to Liked" with a reusable Choose Destination step.

Selection options:

- all resolved songs;
- only newly resolved songs;
- the first user-specified number of songs;
- individually selected songs; or
- the entire imported source when all required tracks are resolved.

Destination options:

- Liked Songs;
- an existing Musify playlist; or
- a new Musify playlist, defaulting to the source filename or source playlist name.

Routing requirements:

- Preview new, already-present, duplicate, unresolved, and selected counts before committing.
- Preserve existing Liked Songs and playlist contents.
- Preserve source order for newly added tracks.
- Make the operation idempotent so retrying cannot create unwanted duplicates.
- Record destination history so newly resolved tracks can be synced later.
- Write changes as a controlled checkpoint and leave staged import data intact.

### 5. Playlist-aware file import

- Continue supporting flat CSV track imports.
- If a flat file has no playlist membership, offer to create one playlist for the whole file.
- Support richer JSON or compatible files that preserve multiple playlist names, ordering, track membership, and useful source metadata.
- Match each unique recording once and reuse its Musify identity across every imported playlist.
- Recreate selected source playlists individually or route selected tracks elsewhere.

### 6. Direct Spotify connection

- Use Spotify Authorization Code with PKCE rather than retired implicit authentication.
- Allow Spotify Liked Songs to Musify Liked Songs import.
- Allow Spotify playlist-to-new-playlist and playlist-to-existing-playlist import.
- Allow selected Spotify songs to any supported destination.
- Checkpoint pagination and matching, handle rate limits, and resume interrupted work.
- Clearly report playlists or tracks Spotify does not permit the connected account to read.

## Delivery order

1. Restore permanent access to every unmatched track.
2. Add unrestricted manual search and exact YouTube-link lookup.
3. Add generalized destination routing, including Liked Songs.
4. Add flat CSV whole-playlist and selective routing.
5. Add playlist-aware JSON/file importing.
6. Add direct Spotify connection and synchronization.

## Safety and acceptance rules

- Never require uninstalling the existing app or clearing user data for an upgrade.
- Never restart a completed matching run merely to reopen unmatched songs.
- Never count a song as routed until the destination write succeeds.
- Never remove staged results after routing; they are the resumable audit trail.
- Every migration and routing operation must be tested for duplicates, retries, partial completion, existing destination contents, empty selections, and app restart.
