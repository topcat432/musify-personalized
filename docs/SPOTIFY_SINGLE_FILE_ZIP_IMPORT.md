# Single-file ZIP song-list import (F03), 2026-10-14

## Supported behavior

Choose a local `.zip` / `.ZIP` containing exactly one root-level ordinary CSV,
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
  during reading, and decoded size throughout DEFLATE output.
- Exactly one local file and one matching central record; offsets, names,
  compression method, CRC and sizes agree. No leading/trailing archive records,
  multi-disk, ZIP64, extra fields, archive/entry comments or data descriptors.
- Stored (0) and raw DEFLATE (8) only. No encrypted entries or optional flags
  except UTF-8-name indication. Ordinary-file attributes only; no symlink or
  directory. Safe ASCII basename up to 128 bytes; no separators or `..`.
- Data stays in memory. No extraction, temporary entry file, arbitrary path,
  network resolution, credential, new runtime dependency or schema change.
- DEFLATE receives at most 256 input bytes per feed; decoded output is checked
  before retention against both the 8 MiB limit and declared length. Final length
  and CRC32 must match. Small feeds avoid presenting the whole compressed input
  to one decoder allocation. Each 4 KiB of compressed input yields to the event
  queue so UI cancellation can run. Header-only inflation limits are insufficient.
- Reader uses the existing cancellation and monotonic 20-second deadline;
  asynchronous inflation observes cancellation and its own 20-second deadline.
  Existing JSON depth/10,000-track limits remain; ZIP CSV/TSV also cap total rows
  at 10,000 and reject playlist-prefixed columns as well as known membership columns.

The picker may cache a native copy before Dart receives it. These limits do not
claim a native pre-copy quota. Original archive bytes are never modified.

## Acceptance

| Row | Host proof | Android qualification still required |
|---|---|---|
| F03-A | Independent Python-produced stored TSV/deflated CSV/JSON fixtures, order, outer name and non-track disclosure | Real picker and streamed/cache behavior |
| F03-B | Traversal/nesting, unknown entry, multiple-entry header, symlink, encryption/descriptor/method, conflicting names/offsets/CRC/size, all truncation prefixes, forged-size inflation bomb | Native cancellation/Back and feedback |
| F03-C | Preview stays unsaved, explicit Save, real Hive partial-write rollback then retry/close/reopen preserves order and unrelated favorites | Source-pinned atomic save, matching/selected-alternative routing |
| F03-D | Existing session/router regressions remain applicable; no durable schema change | Actual saved backup checksum/typed independent restore, process/full cold restart |

Host tests are not signed Android or phone data-safety proof. The immutable signed
c249395a/version300000015 baseline contains F01/F02 but not F03 and is preserved
independently. Its previously authorized emulator queue has priority once the
unchanged 26 GiB / 80% admission permits it. Samsung remains held; no phone route
substitutes for admission. This source work authorizes no new signing/publication,
merge or installation on a live device.

Host result: analysis and91 focused serial tests PASS. Windows strict FAIL16+24;
all40 actual PNGs remain byte-exact to the retained F02 control; representative
expected/actual/isolated diff inspected. No reference/comparator updates. Exact
Linux CI is required; no native feature proof or new signing is claimed.
