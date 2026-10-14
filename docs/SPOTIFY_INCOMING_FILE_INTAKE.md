# F05-A bounded incoming-file preview foundation,2026-10-14

The approved share/open roadmap requires a supported export to reach Musify from
an Android file manager. This first stage supplies the host-tested intake and
explicit preview/Save boundary. Android intent filters, cold/warm launch delivery,
verified URI grants, native stream transport and real-device acceptance are not
implemented by this stage and must not be reported as complete.

Offers contain validated metadata only and never open a URI, parse a file or save
an import. Only content URIs with an adapter-verified read grant are admissible;
network/file URIs, URI credentials/fragments, path-bearing/control-character file
names, unsupported extensions and declared sizes above8MiB reject. The boolean
grant field is an adapter contract, not independent evidence of an Android grant.
Native implementation must check the actual grant before constructing it and
must not add broad filesystem permission or persist grants automatically.

The in-memory inbox retains at most four pending requests and one active lease.
Arrival order is retained. Duplicate active/pending IDs or URIs do not add work;
conflicting ID/URI pairs reject without replacing existing requests. Full intake
reports full and preserves existing requests. Dismiss removes only a chosen
pending request. Restart does not persist content URIs or pretend a grant remains
valid; a future native adapter must handle redelivery explicitly.

Begin is explicit. A lease may run one read at a time. readPreview uses an owned
stream supplied by the verified native adapter and bounds every incoming format,
including unknown-size CSV/TSV, to8MiB,20seconds read and1second cleanup. Existing
ordinary CSV/TSV picker size behavior remains unchanged. Read failure retains the
active lease for deliberate retry/cancel. Finish cancels only its exact lease;
late completion, a reused label or delayed archive-choice failure cannot release
or publish a newer request. Multi-entry ZIP requires an explicit choice and
retains the existing selected-entry validation and source metadata.

A validated preview can enter the existing import page. Page construction does
not save it. Save and continue remains the sole durable replacement action;
leaving the preview preserves the prior import and completed matching data.
No URI, grant, raw source bytes or queue state is written to Hive or backup.
No adapter/schema, dependency, manifest, security or permission change in this
stage. Native worker cancellation/close, cold/warm intents, revoked grants,
background arrivals, actual picker preview/save/backup/restart and signed-source
qualification remain separate acceptance requirements.
