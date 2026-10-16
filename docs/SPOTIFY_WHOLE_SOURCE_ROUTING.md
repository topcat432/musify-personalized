# Whole-source recordings selection, 2026-10-14

The approved entire-source option is a live completeness requirement on the
existing all-recordings transaction. The default Move every matched song remains
an explicit partial transfer. All/firstN/individual/newly-resolved behavior,
owner-selected alternatives, source order and successful identity snapshots are
preserved. Whole source recordings is enabled only when every retained row in
its import or selected source scope has a verified resolved decision.

Excluded rows block a whole-source claim even when exclusion is intentional.
Their decisions remain intact; the user can choose an explicit partial transfer.
Unsupported memberships and rejected input rows are disclosed separately and
never silently removed. These categories can refer to the same input item and
are not summed into a fabricated missing-song total. Named-source verification
uses its selected membership scope. Duplicate memberships are retained and
reported; each chosen canonical destination recording transfers once, in first
source occurrence order. This option does not recreate repeated playlist slots
or manufacture empty playlists.

Readiness inspects raw retained track/result/exclusion values. Missing, nonmap,
duplicate, invalid-position or malformed rows, inconsistent declared counts,
unknown result states, forward metadata, lost named-source membership and
count-only legacy state cannot imply completeness. Source labels, decisions,
recording choices, membership, rejected input counts and exclusion state
participate in a transient canonical fingerprint. It is checked for preview,
confirmation, before destination writes and around audit callbacks. Unready
sources skip fingerprint serialization. Whole verification is bounded to10000
retained rows/results,500000 visited nodes,64 nesting levels and8MiB of string
characters; its unavailability does not change ordinary file-picker policy.
Only primitive serialized data is accepted by the fingerprint traversal.

A newly added exclusion index is authoritative even if interruption left a
matched outcome for that row. Routing projects the exclusion read-only without
repairing the stored outcome or clearing the owner's index. Malformed exclusion
indices block destination writes rather than guessing the intended decision.

Routing reads current stored liked/playlist/folder collections, preserves
unrelated entries and existing order, and refreshes display caches from the
actual stored value after its owned write. Likes retain their established
new-additions-first placement; playlists append in source order. A newer
independent destination edit is never overwritten by an older display cache.
Malformed collections or folder membership reject without normalization.

The existing version1 pending/audit/baseline format is unchanged. The selection
kind remains all because the actual transfer is all unique resolved recordings;
no historical whole-readiness claim is inferred from that audit label. Pending
write failure or readiness loss before destination commit retains the source
and existing destination. A source change after an actual destination write
retains those writes and marks tracking unverified; pending uncertainty prevents
an invented newly-resolved baseline after restart. Source reload is explicit,
and failures are visible immediately as well as in the retained page banner.

## Verification state

The first guarded pass analyzed cleanly but failed43 passed/seven failed. A
bounded complete rerun failed45 passed/five failed. Diagnosis separated stale
collection-cache defects from new-test placement/type/viewport assumptions.
Final targeted51 PASS covers source completeness, all existing selectors,
permanent index interruption, owner alternative/order, duplicates, late source
changes, retry, existing destination protection, saved-file restore/reopen,
compact412x915 at2x text, visible errors and retained decisions. Analysis and
730 aggregate tests PASS after the eight independent-review regressions. Windows strict suites FAIL16+24; all40 actual images
match the preserved F02 control byte for byte; no reference images changed.
Exact Linux CI qualification remains pending for this milestone.
An exact8ff4297f control is included to reproduce the old exclusion omission.
No adapter, dependency, permission, backup schema or migration changes.

Immutable signed c249 and its installed-source/data receipts remain separate.
Cold semantic audit28208 is completed PASS. Corrected About/Back, cold-start
reliability, empty-library/rollback, picker and provider runtime remain open.
Fresh21:52:32Z unchanged26GiB/80% admission refused99.65%; nothing launched.
No phone, signing, publication, merge or unrelated emulator operation occurred.

## Declared totals and authoritative absence

Whole readiness requires an exact nonnegative integer totalDataRows and an exact
nonnegative rejectedRowCount. A flat import total must equal retained raw tracks
plus rejected rows. Named-source totals describe every saved membership across
all source playlists, including repeated and unsupported entries; rejected count
must equal unsupported memberships. A selected source does not compare the
whole-file total against its unique recording count. Declared total is included
in the preview fingerprint and revalidated before writes.

Legacy imports without verifiable totals remain available for explicit partial
routing; no completion claim is inferred or written back. CSV totals that include
unrepresented blank rows remain unknown rather than guessing which rows were
ignored. No source rows, counts or metadata are repaired.

Missing Hive destination keys mean an empty saved collection, including normal
first use and deletion or empty restore. Display caches never supply missing
likes, playlists or folders. Malformed present values fail closed. This prevents
stale display state from resurrecting removed data before or during a transfer.
Existing-target deletion during the pending checkpoint rejects without recreating
that target. Reopen regressions and an exact ce6bf615 failing control cover this.