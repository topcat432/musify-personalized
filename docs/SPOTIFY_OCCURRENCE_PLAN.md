# Read-only source occurrence planning prototype

Status: staged pure model, no production caller, persistence or mutation API.
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

Before mutation, the parent/owner must resolve the durable ownership-journal
format and its migration/rollback/restart proof; how an owner explicitly adopts
legacy destination occurrences; and separate confirmation for replacement,
reorder, deletion or an ambiguous retimestamped/re-added source occurrence. The
current existing-schema UI/routing authorization does not imply those new durable
semantics. The prototype deliberately leaves those decisions visible and blocked.

Bounds reuse the existing200-playlist/10000-membership codec and validate target
and baseline evidence at10000 entries and scalar IDs at2048 characters. Synthetic
pure tests cover alternatives, repeats, retry, source reorder/new session, manual
edits/removals, legacy uncertainty, collisions, changed choices, invalid dates,
unsupported/pending sources and oversize evidence. No test execution is claimed
until qualification. Empty-source reporting correction remains the active CI gate.