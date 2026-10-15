# Explicit source-order playlist copies

Implementation milestone2026-10-15; exact-source CI and Android runtime
qualification are tracked separately in PR23 and the canonical evidence ledger. Existing pure occurrence planning and existing-format repeated
slot storage/queue/rename/Undo qualification remain prerequisites, not fulfillment.

The action is a separately confirmed new user-created playlist containing every
resolved source membership in original order, including repeated selected
alternative recordings. Unresolved, excluded, unsupported, incomplete and empty
sources refuse this action; genuine empty sources retain their separate action.
Ordinary all/first-N/individual/newly-resolved transfers remain unique-recording
operations. No reconciliation, adoption or destructive synchronization is added.

## Minimum persistent facts

The existing Hive playlist map/list format safely represents repeated song maps.
Idempotent recovery additionally needs explicit durable ownership evidence. This
is an additive optional protocol, not an adapter/global-schema version change or
automatic migration: a playlist-level importSourceCopyProof map and matching
copyProof inside the existing routingInProgress/routingHistory operation envelope.
Version1 records operation/destination/session/source identities, source membership
and ordered selected-recording SHA256 fingerprints, slot count and unique count.
Phase belongs to the operation envelope, never song rows. No queue or occurrence
tags are persisted. The copy does not receive ordinary-routing source-link/name
fields, so unique-recording routing cannot implicitly adopt it by name or scope.

No old playlist or count-only audit is converted. Older binaries may retain these
optional maps but cannot certify the new action; removed/malformed/future markers
remain unverified. New code never repairs or downgrades such proof. Completing a
copy audit does not advance the existing last-successful recording-transfer
baseline or invent a baseline for legacy count-only history.

## Recovery and write boundaries

Pending without a target cannot distinguish never-saved from intentionally
deleted: refuse automatic recreation. Pending plus exact unique marker/target and
unchanged source/selection with the exact recording-slot sequence may recover
audit only. Pending changed recording IDs, order or counts remain saved/unverified. Song
metadata edits are retained; the fingerprint certifies ordered recording identity,
not ownership of later titles/artists. Completed retries
with proven identity preserve later names, folder moves, manual additions/removals
and ordering without any list write. Missing/duplicate/copied/unknown proof refuses
adoption. A changed source needs a fresh preview/new operation. Creating another
independent copy also requires a separately explicit preview, not an automatic retry.

The writer shares the existing routing ownership lock, durably
checkpoints before appending one new root playlist, revalidates after every await,
verifies the saved marker/list, then completes the audit. Exact frozen owned-value
compensation preserves original key absence and stops at any newer owner.
Interrupted/post-commit uncertainty retains evidence and describes saved versus
unverified truthfully. Physical ENOSPC, torn-write and power-loss qualification
remain separate from injected before/after-write/reopen tests.

Codec/classifier tests first cover strict versions/fields/bounds, repeats/order,
legacy uncertainty, source/selection changes, deleted/copied/ambiguous targets and
manual edits. Existing-format tests store the actual optional proof, reopen Hive,
write/reopen/checksum a synthetic backup, independently restore/restart and compare
the complete semantic inventory including unrelated typed values. Exact CI remains
required before these are qualified. The writer and actual UI tests now cover explicit preview/Cancel/Confirm,
repeated selected alternatives, unknown legacy baselines, shared audit lock,
stale/newer owners, acknowledged/ignored writes, before/after failures and closed
Hive handles followed by reopen. These are injected storage/restart models, not
native power-loss qualification. The source-copy UI exposes an explicit separate
additional-copy preview and permits audit-only verification on re-entry. Normal
partial/unique transfers remain separate and cannot bury a pending copy journal.
Synthetic compact2x before/created/unverified screenshots and a state-difference
image are captured for review; no golden is updated by these captures.

After any destination attempt, a missing target stays unknown even if an owned
exception compensation restored the original root. Its pending attempt is kept
for review; it is never silently cleared to make a retry create another copy.
Original-key absence and still-live original owner references survive verified
compensation, keeping selected-slot rename/Undo valid. A pinned d3d2fc8a control
must fail the composed post-compensation rename test with its specific marker.
The ownership scan refuses a new target beyond10000 destinations before writing;
existing entries are never truncated.
