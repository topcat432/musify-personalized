# Single-file ZIP song-list import (F03), 2026-10-14

## Status: PARTIAL

87704dd6 remains the independently qualified stored-only checkpoint. The Android
strict platform inflater route is now implemented and host-tested, but Android
runtime/picker/cancellation/backup/restart qualification is pending. Full account
archives and ordinary multi-file exports remain unsupported. Do not treat F03 as
complete practical ZIP/account importing.

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
  during reading, and stored payload length before parsing. The 8 MiB archive
  budget includes its headers/name, so payload must fit the remaining bytes.
- Exactly one local file and one matching central record; offsets, names,
  compression method, CRC and sizes agree. No leading/trailing archive records,
  multi-disk, ZIP64, extra fields, archive/entry comments or data descriptors.
- Stored (0), and raw DEFLATE (8) when the strict Android channel is available.
  Other platforms / a missing channel fail closed for compressed entries. No
  encrypted entries or flags except UTF-8-name indication and DEFLATE level hints. Ordinary-file attributes only; no symlink or
  directory. Safe ASCII basename up to 128 bytes; no separators or `..`.
- Data stays in memory. No extraction, temporary entry file, arbitrary path,
  network resolution, credential, new runtime dependency or schema change.
- Stored payload covers its exact declared range and has equal stored/decoded
  sizes. Android DEFLATE uses the standard platform Inflater, not Dart raw
  decoding: finished must be true, bytes consumed must equal the ZIP payload,
  and exactly its one documented dummy byte must remain unused/unfed. Final
  decoded length and CRC32 must also match in Dart before preview.
- Native input feeds and output buffers are at most16 KiB. Both declared/actual
  output are capped at8 MiB; overrun is detected before excess is retained.
  One engine-owned worker runs off the UI thread, rejects overlapping jobs,
  observes owned request cancellation/interruption and20-second monotonic
  deadline, and calls Inflater.end in finally. Engine cleanup cancels only its
  worker. Dart checks the response proof and never falls back to permissive raw
  decoding; stale cancellation IDs cannot cancel the successor.
- Existing streamed reader cancellation/deadline and JSON depth/10,000-row
  limits remain. Streamed-reader finally cleanup has a1-second bound and observes
  late failures. ZIP CSV/TSV enforce10,000 data records during delimiter scanning,
  before excess records or track models are retained, and reject playlist-prefixed
  and recognized membership columns. No new durable session fields.



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

## Decoder feasibility and strict Android route

The pinned Dart3.12.2 and installed archive4.0.9 APIs cannot supply the required
completion proof. The existing Android/JDK java.util.zip.Inflater does supply
finished, consumed input and remaining input, with caller-sized buffers. This
route adds no dependency, downloaded codec or custom compression implementation.
[Bounded source/API review and alternatives](STRICT_DEFLATE_FEASIBILITY.md).
The known-defective f7d150b1 must not be signed; c249 remains independently sealed.

Host result: analysis/113 focused Dart tests and3310 standard-inflater checks
PASS, including independent fixed/dynamic fixtures, every truncation prefix,
trailing/concatenated streams, absent BFINAL, output/input/size limits, empty
blocks, cancellation and deadline boundaries. Method-channel tests are simulated
transport; host JDK proof is not Android runtime proof. CI must compile the real
Android bridge and rerun these gates. No signing/device qualification claimed.

## Stalled transport ownership

Caller timeout completes locally at20 seconds, without waiting for a platform
reply or cancellation acknowledgment. Disposal cancellation also completes
locally. At most one cancellation message targets that request ID; its reply
wait is independently bounded to1 second. The local timer is cancelled on all
completion paths. Late success/error/acknowledgment cannot resume the old import
or cancel a successor. A subsequent native request can still receive ZIP_BUSY
until the engine-owned native worker exits; no native ownership is adopted or
force-cleared. Engine/worker lifecycle remains runtime-pending.

Controlled-clock regressions cover missing replies, stalled/delayed cancellation
acknowledgment, disposal, late response/error and a successor. A real-Hive widget
fixture retains an independent prior session snapshot through timeout and late
success, then saves only the next explicitly approved preview and reopens it.
