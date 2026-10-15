# Read-only source occurrence planning prototype

Status: pure model, no production caller, persistence or mutation API.
Exact6a8d18fc CI38657271707 qualified the initial13 tests/778 aggregate,
analysis/40 Linux visuals and required builds. Capacity/schema successor pending.
Ordinary all/first-N/individual/newly-resolved routing still transfers each
recording once. Queue entry IDs are runtime playback identities and are not
import ownership. No playback or queue changes are included.

The plan expands every resolved retained membership in source order, including
intentional repeats of a chosen recording. Unsupported or unresolved members
block a complete proposal; genuine empty sources point to the explicit zero-song
action. The model never changes source rows or destination entries, assigns tags
to legacy songs, infers ownership from recording IDs, or writes an audit/baseline.
Its canPropose flag describes a hypothetical preview, not permission to commit.
Any future mutation still needs live completeness/source/destination validation
and explicit preview/confirmation.

A validated playlist URI plus track URI and unique strict UTC added-at stamp can
supply a deterministic reusable metadata anchor. This is not an authoritative
Spotify occurrence UUID. Missing, invalid, colliding or URI-less stamps remain
scoped to the unchanged saved membership fingerprint and source position. Such
anchors cannot identify new repeats across a changed snapshot. A removed anchor
reappearing with a changed timestamp for the same source recording is ambiguous,
so the model refuses to silently append it as a new occurrence.

A verified hypothetical ownership baseline must name the exact destination and
source key, retain the earlier membership fingerprint and enumerate occurrence
IDs with selected recording identities. This is an immutable input type only;
there is no Hive key, adapter, migration, or legacy inference. Existing targets
without that proof cannot be reconciled automatically, even if counts, titles or
recording IDs match. Unknown/duplicate tags or edited recordings require review.

For a verified target the proposal only appends genuinely new anchored members.
It retains manual entries, existing order and intentionally removed owned slots;
it never restores removed songs, deletes source removals, reorders existing songs,
or replaces a chosen recording. New slots colliding with manual recordings also
require review. wouldMatchSourceOrder explicitly distinguishes an exact new
recreation from an append proposal retaining destination edits. No full sync is
claimed. Removed recorded destinations are not automatically recreated.

## Conservative create-only design, 2026-10-15

Delegated engineering defaults are now explicit: no automatic legacy adoption,
no reconciliation of manually edited destinations, a separate explicit preview
for every changed source, and refusal when ownership is ambiguous. A previously
created destination is never filled, reordered, repaired or replaced on retry.

The existing user-created playlist map already supports an ordered list of song
maps with repeated recording IDs. A new separately created snapshot can therefore
store selected recordings in source membership order without a new Hive adapter,
per-song field or queue identity. Existing add-song helpers deduplicate and must
not implement this action. Queue loading clones each slot with a fresh runtime
ID; unfiltered removal uses the actual slot index. Filtered playlist playback now carries each visible row's original slot index
into the existing full-playlist queue call. It does not look up a recording ID
or map equality, so later repeats and distinct rows sharing a recording retain
their selected position. Three actual-row regressions cover shared map instances,
case-insensitive filtered selection and unfiltered selection; both filtered
cases fail against predecessor b0f5d4f with slot1 instead of3/4. This UI correction
adds no durable occurrence tags or recreation writer. Exact successor CI and
native qualification remain separate gates.

Proposed minimum durable proof: an immutable versioned creation descriptor in
the existing import operation journal and a matching playlist-level creation
marker. Required facts are operation ID, exact destination ID, source scope,
source membership fingerprint, selected-recording fingerprint, slot count and
unique-recording count. Pending/completed phase belongs to the journal, not song
maps. These are proposed facts only: no key names, serializer or production
writer have been introduced. Counts or recording IDs alone never establish
ownership; the marker and journal must match exact IDs and fingerprints.

