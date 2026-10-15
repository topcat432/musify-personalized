# Explicit source-order playlist copies

Design/test milestone2026-10-15. No production writer or UI is enabled by this
first milestone. Existing pure occurrence planning and existing-format repeated
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
audit only. Pending edited content remains saved/unverified. Completed retries
with proven identity preserve later names, folder moves, manual additions/removals
and ordering without any list write. Missing/duplicate/copied/unknown proof refuses
adoption. A changed source needs a fresh preview/new operation. Creating another
independent copy also requires a separately explicit preview, not an automatic retry.

The eventual writer must share the existing routing ownership lock, durably
checkpoint before appending one new root playlist, revalidate after every await,
verify the saved marker/list, then complete the audit. Exact frozen owned-value
compensation preserves original key absence and stops at any newer owner.
Interrupted/post-commit uncertainty retains evidence and describes saved versus
unverified truthfully. Physical ENOSPC, torn-write and power-loss qualification
remain separate from injected before/after-write/reopen tests.

Codec/classifier tests first cover strict versions/fields/bounds, repeats/order,
legacy uncertainty, source/selection changes, deleted/copied/ambiguous targets and
manual edits. Existing-format tests store the actual optional proof, reopen Hive,
write/reopen/checksum a synthetic backup, independently restore/restart and compare
the complete semantic inventory including unrelated typed values. Exact CI remains
required before these are qualified. Writer fault/restart and UI confirmation
tests are the next phase; they are not yet implemented or claimed.
