# Explicit empty source playlist creation

Status: source milestone; exact CI and runtime acceptance pending.

Saved named sources with genuinely zero memberships offer **Review empty playlist
creation**. The dialog states zero source items and zero transferred songs. Cancel
changes nothing. Confirmation creates one ordinary user playlist using its source
name, or reuses its already linked destination without modifying name, location,
contents or unrelated library data. Preview-only source pages cannot create.
Nonempty unmatched, excluded, unsupported or rejected membership is never treated
as an empty source. Flat files without named membership do not acquire this action.

An empty-only named backup can be saved for source review. A mixed document with
empty and unsupported sources retains every unsupported membership; those sources
cannot create empty destinations. A document containing only unsupported nonempty
sources still rejects rather than claiming a complete import. Saving source
membership itself never creates a destination or transfers songs. The saved import
page opens the actual saved source review, rather than a preview-only route.

Identity uses the validated Spotify playlist URI when present; otherwise it uses
saved import-session identity plus source position. Names never establish identity.
Retries find the linked source key independently of destination title, retaining
user renames, folder moves and intentional additions. Multiple linked destinations
are ambiguous and reject. A recorded destination that was removed or relinked is
not recreated automatically. Cross-import reuse needs a stable URI; URI-less
sources from a later session are distinct and only create after new confirmation.
This is not repeated-slot recreation, repeat-import synchronization or reconciliation.

The existing transfer ownership lock serializes creators and song transfers.
Live session, source membership, declared totals and completeness fingerprint are
validated at confirmation and after persistent callbacks. A source changing after
preview rejects; an independent destination edit is never overwritten. A source
linked destination appearing during the pending callback rejects duplicate creation.
A durable pending marker precedes the library write. No silent ignored checkpoint
is accepted as persistence. Owned metadata and destination failures compensate only
an exact owned staged value, including original key absence; newer values survive.

A completed routingHistory entry explicitly records action=create_empty_source_playlist,
source key/fingerprint, destination ID/title, sourceItemCount=0, selectedCount=0,
addedCount=0, songTransfer=false and whether a playlist was created or reused.
It carries no resolved-recording snapshot and never advances or invents the
last-successful recording-transfer baseline. Unknown legacy baseline stays unknown.
An unresolved song-transfer journal cannot be completed by an empty action.
Interrupted or failed final audits retain uncertainty; retry reuses the durable
linked destination without creating a duplicate. If its destination disappeared,
review is required rather than silently recreating intentional deletions.

Existing map/list shapes and version1 backup decoding suffice. No adapter, schema,
dependency, permission or migration changes. Older binaries can retain/read the
ordinary custom playlist and optional metadata but cannot offer this new action.
No playback or queue semantics change; source repetitions remain retained with the
existing disclosure. Synthetic pure, widget, rollback, reopen and actual saved-file
independent restore regressions are included. Their qualification is pending.

Qualified predecessor7db12a5d exactCI38647486899 PASS includes aggregate tests,
strict Linux visuals, production channel/policy/inflater controls and required
Android builds. Its Windows strict suites FAIL16+24 with all40 actuals byte-equal
to preserved F02 control. Fresh22:49:42Z unchanged3GiB host guard refused92.63%;
no formatter, analyzer or test process launched for this milestone. Native c249
and cold semantic audit28208 remain separate; no current-source runtime, signing,
publication, merge, phone or unrelated-emulator operation is implied.