| State on reopen/retry | Required behavior |
|---|---|
| Legacy destination; absent descriptor or marker | Retain unchanged; never adopt by name/count/recording match |
| Partial/malformed/unknown-version proof | Retain all evidence and refuse writes |
| Pending descriptor; target absent | Refuse automatic recreation: cannot prove it was never saved then deleted |
| Pending plus exact target/marker; source unchanged | Recover audit only; never write its list again |
| Pending target exists but source/selection changed | Report saved/unverified; retain target and pending evidence |
| Completed plus exact target/marker, including later manual edits | No-op creation retry; preserve name, folder, list and order |
| Recorded target deleted or marker removed | Refuse automatic recreation/adoption |
| Duplicate destination IDs, duplicate operation markers or copied marker with another ID | Refuse ambiguous ownership |
| User explicitly requests a changed snapshot/new independent copy | Separate preview; new operation and destination IDs |

Transaction order must remain pending checkpoint, live revalidation, append one
new destination to the current authoritative collection, verify saved identity,
then audit. The shared writer lock prevents overlaps. Every callback may change
source/destination state; verify again at each boundary. Failure compensation may
restore only the exact frozen staged value owned by that writer. Independent
owner edits and key absence must survive, and post-commit errors must describe
the saved/unverified phase truthfully. No automatic import-baseline advance is
implied; slot counts and unique recording counts require separate audit fields.

Backward compatibility is additive only: no rewriting old maps or assigning
legacy tags, and unknown/partial proof remains retained. Before a writer ships,
its actual serializer and recovery classifier need synthetic version0/partial/
future-version, crash-before/after-each-write, stale/overlap, deleted/copied target,
manual edit, rollback and close/reopen tests. Saved-file checksum inspection plus
independent restore/restart must cover the new proof together with existing
library/import fields. The new existing-schema feasibility tests exercise repeated
slot reopen, independent backup restore, existing write compensation and runtime
queue cloning. They do not claim a new ownership migration has been implemented.

There is no owner-level choice needed to apply these create-only defaults. General
synchronization remains a separate material choice: replacing/reordering/deleting
or explicitly adopting occurrences in an existing destination would require its
own reviewed preview and durable per-occurrence ownership design. This design
keeps that behavior outside the new-copy action and does not enable it implicitly.

Bounds reuse the existing200-playlist/10000-membership codec and validate target
and baseline evidence at10000 entries and scalar IDs at2048 characters.
Destination plus proposed appends must also stay
at or below10000; an oversized proposal refuses all appends without dropping
manual entries. Ownership/collision lookup uses sets to avoid quadratic scans.
Synthetic pure tests cover alternatives, repeats, retry, source reorder/new session, manual
edits/removals, legacy uncertainty, collisions, changed choices, invalid dates,
unsupported/pending sources and oversize evidence. Successor qualification is
recorded in RELEASE_STATE and exact CI receipts.

## Removal sorting prerequisite,2026-10-15

One visible deletion previously removed all equal recording IDs from the page's
original-order backup. The successor tracks original positions only in memory,
including while sorting by title/artist, and removes the selected slot alone.
Default/Date added cycles retain other repeated slots in source/reversed order;
root/folder saved lists reopen with their persisted post-removal order and no
new fields. Six new widget cases plus five existing playlist cases pass locally.
Exact successor CI remains required. This fixes the page baseline; ordinary
recording-level deduplication and the separate repeated-slot Undo limitation are
unchanged. No durable occurrence creation/ownership writer is enabled.


## Explicit one-slot Undo,2026-10-15

Undo now has a live-page one-shot token, separate from ordinary deduplicating
addition. It captures the removed value/original position, validates remaining
values and exact unique live/stored destination, and permits only a complete
position permutation with that one occurrence restored. The page computes the
current sort anew, including when search is active. Runtime positions/tokens do
not enter saved songs or playlist metadata. Existing collection staging is a
single explicit Undo write, not an occurrence creation/ownership protocol.

Focused widget/service checks cover sort changes, shared repeats, root/folder
save/reopen, overlap, stale/ambiguous/partial state, typed legacy values, failure
before/after a save and preserving newer owner edits. A consumed/uncertain token
never retries or compensates over actual saved data. This closes the earlier
Undo prerequisite only after exact successor CI; native qualification remains
separate. No durable cross-restart Undo or playlist recreation is claimed.


The pending-publication guard also compares the entire affected live collection,
so an owner name/metadata edit made while the Undo write completes cannot be
replaced by its earlier staged copy. The reproduced predecessor race and31
focused checks qualify this guard locally; successor exact-source CI remains
required. Existing saved values are never compensated over or automatically
replayed when publication is stale/unverified.
