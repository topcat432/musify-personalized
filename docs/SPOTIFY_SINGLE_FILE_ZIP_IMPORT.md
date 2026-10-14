# Single-file ZIP song-list import (F03), 2026-10-14

## Supported behavior

Choose a local `.zip` / `.ZIP` using stored (uncompressed) entries containing exactly one root-level ordinary CSV,
TSV or JSON song-list file. CSV/TSV use the established title/artist parser and
row order; JSON uses the existing YourLibrary saved-track contract. The outer
filename and original logical source rows are preserved. Preview discloses the
entry name and flat-list scope; nothing is saved until explicit Save. The normal
four-key session writer, matching and routing flow remains unchanged.

This is a narrow additive ZIP adapter, not complete Spotify account-archive
support. Multi-file account exports, directories, playlists/memberships, nested
archives and synchronization are unsupported. Unsupported archives give a
retryable error; Musify never silently chooses or flattens an entry.

## Safety contract

- At most 8 MiB of selected archive bytes and 8 MiB of actual decoded bytes;
  declared size is checked before stream subscription, actual selected bytes
  during reading, and stored payload length before parsing. The 8 MiB archive
  budget includes its headers/name, so payload must fit the remaining bytes.
- Exactly one local file and one matching central record; offsets, names,
  compression method, CRC and sizes agree. No leading/trailing archive records,
  multi-disk, ZIP64, extra fields, archive/entry comments or data descriptors.
- Stored (0) only. All compressed modes, including valid fixed/dynamic raw
  DEFLATE (8), reject with guidance to choose an uncompressed ZIP or select the
  inner supported file directly. No encrypted entries or optional flags
  except UTF-8-name indication. Ordinary-file attributes only; no symlink or
  directory. Safe ASCII basename up to 128 bytes; no separators or `..`.
- Data stays in memory. No extraction, temporary entry file, arbitrary path,
  network resolution, credential, new runtime dependency or schema change.
- Compressed size equals uncompressed size and exactly covers the bytes between
  the local header/name and matching central record. Final size and CRC32 cover
  the entire stored payload; no decoder, decompression or unused input exists.
- Reader uses the existing cancellation and monotonic 20-second deadline. The
  stored adapter yields before CRC/parsing for event-loop cancellation and checks
  its own deadline before/after CRC. Existing JSON depth/10,000-track limits
  remain; ZIP CSV/TSV cap total rows at 10,000 and reject playlist-prefixed and
  recognized membership columns.


The picker may cache a native copy before Dart receives it. These limits do not
claim a native pre-copy quota. Original archive bytes are never modified.

## Acceptance

| Row | Host proof | Android qualification still required |
|---|---|---|
| F03-A | Independent Python-produced stored CSV/TSV/JSON fixtures, order, outer name and non-track disclosure | Real picker and streamed/cache behavior |
| F03-B | Traversal/nesting, unknown entry, multiple-entry header, symlink, encryption/descriptor/method, conflicting names/offsets/CRC/size, all truncation prefixes, valid fixed/dynamic and malformed/trailing DEFLATE rejection | Native cancellation/Back and feedback |
| F03-C | Preview stays unsaved, explicit Save, real Hive partial-write rollback then retry/close/reopen preserves order and unrelated favorites | Source-pinned atomic save, matching/selected-alternative routing |
| F03-D | Existing session/router regressions remain applicable; no durable schema change | Actual saved backup checksum/typed independent restore, process/full cold restart |

Host tests are not signed Android or phone data-safety proof. The immutable signed
c249395a/version300000015 baseline contains F01/F02 but not F03 and is preserved
independently. Its previously authorized emulator queue has priority once the
unchanged 26 GiB / 80% admission permits it. Samsung remains held; no phone route
substitutes for admission. This source work authorizes no new signing/publication,
merge or installation on a live device.

Initial f7d150b1 analysis/91 focused tests and CI38515969269 PASS566/40 did
not cover DEFLATE completeness. Follow-up failing-before tests proved Dart
accepts truncated/trailing raw streams when decoded CRC/length match.
That initial compressed-mode contract is superseded by this stored-only fix.
Corrective analysis and96 focused serial host tests PASS; exact-source CI is
pending. Windows strict FAIL16+24;
all40 actual PNGs remain byte-exact to the retained F02 control; representative
expected/actual/isolated diff inspected. No reference/comparator updates. Exact
Linux CI is required; no native feature proof or new signing is claimed.

## Decoder limitation and fail-closed correction

The pinned Dart3.12.2 `ZLibDecoder` / `RawZLibFilter` API exposes output chunks,
not consumed-input bytes or a verified stream-ended indicator. The existing
archive4.0.9 cache is transitive; its inflater likewise does not expose the
required completion proof. No new dependency or custom DEFLATE implementation
is introduced. Compressed ZIP support remains deferred until a trustworthy
bounded decoder can prove complete consumption/end-of-stream on supported
platforms. The known-defective f7d150b1 must not be signed. Only a separately authorized
corrected source/artifact can enter later native qualification.
