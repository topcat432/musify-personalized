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

## F05-B bridge work in progress

The bridge source now wires a bounded native descriptor catalog to a non-interrupting
arrival notice and explicit inbox Preview. Native supports only the registered
import MIME types and actual content URI read grants; it never persists grants,
converts URIs to filesystem paths or caches source files. A targeted vendored-plugin
predicate excludes supported import streams from its eager media-copy path while
leaving original image/video and text-only branches intact. Native metadata types,
names and sizes are checked; raw data is capped independently of advertised size.

One native worker owns inspection/read and remains BUSY until its actual finally
exit. One cancellation worker has no queued tasks; a stuck provider cannot spawn
unbounded replacements. The local Dart deadline starts synchronously on stream
subscription, observes late replies, and cancellation addresses the exact request.
Failed previews retain an active lease for Retry or Cancel; older callbacks cannot
publish or release a successor. Widget cancellation/retry regressions are prepared.

This work is committed as a source checkpoint and remains uninstalled. Earlier Java policy/reader49 checks and
Android/Flutter Java API compilation passed; earlier Dart analysis passed. The
first transport run passed17 and failed one missing-reply deadline case. Subsequent
stream-boundary changes and new widget tests are unverified: normal3GiB host-test
admission was refused at97.21% on2026-10-14T19:32:50Z. Do not treat bridge runtime,
Kotlin/APK compilation, aggregate tests, strict visuals or exact-source CI as passed.
Actual URI grants/cold/warm intents/native cleanup remain acceptance gates.

### Bridge CI correction, 2026-10-14

Source c3abefe71646299064cdf76f18480abe6fc1b91f exact CI38627270804
passed Dart analysis and actual Java policy/reader checks, but aggregate tests
failed (695 passed, four failed); visuals and Android builds were skipped.
The fake-clock deadline assertion needs an explicit void Future continuation.
Widget preview assertions must wait for stream cleanup and the observable
review/error result; cancellation tests must settle the late owned stream before
checking timer cleanup. The correction is pending exact-source CI and makes no
native intake claim. Local updated tests remain admission-blocked.
### Request ownership and early row-budget correction, 2026-10-14

Exact a24730c CI38628233753 is terminal FAIL:698 passed/one failed.
Analysis,49 Java policy/reader and3310 inflater checks passed; strict visual
suites and Android builds were skipped. The remaining retry widget reached a
lazy preview layout whose Save button was outside its default viewport. The
successor verifies the actual preview route and scrolls to the enabled Save
control; it retains prior-state and read-count assertions.

Source review reproduced a native contract gap: ready request A attempts Preview
while metadata inspection B owns the worker; read A returns BUSY before activation.
The old finish implementation did not remove pending A, so authoritative refresh
requeued the cancelled file. Finish now releases exactly the pending or active
ID and cancels only a job owning that descriptor. The production Java channel is
exercised with deterministic API doubles and a blocked B barrier; an independently
compiled exact a24730c control must fail on A resurrection. This is channel host
proof, not actual Android grants or provider cancellation qualification.

Acquiring a lease now notifies the shared service. Global notice navigation checks
that owner, the root permits one inbox route, pending Preview buttons respect the
global active lease, and stale lease acquisition fails with retained requests.
Real Navigator/widget regressions cover A reading, A in unsaved Save review,
repeated notice taps and a second inbox route, with unchanged Hive state.

Incoming CSV/TSV alone now uses the existing maxJsonTracks early data-row budget
before retaining another row. A compact many-row fixture with a malformed tail
must reject at that budget first; the ordinary picker parser retains its existing
policy. Actual Android parsing/allocation and intake lifecycle remain unqualified;
no observed OOM is claimed. Cold semantic audit28208 remains completed PASS on
signed c249; About/Back and subsequent native gates remain separate and pending.