# Musify Personalized current state

## Selected-occurrence playlist rename correction,2026-10-15

The existing custom-playlist rename writer selected the first matching recording
ID while SongBar subsequently mutated the selected map. Repeated recordings or
shared map references could therefore rename other occurrences. The callback also
used the dialog context after it closed and could omit the page refresh.

The successor captures the selected full-list index and full source values when
opening the dialog. Its one-shot writer stages a separate existing collection,
refuses stale/ambiguous source or live/stored collection divergence before writing,
and awaits the save before ownership revalidation and publication. It retains
actual saved values after uncertainty/newer owner writes without compensation or
replay. Only the captured occurrence's title/artist changes; alternatives, typed
metadata, all other occurrences, source order, folder metadata and unrelated
playlists are retained. The runtime sort permutation is inverted before saving,
so a rename in Date added/Name/Artist view retains original source order after
restart; the page then reapplies the current view sort in memory. The page adopts the saved target and resynchronizes its
runtime sort/source mapping. Confirm is consumed before its callback/navigation,
so a repeated press cannot save again or pop the underlying page. The eight
view cases invoke the actual Confirm callback twice. No persistent identity,
field, adapter, migration,
backup-format, dependency or rendering change; liked-song semantics are unchanged.

The initial test-only27e74dc3 run was cancelled after a disk/fake-clock fixture
stall and is non-qualifying. The actual dialog Confirm callback now runs in the
root zone, retaining field validation/close and all data assertions. Corrected
test-only predecessorfd65eccb09b5bc271a3b28595f6bcbb049416415
[CI38683871748](https://github.com/topcat432/musify-personalized/actions/runs/38683871748)
PASS analysis and820 tests, including Cancel in both locations; eight repeated-row
views and both stale-dialog cases FAIL at their intended preservation assertions.
Default view renamed two occurrences instead of one; stale views renamed the
first row after the selected row changed. No timeout counts as defect evidence.
Successor qualification is pending. The successor additionally
covers dialog Cancel/stale source and twenty Hive-backed writer boundaries.

Undo source300fe46bfff94dcbed18b828d0d0bb09a3ed404d passed
[exact CI38681704615](https://github.com/topcat432/musify-personalized/actions/runs/38681704615):
818 aggregate tests,16+24 strict Linux visuals,analysis,nine logger tests,
49 reader/30 channel/3310 inflater checks and all required Android builds.
Its implementation remains unchanged during independent review.

Five verified orphaned October13 Musify Flutter test runners had absent parents,
exact checkout/storage-session paths and only same-launch console children.
Their identities were saved outside Git, rechecked before stopping, and all ten
processes were verified absent. No unrelated process or retained evidence was
removed. Host commit remains above97% with less1GiB physical memory available;
no local worker/emulator was launched. Native signed-baseline recovery remains
first when unchanged admission permits, then F01/F02. No device/provider request,
phone, merge, signing or publication action.

## Pre-write collection divergence guard,2026-10-15

Independent review found that the preceding live-publication guard only covered
changes made during the write. An unrelated replacement-map edit already pending
in live memory could still be overwritten from Hive, even while the target
playlist retained its shared identity. Undo now requires complete equality of
the affected live/stored root or folder collection before its first write, and
retains the existing post-write ownership checks. Divergence refuses Undo without
writing or reconciling either state; stored-only legacy entries remain untouched.
No schema, persistent field, migration, adapter, dependency or visual change.

Five additional Hive-backed regressions cover pending root metadata, folder-child
metadata and folder names, plus omitted stored-only legacy entries in both
locations with byte-exact saved-file and reopen assertions. The positive unrelated
playlist fixture explicitly loads that playlist into both live and stored state;
it no longer assumes Undo should adopt an unloaded stored collection.
The test-only predecessor control is exact source
4cb49596c7a1aee695fc72441cfefeef2361ac96,
[CI38681101358](https://github.com/topcat432/musify-personalized/actions/runs/38681101358).
Analysis and813 existing tests PASS; all five new cases FAIL as expected,
returning incorrectly successful Undo results instead of refusing. This is a
qualifying defect control, not a passing candidate. Corrected successor
qualification is pending:818 aggregate checks expected, plus strict Linux
visuals and all required builds.

Predecessor0bd4d5ef5435a0f22faf0c6efb40bc339dc180b2 passed
[exact CI38678970112](https://github.com/topcat432/musify-personalized/actions/runs/38678970112):
813 aggregate tests, analysis,16+24 strict Linux visuals,nine logger tests,
49 reader/30 channel/3310 inflater checks and required Android builds.
That does not qualify this successor. Local workload admission is unavailable:
measured available physical memory fell below1GiB and host commit exceeded80%
before additional source-test or26GiB native allowances. Limits remain unchanged.
Native isolated signed-baseline recovery, F01/F02 acceptance and provider playback
remain outstanding; no device/provider operation, merge or publication occurred.

## Pending live metadata publication guard,2026-10-15

Undo predecessor b595e6ef7b721b2c7b8f8e3a05368d504f1fff52 passed
[exact CI38677859310](https://github.com/topcat432/musify-personalized/actions/runs/38677859310):
812 aggregate tests,analysis,16+24 strict Linux visuals,nine logger tests,
49 reader/30 channel/3310 inflater checks and required Android builds.

A final synthetic control reproduced a publication race: a playlist-name or
unrelated playlist metadata edit made in live memory during Undo's write was
replaced by the staged collection. The successor snapshots the entire affected
live collection before awaiting and refuses publication if any of it changes.
It preserves pending owner edits and retains actual saved data without rollback
or replay. No schema/field/adapter/dependency or UI rendering change.

Current focused PASS31 (ten Undo views,ten service boundaries,eleven prior playlist
checks). The added predecessor case fails with an incorrectly successful staged
result; corrected checks retain both pending names. Local aggregate812/strict
Windows control evidence belongs to b595; exact successor aggregate/analysis/
strict Linux/build qualification is required. No additional heavy local full run
is inferred during measured host physical pressure. Native recovery remains
outstanding under unchanged limits, followed by F01/F02; six c249 fixtures and
all original/isolated comparison evidence remain preserved. No device operation,
provider request, signing/publication or merge.

## One-shot repeated-slot Undo,2026-10-15

Predecessor bb4cbdb78b9a9d7ecbef8f118e673964668a7e35 passed
[exact CI38673559643](https://github.com/topcat432/musify-personalized/actions/runs/38673559643):
analysis,793 aggregate tests,16+24 strict Linux visuals,nine logger tests,
49 reader/30 channel/3310 inflater checks and all required Android builds.
Independent review closed its deletion/sort preservation correction.

Its Undo callback still used deduplicating addition and the deleted row's old
visible index. The successor captures one removed song's full value and original
position in memory. It validates the remaining source and exact live/stored
custom destination, rejects ambiguity/replacement/partial legacy containers,
and restores only a complete permutation of those retained slots plus that one
captured occurrence. It recomputes the current Default/Date added/Name/Artist
order independently of the old visible or filtered index. No song or playlist
field, adapter, backup format, dependency or durable Undo journal is added.
Ordinary add-song and recording-level destination deduplication stay unchanged.

The token is consumed before awaiting its sole write. A separately staged copy
of the existing collection preserves old Hive values on pre-write failure;
post-save uncertainty or a newer owner write never triggers compensation over
actual saved data. Success requires live and stored revalidation before updating
library/page references. Unverified attempts show the existing error and do not
automatically replay. Runtime Undo expires with the page/restart; restored data
uses the existing persistent list format.

Focused PASS30: ten widget cases change sort between deletion and Undo, keep
search active, cover shared-map repeats/direct/folder lists, double/overlapping
Undo, subsequent Default/Date added cycles and disk reopen; nine service cases
cover frozen alternatives/typed legacy fields/metadata changes, stale/replaced/ambiguous targets,
raw unrelated playlists, invalid positions, failed/after-save writes and late
owner edits; eleven prior playlist checks remain PASS. The asymmetric Default
case requires slot3 instead of old slot1. All ten final widget controls fail on
byte-exact bb4cbdb7 UI copied outside the checkout; no dirty source was replaced.
Analysis and812 aggregate tests PASS. Strict Windows FAIL16+24; all40 actual PNGs match the retained control exactly.
Reference/actual/isolated diff inspected; no golden/comparator change. Exact
successor Linux CI remains pending.

Native baseline recovery remains outstanding behind unchanged admission; original
5558,5560 configuration/comparison evidence and empty export remain preserved.
Six checksum-indexed host-only native F01/F02 inputs are validated against byte-
exact signed c249 parser blob8a63cc802dd6fc7326ec2bc1fc15bdf76b3b4fc5. No device
copy, provider request, phone operation, signing/publication or merge occurred.

## One-slot deletion across sort changes,2026-10-15

Predecessor36c389260772fdb5e9ca7fe18f842506489c93b3 passed
[exact CI38670791363](https://github.com/topcat432/musify-personalized/actions/runs/38670791363):
analysis,787 aggregate tests,16+24 strict Linux visuals,nine logger tests,
49 reader/30 channel/3310 inflater checks and all required Android builds.
Independent review closed its filtered repeated-slot playback correction.

Review found a pre-existing removal defect: deleting one visible slot persisted
that one deletion, but the page removed every equal recording ID from its original
sort baseline. Default/Date added could therefore hide retained repetitions.
The successor keeps an in-memory displayed-slot-to-original-position mapping,
sorts those positions with the existing title/artist comparator, and removes only
the selected original position. Runtime positions never enter stored song maps.
It refreshes current song values before reordering and recaptures the visible
baseline after an outside list-length change. No new durable identity, adapter,
backup format, dependency or service writer is introduced.

Five exact-predecessor callback regressions reproduce retained slots disappearing
across all sort modes/root and folder storage. Corrected focused tests PASS11,
including a sixth case deleting a later shared-map instance, Default/Date added
cycles, disk close/reopen, retained order, unrelated values and stored-key checks.
Fixture callbacks own real Hive writes outside Flutter's fake clock; queued
open-box continuations drain before close. Earlier timed-out fixture attempts and
exact PID/creation-time owned cleanup evidence remain outside Git. No timeout or
fixture failure is counted as product proof. Analysis and793 aggregate tests PASS; strict Windows FAIL16+24 with all40 actuals byte-exact to the retained control.
Reference/actual/isolated diff inspected; no golden/comparator changed. Exact
successor Linux CI remains pending. Repeated-slot Undo still uses deduplicating
addition and is a separate unqualified boundary; this is not playlist recreation.

Native baseline recovery on5560 remains outstanding behind unchanged physical/
commit admission controls. Empty-export evidence and original5558 are preserved;
F01/F02 native work stays queued after recovery. No current-source installation,
provider request, phone operation, signing/publication or merge occurred.

## Isolated empty-export proof and playlist slot correction,2026-10-15

Current candidate predecessor b0f5d4ffcee3939311ee7218e91b520c757fe3b8 passed
[exact CI38666790364](https://github.com/topcat432/musify-personalized/actions/runs/38666790364):
analysis,784 aggregate tests,16+24 strict Linux visuals,nine logger tests,
49 reader/30 channel/3310 inflater checks and all required Android builds.
Its predecessor aa894e2d run38666177250 was cancelled, not passed.

The isolated5560 working clone uses the same API35 Google APIs x86_64 system
image,2GiB guest RAM and four vCPUs as saved5558. It changes1080x2400/density420
to720x1280/density320, swiftshader_indirect to swiftshader, and layered userdata/
encryption disks to self-contained QCOW2 copies independently compared logically
identical. Original5558 files/configuration remain preserved. One cold Launcher/
Settings/c249 probe had usable hierarchies without ANR, not repeatability proof.
Several variables changed together; no single-cause attribution is established.
Observed owned peak private bytes4,679,602,176 and peak working set4,127,690,752;
minimum available host bytes12,576,444,416 during that probe. Early paging settled
before the app phase. Guest RAM/vCPU,26GiB commit forecast,80% threshold and8GiB
physical reserve were not reduced. No global memory/pagefile/security change.

Signed c249 empty restore, app-process restart, actual saved-file reopen/checksums
and independent typed Hive close/reopen PASS on5560. The export has zero user/music/
import entries and exactly one intentional update-check opt-out setting. Full
guest cold restart and signed-baseline rollback remain outstanding. Recovery-only
launch was refused before startup for insufficient physical reserve; no emulator
is running and the lease is free. Normal-debug four Hives remain exact/mode600.
Canonical private evidence: c249-isolated-empty-independent-index.json and
optional-batch-f01-f02-acceptance.json under the established evidence root.
F01/F02 native acceptance has not started. Current candidate is not installed;
provider reliability, actual phone, signing/publication and merge gates stay held.

The next bounded source correction preserves original playlist slot indices when
searching repeated recordings. It keeps queue order and chosen row position,
including repeated references to one map and different rows with the same ytid.
Predecessor filtered taps reproducibly chose slot1 instead of3/4; corrected actual
widget tests PASS5. No schema, stored list, golden, dependency or provider change.
Analysis and787 aggregate tests PASS. Strict Windows FAIL16+24, with all40 actual PNG hashes matching the retained control exactly; reference/actual/isolated diff inspected. No reference change. Exact successor Linux CI remains pending.

## Signed c249 owned5558 update/data checkpoint,2026-10-14

Immutable signed c249395a4dc0a151a73f8402afdfc444eb140261 installed in place on
emulator-5558,300000012→300000015,UID10210 retained. Installed APK SHA256
fed354d5c8594826135863d14fbdc0248d9c54565687934219ffcd1fcd1ef469 matches the
independently verified artifact. Actual post-update and fresh cold-boot exports
were checksum-validated and independently reopened as typed Hive. Both complete
user/settings semantic inventories match the pre-update baseline exactly:4 imports,
4 results,1 exclusion,5 favorites,2 playlists,8 user keys and6 settings keys; list
order and selected identities are covered by full comparison. A changed kernel
boot ID and visible-frame gate support the successful cold cycle; it needed no
System UI Wait action. Four normal-debug Hives restore byte-exact/mode600.

Earlier cold cycles failed with black rendering and a captured Android System UI
ANR; retained failures prevent a blanket reliability pass. About correctly shows
v0.1.300000015(300000015) in accessibility description; a text-only probe falsely
failed. Corrected About/Back, empty/rollback, F01/F02 picker and playback work remain
queued. The About/Back launch was refused at88.91% projected host commit; subsequent
read-only measurement19:09:26Z was93.97%, with unchanged26GiB/80% planning.
No Samsung, new signing/publication or merge. Dirty intake bridge was preserved,
uncommitted and uninstalled; newer F03/F04/F05 host evidence is separate. Private
canonical milestone: host-provider-diagnostic/c249-native-update-restart-milestone.json.

## F05-A incoming-file preview foundation,2026-10-14

The approved Android share/open roadmap now has bounded in-memory intake and a
validated-preview entry to the existing explicit Save flow. Offers never read or
save; active leases own cancellation and stale callbacks cannot release newer
requests. All incoming formats have8MiB/20second/1second read/cleanup bounds;
ordinary picker CSV/TSV policy remains. ZIP choice stays explicit. The prior import
and completed work remain unchanged until Save. [Contract](SPOTIFY_INCOMING_FILE_INTAKE.md).
This is partial host infrastructure: intent handlers, actual URI grant verification,
native transport and runtime acceptance are not yet implemented/qualified. No
manifest, adapter, backup format, dependency or permission change. Immutable c249
and queued native acceptance remain separate. Analysis/40 focused and688 aggregate
tests PASS. Both strict Windows suites FAIL16+24/all40 actuals match unchanged
control. Exact-source Linux CI remains required for this foundation.

## Saved membership read integrity correction,2026-10-14

An independent review found that saved source review decoded membership without
checking its import-row references. Four reopen regressions reproduced false
retained-song display for missing rows, changed recording URIs and missing URIs.
Saved review and destination loading now validate the raw stored track list and
exact row/Spotify-track-URI references before projecting any membership. Invalid
references show the retained-data error; no damaged values are repaired or written.
Structural decoding also rejects missing/invalid URIs for supported memberships.
Save and direct destination projection share the same reference validation. Legacy
absence, unsupported memberships and valid saved membership retain their behavior.
Analysis and25 focused checks PASS. Guarded aggregate PASS681, including seven
uncommitted inbox tests; the source-only correction adds eight tests to666.
Both strict Windows suites FAIL16+24; all40 actual images match the unchanged
control byte-for-byte. Exactc874d11d CI38609076258 PASS674/40,3310 inflater checks and all required builds. The incoming-file inbox
prototype remains outside this correction.
No adapter, backup format, dependency or permission change. Native/signing/phone
acceptance remains separate; immutable signed c249 is unchanged.

## F04-D source-specific resolved-song routing,2026-10-14

Saved source review now opens the existing explicit destination preview/Apply
flow, constrained to the chosen source in first membership-occurrence order.
Chosen recordings, pending/unsupported items and source repetitions stay retained.
Scoped target keys separate same-name sources and unrelated existing playlists;
retries/restart and saved-file restore preserve scope/order. Source fingerprints
reject stale membership before writes; a late membership change leaves actual
writes intact with unverified tracking. Failed destination writes roll back only
the exact owned staged value, never a newer independent edit. [Contract](SPOTIFY_SOURCE_PLAYLIST_ROUTING.md).
The playlist-ID/URI conflict guard prevents assigning a contradictory source key.
Targeted service/widget and identity tests, aggregate analysis and666 tests PASS; exactfe49a732 CI38605348118 PASS666/40,3310 inflater checks and all required builds. Windows strict FAIL16+24/all40 actuals unchanged. Test-only root-zone
I/O adapters resolve the Flutter fake-clock fixture; production defaults remain.
No global adapter/backup format/dependency/permission change. Exact repetition
recreation, empty-only sources, account schemas and repeat synchronization remain
unfulfilled; immutable signed c249 and its native queue remain separate.

## F04-C durable named-playlist intake/review,2026-10-14

Direct JSON and selected ZIP payloads now connect the precise named-playlist
producer model to explicit preview/Save, version1 membership metadata and retained
source review from the hub. Ordered/repeated memberships, unsupported item labels
and dates survive checkpoint, routing retry, backup restore and restart. Missing
reference rows reject before writes; old absence is readable, and malformed or
forward-version data is retained with an error. Same-URI artist lists compare
structurally, and supplied track-ID conflicts retain an unsupported member at its
original position. [Contract](SPOTIFY_PLAYLIST_MEMBERSHIP.md). No global adapter,
backup format, dependency or permission change. Analysis and651 aggregate tests
PASS; exact859a16c3 CI38596632931 PASS651/40,3310 inflater checks and all required builds. Final targeted suites and both strict Windows suites ran. Windows remains
FAIL16+24/all40 actuals unchanged. Exact-source CI pending. Native/signing/phone
qualification is separate; c249 unchanged. Source-playlist recreation and repeat
synchronization are not implemented and are the next roadmap milestones.

## F04-B membership draft model,2026-10-14

A separate transient named-playlist JSON source model now preserves ordered
memberships, repeated recording references and unavailable/local/non-song gaps,
including available source labels and original added-date strings. Same-URI
conflicts reject; distinct recording URIs never merge merely by title/artist.
[Precise producer contract and next durable gate](SPOTIFY_PLAYLIST_DRAFT.md).
Analysis/88 focused tests PASS; Windows strict FAIL16+24/all40 actuals unchanged.
Exacte9379828 CI38591350970 PASS636/40,3310 inflater checks and all builds. This source-model checkpoint still rejected playlist JSON until controlled durable
membership/review/routing/backup/restart support is connected. No schema or
installed baseline change; signed c249 native acceptance remains separate.

## F04-A explicit archive selection,2026-10-14

Expanded owner direction authorizes continuous planned host milestones while
native admission is blocked. Explicit bounded multi-entry ZIP choice is now
implemented; [contract](SPOTIFY_ARCHIVE_SELECTION.md). Selected source entry
provenance survives the existing controlled metadata write; memberships still
reject instead of flattening.89 focused tests/analysis and the saved-file
backup restore/reopen regression PASS. Windows strict FAIL16+24, all40 actual
images unchanged from control. Exact597cd242 CI38589804406 PASS624/40,3310 inflater checks and all required builds. No new codec/dependency/permission/adapter. This is
not full Spotify account archive fulfillment. Immutable signed c249 and its
native queue remain separate; no device/signing action. Next is membership-aware
JSON source modeling with precise producer compatibility and preservation.

## File cleanup and early ZIP row-budget correction,2026-10-14

A controlled-clock regression reproduced an indefinitely pending streamed read
when its provider's onCancel future never completed. The reader now bounds its
finally cleanup to one second, observes late cleanup failures, and preserves the
original read failure. A read timeout therefore settles within20+1 seconds.
ZIP CSV/TSV now pass an optional10,000-data-record budget into the delimiter
scanner, rejecting before retaining excess records or constructing track models.
Direct CSV/TSV defaults remain unchanged. Quoted multiline records, original
logical positions and ignored trailing blank records retain their semantics.
Real Hive widget regressions cover old session/decisions/exclusions/favorites,
close/reopen, late cleanup failure, successor preview and explicit Save/reopen.
Analysis and86 focused tests PASS; Windows strict FAIL16+24, with all40 actual
images byte-identical to retained control. Exact2371f1b6 CI38583443183 PASS598/40,3310 inflater checks and all required Android builds. No schema/dependency,
reference-image, signing or device change; F03 remains PARTIAL.

## F03 stalled transport correction,2026-10-14

Deterministic regressions at the exact d06f24b6 CI checkpoint exposed delayed
caller completion when cancellation acknowledgments/replies were absent. The
Dart adapter now owns a cancellable20-second local timer, settles disposal/
request cancellation promptly, sends at most one targeted cancellation attempt
with1-second acknowledgment bound, and ignores late reply/error/acknowledgment.
The native worker remains separately engine-owned with its existing deadline;
this is not native lifecycle proof. Analysis and27 focused transport/widget
tests PASS; Windows strict FAIL16+24 and all40 actuals match retained control.
Exact-source CI will qualify the correction before native results are attributed.
Exact d06f CI38522644850 PASS588/40 and its3310 standard-inflater proof remain
preserved; c249 signed and87704 stored checkpoints are unchanged. F03 PARTIAL.

## F03 PARTIAL: strict Android inflater route,2026-10-14

Bounded review found a trusted existing Android/JDK standard-library route;
[API/source findings](STRICT_DEFLATE_FEASIBILITY.md). A thin adapter requires
verified end-of-stream, exact consumed bytes, no unused input, capped output,
owned cancellation/deadline and finally cleanup. No dependency/codec download
or custom DEFLATE implementation was added. Host3310 inflater checks and
analysis/113 focused Dart tests PASS; exact CI/real Android bridge compile pending.
F03 remains PARTIAL for practical compressed/account archives: Android runtime,
picker/lifecycle/data proof and full multi-file membership semantics are open.
Other platforms/missing channel fail closed for compression.87704dd6 remains the
safe stored checkpoint; f7d150b1 must not be signed; c249 signed APK is unchanged.
No device/signing/other-workload changes occurred in this review.

## F03 integrity correction,2026-10-14

Post-CI adversarial tests exposed a real decoder limitation: truncated or trailing
DEFLATE payloads can pass Dart raw decoding with valid output CRC/length. Existing
APIs expose no verified consumed-input/end marker. F03 now fails closed for all
compressed ZIP methods, including valid fixed/dynamic DEFLATE; only uncompressed
stored entries are supported, with exact envelope/size/CRC and cancellation.
Initial f7d150b1 CI38515969269 PASS566/40 does not qualify this gap and must not
be signed. Corrective analysis and96 focused serial tests PASS; exact-source CI is pending.
[Actual supported contract](SPOTIFY_SINGLE_FILE_ZIP_IMPORT.md). Preserved signed
c249 remains independent and contains no F03. Latest05:31:18Z emulator admission
refused105.54% projected commit; no device command occurred. Samsung remains held.

## Additive single-file ZIP implementation (F03),2026-10-14

Owner renewed bounded host engineering while emulator admission remains blocked.
F03 adds an in-memory single-root CSV/TSV/YourLibrary JSON ZIP adapter with strict
8 MiB input/output, CRC/header/attribute checks and no extraction or schema change.
See [supported contract and separate acceptance](SPOTIFY_SINGLE_FILE_ZIP_IMPORT.md).
Analysis and 91 focused serial host tests PASS, including actual inflation limits,
event-loop cancellation, explicit Save and Hive rollback/close/reopen. Windows
strict remains FAIL16+24; all40 actuals match retained control. Exact Linux CI
will qualify this additive source before Android results are attributed.
Immutable c249395a/version300000015 APK remains independently preserved, checksum
fed354d5c8594826135863d14fbdc0248d9c54565687934219ffcd1fcd1ef469;
CI38488825088 PASS527/40 and sign-only38489764474 PASS/Publish skipped.
Owned5558 emulator checks are reauthorized; fresh04:54:30Z admission projects96.68%
against80% (26GiB allowance), both disks pass. No emulator launched. Samsung remains
held. The previous dated all-device hold below is superseded only for owned5558.

## Stable optional batch and host-only qualification,2026-10-14

F01 source811bc222e22678d45d3c6f6330c3ccca25436679 passes CI38479895933
(497 tests/40 strict Linux visuals). F02 product source8c938ae96b3abeddb687a27e6ab1bf3092abf15a
passes exact CI38485178534 (522 tests/40 visuals, required build/channel checks),
with independent terminal/log receipts outside Git. This follow-up adds only
boundary/reader regression tests and documentation; product code is unchanged.
Baseline signed24a/d12f remain preserved. One consolidated sign-only optional-batch
artifact follows exact-tip CI; no signing/publication credential changes.
All device testing is currently held by the owner, including emulator work in
this turn. The [runtime queue](RELEASE_VERIFICATION_QUEUE.md) records target-specific
authorization needed before resuming. No phone route substitutes for admission.

## Optional direct saved-track JSON step,2026-10-13

F02 adds a bounded offline YourLibrary saved-track JSON adapter using existing
import/session fields. Non-song entity counts are disclosed, unsupported formats
reject, and streamed input is size/depth/deadline bounded with cancellation.
See [the exact contract and feature acceptance](SPOTIFY_SAVED_TRACK_JSON_IMPORT.md).
It does not import ZIP/full playlist membership or migrate Spotify preferences.
Baseline24a/d12f and additive F01 remain distinct; native gates remain open.

## Optional flat TSV roadmap step,2026-10-13

After host-actionable baseline fixes were exhausted, the owner authorized small
roadmap additions. F01 adds flat TSV selection/preview/save using the existing
import session, with no schema, dependency, matching or routing changes.
See [inventory and separate feature acceptance rows](ROADMAP_ADDITIONS_20261013.md).
Signed24a2cb38 and CI-verifiedd12f932d remain separate baseline checkpoints.
Their unresolved native/provider/physical gates are not closed by F01.

## Durable production-router coverage,2026-10-13

The test/documentation-only successor to signed24a2cb38 adds actual production
Home/Search/Library/Settings tabs and Settings/About/Back coverage at412x915 and
1280x900, using existing mocks and visible rail targets. Product source remains
byte-identical to24a; the sealed APK's embedded SHA/version/hash are unchanged.
See [the complete38-row host/runtime reconciliation](RELEASE_HOST_REVIEW_20261013.md).
No reproduced low-resource product gap remains. Native queue and separate
release gates stay open; this host regression does not prove signed Android behavior.

## Host concurrency and playback follow-up, 2026-10-13

The signed9a6663c6 checkpoint and its immutable APK remain preserved. The current
successor delta fixes reproduced ownership races: late load success stopped a
newer source; late load failure built stale recovery; healthy Stop/Play reused a
permanently cancelled byte source and lost attribution; a late native error
restarted the queue after explicit Stop. A global pending-error flag also blocked
a genuine replay failure while its older handler was still awaiting Pause; the
existing per-transition duplicate guard now owns errors without that global gate.
Healthy explicit replay recreates the
same recording's source; cancelled originals and terminal failures stay blocked.

CSV reading/saving are mutually exclusive, picker cancellation retains saved
state, and a saved preview cannot silently create another session and erase
matching work. The service rejects overlapping writers across page instances
until commit or complete rollback finishes. No schema, recording selection,
source order, matching score, provider identity or dependency changed.

54 targeted host checks PASS, including29 backup rejection/empty/rollback cases
and a controlled slow-close timeout case,
real production-router three/four-tab Home/Library/Settings/Back, delayed CSV picker
and partial-write failure, two concurrent-writer/reopen cases, healthy source
replay and late native cancellation. Fake backend tests do not establish signed
Android usability or provider availability. Settings navigation source is unchanged;
its signed Android failure still needs input/focus/log diagnosis.

Slow failed validation close now retains its own temporary staging while the
validation lock exists, including timeout, instead of deleting it behind Hive.
The two-second wait uses a monotonic clock. Strict rejection is unchanged; no
unhandled cleanup error occurs in the controlled delayed-close regression.

The38-row audit retains the existing selector/import/offline/library implementation;
remaining provider, signed data/restart and physical-output rows require runtime
proof. No missing current-version selector or new Spotify playback engine is
inferred. Final local analysis and487 aggregate tests PASS. Windows strict remains
FAIL16+24; all40 actuals remain byte-exact to the established control, with
before/after/isolated diff inspected and no comparator/golden changes. Successor
exact CI/signing remain pending. All four CSV UI races fail against an exact
checkpoint9a UI-source control, including lost ready state after cancellation
and erased accepted matching work after a stale saved callback; corrected
controls pass. Follow [the dependency-ordered verification queue](RELEASE_VERIFICATION_QUEUE.md).

## Corrected candidate CI and sealed artifact, 2026-10-13

Source9a6663c6c5626bd5d1a8e4a377a1a1b35693f4e4 is pushed to sole draft PR23.
The bounded validation-copy cleanup wait fixes four Linux rejection-test races
from CI38453235406; strict malformed/truncated rejection and original-byte
preservation remain intact. Local29 targeted/472 aggregate tests and analysis
PASS. Windows strict FAIL16+24; all40 actuals are byte-exact to retained control.
[Exact CI38456177304](https://github.com/topcat432/musify-personalized/actions/runs/38456177304)
PASS:472 tests, both strict Linux suites, debug/F-Droid boundaries and unsigned
release assembly. No schema, dependency, comparator or golden changed.

[Sign-only38457361054](https://github.com/topcat432/musify-personalized/actions/runs/38457361054)
PASS; Publish skipped. Independent downloaded-APK verification agrees with the
manifest/checksum/proof and embedded x64 Git SHA: retained .preview package,
version300000013, signer58c5316466da7a426c4411beb33b3b594ef58875bcfa31e092a5afce8cf9999e,
v2/v3 true, non-debuggable. APK SHA256:
6ef557958a3e947ec59964ceaf4b21697526a32945371c4191c5ebece2f0945d.
Canonical immutable artifact/receipts remain outside Git under the established
host-provider-diagnostic evidence root, immutable-signed-9a6663c6-run38457361054.
This artifact is not a published updater asset and has not been installed.

Earlier018bb5c7 remains installation-only PASS. Its post-update semantics,
full restart and signed UI usability remain UNVERIFIED. Host comparison finds
no lib/Android delta from the earlier successful normal-main navigation build;
the saved Settings tap lies within its observed semantic button bounds. Neither
observation distinguishes input delivery/timing from release application behavior.
The exact signed navigation diagnostic therefore remains required; no navigation
code was changed without evidence. Corrected signed semantic/full-restart,
empty-library restore and normal-entrypoint provider checks await admission.

Latest host committed bytes35116941312, limit72846569472: unchanged26GiB native
allowance projects86.53%,4756973159 bytes above the80% cap. No native launch or
provider request occurred during this correction. Normal clone and immutable
baseline/artifact copies retain the previous verified checkpoint; no fresh native
preservation pass is inferred. All owned CI/sign/download jobs are terminal.
No phone operation, merge, publication or unrelated workload change occurred.
The corrected source tip is frozen while these acceptance receipts are reconciled.


## Strict validation cleanup correction, 2026-10-13

Exact CI38453235406 at1e24ad8b failed four rejection tests on Linux: Hive2.2.3
starts an unawaited close after failed initialization, and deleting the staged
lock first causes its later lock deletion to throw PathNotFoundException.
The bounded correction waits up to two seconds for that validation copy's own
lock to disappear before deleting the copy. Strict CRC/frame validation,
zero-byte empty-box support and original-file preservation remain unchanged.
29 targeted tests,472 aggregate tests and analysis PASS locally. Corrected
exact Linux CI/sign-only/native acceptance still require fresh evidence.
The earlier018bb5c7 signed result is installation-only PASS; semantic
preservation, full restart and signed UI usability remain UNVERIFIED.

## Valid empty-box correction and signed rehearsal status, 2026-10-13

The bounded correction accepts Hive's legitimate zero-byte empty boxes without
manufacturing a playlist. Backup descriptors/checksums and semantic inventories
remain required; declared nonempty data truncated to zero is rejected. Strict
frame/CRC validation disables automatic repair of malformed nonempty input.
Preflight rejection leaves existing boxes/files unchanged, while failure after
replacement restores exact original bytes, including zero-byte originals.
No Hive, bundle or restore-journal schema/version changed. Older backup readers
can reject newly valid empty payloads; nonempty historical bundles stay readable.

29 targeted backup regressions, 472 aggregate tests and analysis PASS locally.
Windows strict suites remain FAIL16+24; all40 actual images are byte-exact to
established Windows control. No goldens/comparisons changed. Corrected exact CI,
signed artifact and affected native recovery checks are pending.

Immutable signed source018bb5c772c36448b8a72dd7c4f4a568a3eafc19 passed
CI38433405297/sign-only38434666060; Publish skipped. APK SHA256:
8852dfaba4a46de8aa6c1f1855bdb7c459708c0db970a5ee227136b93c781048.
On5558 the actual retained production baseline was prepared through supported
local persistence/legacy recovery, then full cold boot, nonempty saved export,
payload checksums and independent typed Hive close/reopen PASS:4 imports,
4 matches,3 strong,1 exclusion,5 favorites,2 playlists. Original zero-box failure
and insufficient UI-only confirmation remain recorded as earlier failed checks.

That verified018 APK installs in place with retained .preview identity,
version300000001 ->300000012 and unchanged UID10210. It renders normal main.
Post-update semantic export/restart remains UNVERIFIED: repeated Settings taps
stayed on Home; source versus input-harness cause is not yet isolated. Provider
integration has no new result. Normal debug baseline four Hive bytes/private0600
are restored exactly after each completed native session; immutable originals
and signed artifact are preserved. Native diagnostics await unchanged26GiB/80%
admission. No phone operation, merge or publication occurred.

## Current transport and review evidence, 2026-10-13

Frozen product source f314b3aa115420a8a5691390b4c9e7b0114c2c8d adds bounded
same-provider redirects: at most two HTTPS Googlevideo hops, preserved selected
identity, one deadline, terminal401/403. A separately consented186-second source
passes full2,394,977-byte host save through one302 ->206 hop. No denied source
was replayed; this does not prove catalog-wide availability.

Production review on emulator-5558 passes real12-second cutoff (12,042ms),
seek, pause/resume, Later cancellation and repeated decisions. Independent
post-UI and full cold-restart Hive reopen preserves three-row order,
accepted/NoMatch decisions and completed matching state. External receipt:
`host-provider-diagnostic/live-review-native-f314b3aa-attempt2` in the established
evidence root. Debug APK SHA256:
c9e8a81608cfbca57aad0129505fb16c8e74e65c36d071ea0a96e1ba994e5db2.

Current normal-main sourcef314b3aa also passes Home/Library/Settings/About,
scroll and safe Back on5558 with temporarily disconnected guest networking.
Afterward the baseline APK/four Hives are restored exactly, and a full cold boot
verifies APK/Hive hashes and private writable0600 modes. An earlier failure
traced to clone files inheriting0444 from immutable host copies; host originals
remain unchanged. External receipts: `normal-ui-f314b3aa-attempt5` and
`normal-clone-recovery-proof.json` under host-provider-diagnostic. No normal-main
provider search/playback or physical audibility pass is inferred from navigation.

Local460 aggregate tests/clean analysis and11 offline workflow contracts PASS.
Prior9c89d4a1 exact CI38412302996 passes439 tests/all40 Linux strict visuals.
New exact-source CI follows the coherent push. Windows strict failures16+24
remain unchanged; no comparisons/goldens weakened. See
[the38-row bridge](RELEASE_ACCEPTANCE_20261013.md) for current remaining gates.
Candidate-ref sign-only dispatch pins the sole candidate/dispatch SHA/current
tip; publication retains protected-default-tip gates. Signing/in-place update
and physical output/focus/accessories remain separate gates.


## Persistent isolated native saved playback closure, 2026-10-13

Approved predeployment target musify_saved_acceptance_api35/emulator-5558 is
created on V: using the installed Android35 Google APIs x86_64 image. Original
musify_rehearsal_api35/emulator-5556 and immutable rollback copies were not
operated on during isolated testing. Original package/restart durability remains
unverified; the isolated target is an explicitly seeded verified host clone.

Exact product source3b012181c56d4af1181ba534099fab1539b3c3bf, fixture APK SHA256
688c68bee42c2c492127f7e6566241c85ec6bf7e62ad1a1726b26bdbb6dcfb6d, passes
full native saved214-second playback, middle/tail seeks, background advancement,
natural completion into the owned8-second next track, and cold process restart
with no autoplay/queue restoration. Last observed selected-track position was
213,577ms before natural queue transition. Saved3,961,198-byte file remains
SHA25641f0b95163cbfdb3881972564f78931c016d3f74356154af20386365328c8e1b.
No provider request, alternate source, account or credential was used.

Before fixture installation, a full AVD cold restart without snapshot loading
preserved the cloned baseline APK and all four known-good Hive lengths/hashes;
independent remote stat/checksum and host-byte checks reject error-text captures.
After fixture, normal b1dc64fa APK/entrypoint and four baseline Hive files were
restored exactly, guest filesystem synced and wrapper gracefully shut down.
A second full cold restart independently verifies that normal APK/four-Hive
baseline and saved source file remain exact. Host Hive reopens across playback,
process restart and AVD restart preserve selected identity/duration, source order,
library membership, offline preference and completed state. All owned emulators
are stopped. Physical audible output/focus/accessories and Samsung last-mile
acceptance remain unverified; this does not establish original AVD durability.

12 mocked owned lifecycle contracts and4 receipt-reader cases PASS. New target
uses explicit persistent V: data, fixed serial/name, shared lease,26GiB admission,
hash-pinned callbacks and finally graceful cleanup. Original target rejects
saved-only bootstrap/cold overrides. No schema migration, clear-data, uninstall,
merge, phone installation, signing or publication. Current app source is unchanged
from exact-CI verified3b012181; measured orchestration/evidence delta follows.
Canonical external receipts: host-provider-diagnostic/isolated-baseline/
bootstrap-proof.json and saved-native-isolated-3b012181/{native-result.json,
normal-restored.json,avd-restart-proof.json,independent-hive-proof.json} under the
established continuing-acceptance-20261012 evidence root. Prior312-second online
provider native proof is distinct; the original audio-only later-range403 case
remains unresolved and unreplayed. Immutable rollback/retained normal APK remain.

## Native package gate and preserved rollback, 2026-10-13

Product source3b012181 remains exact-CI verified; its saved-file fixture APK is
pinned and no provider request was repeated. Orchestration e9cde45c93d562994c0da66829e83c05357073d6
preserves the existing AVD snapshot configuration and passes8 mocked lifecycle
contracts. The earlier hooks' exact CI7f464237 passes38405517408; current exact
[CI38406895221](https://github.com/topcat432/musify-personalized/actions/runs/38406895221) passes.

The owned musify_rehearsal_api35/emulator-5556 reaches boot property1 but its
required debug package has no APK path, including after preserving original
Fast Boot configuration. The150-second readiness gate stops before callback,
fixture installation or app-data mutation; finally graceful shutdown completed.
No native214-second playback or cold-restart normal-data preservation is claimed.
Attempt2 verified normal APK/four-Hive restoration inside the session before
shutdown; this is not post-restart proof. Attempt3's72-byte error texts were
rejected as Hive data. Three preserved host capture sets each match all four
known-good Hive lengths/hashes. One canonical immutable rollback copy and pinned
normal APK remain available outside Git.

A proposed separate persistent-data Android35 AVD would reuse the installed
system image, restore only verified disposable-target baseline copies, and test
full saved playback plus process/AVD restart. It is not created or approved as an
active target. Current original AVD remains stopped, with no wipe/clear/reinstall
attempt to force the package gate. Canonical external receipt/proposal:
host-provider-diagnostic/saved-native-persistent-proposal.json in the established
continuing-acceptance-20261012 evidence root.

## Wrapper-owned native lifecycle qualification, 2026-10-13

Exact product source3b012181c56d4af1181ba534099fab1539b3c3bf passes
[CI38401391442](https://github.com/topcat432/musify-personalized/actions/runs/38401391442).
Its saved-file fixture compiled in195.5s with the separate process-local4GiB
heap/2GiB metaspace/one-worker profile; default32GiB allowance remains unchanged.
Debug x86_64 APK SHA256:
688c68bee42c2c492127f7e6566241c85ec6bf7e62ad1a1726b26bdbb6dcfb6d.
Sparse host-commit samples peaked42.31%; this is not continuous peak proof.

Automatic review rejected creation of a callback containing a direct emulator
launcher before execution. Parent instructed a compliant wrapper-owned launch
hook. tool/Invoke-OwnedRehearsal.ps1 now owns admission, fixed target launch,
boot/identity, lease and finally graceful shutdown; callback is hash-pinned and
contains acceptance operations only. Seven mocked lifecycle contracts PASS,
including callback/boot failure cleanup and foreign/pre-existing process refusal.
No native data or APK was changed by mocks. The external established invocation
path delegates to this reviewed implementation. Native saved-file acceptance
remains pending; the product source/APK stays pinned to3b012181 because this
change is orchestration only. No additional provider request is needed.

## Selected-format length discovery and host delivery, 2026-10-13

Candidate repair selects the offered recording/format before one bounded GET
range probe; unknown progressive lengths no longer force HEAD requests or
silently discard an eligible muxed format. The validated format remains pinned
through selection. HTTP denial, ignored ranges, malformed lengths/types and
probe timeouts are terminal. Derived cache length is optional; legacy cache and
library data remain intact and no durable schema migration is introduced.

Guarded local analysis and439 tests PASS, including18 new selected-discovery/
context tests. Both strict Windows suites remain FAIL16+24; all40 actual images
are byte-exact to the existing Windows control, references unchanged. Reviewed
actual/reference/diff retain the known font rasterization difference.

One newly authorized non-denied recording selected muxed MP4/AAC itag18 before
probing. Metadata supplied no length; GET206 learned3,961,198bytes, then all16
finite production download ranges returned206 and makeSongOffline saved the
complete file. Saved SHA256:
41f0b95163cbfdb3881972564f78931c016d3f74356154af20386365328c8e1b.
One metadata request, one probe, one logical download; no retry, alternate client,
credentials or replay of denied resources. This is host delivery proof. Native
214-second saved-file seek/background/completion/restart acceptance is pending;
the isolated generic fixture is included, private input/media remain outside Git.
External canonical receipt: host-provider-diagnostic/
selected-live-20261013T124149916/selected-muxed-proof.json in the established
continuing-acceptance-20261012 evidence root. Earlier312-second provider native
proof is a distinct recording; audio-only later-range403 reliability remains open.

Default Windows build admission still refuses its32GiB commit forecast. No
forecast, heap setting or80% threshold was weakened. An explicit separately
measured constrained profile is being investigated; normal emulator data/APK
remain preserved, emulator stopped, Samsung reserved for final acceptance.

## Offline playback investigation and justified repair, 2026-10-13

Storage-adoption tip57661cf391da4b6902c529577fb2e1f5cb65156e passes
[CI 38388340061](https://github.com/topcat432/musify-personalized/actions/runs/38388340061).
No further provider request was made after the recorded later-range403.
The failed recording1 selection is audio-only Opus/WebM itag251,4,556,211bytes;
the earlier312-second native pass used muxed MP4/AAC itag18,15,818,625bytes on a
different source. The earlier captured format had declared length in metadata
and URI. The recent inventory's ordinary format had neither, so the no-HEAD
harness skipped it and the unchanged production selector used audio-only fallback.
That is not proof of a selector regression or provider-wide denial. The older
native rehearsal explicitly pinned its offered muxed source.

Read-only inspection of a working copy of the retained cache confirms the failed
URI hash and21,599seconds remaining before its declared expiry at denial. Producer
User-Agent hash and exact URI were enforced across all five sequential ranges.
The original cache SHA remained exact. This does not identify the server's reason
for403, but expiry/header identity loss is not supported by this capture. Latest
raw player bodies were not retained; recording2's precise codec/length/parser
exclusion cannot be reconstructed from its narrow summary. Do not invent it.

An independent synthetic reproduction establishes a real SDK bug: optional HEAD
discovery accepted403's9-byte Forbidden body as a muxed media size and proceeded
to GET;302's5-byte response body was likewise treated as media bytes. The local
SDK now rejects error/redirect lengths and makes HEAD403 terminal before GET.
Three targeted tests pass, including preserved valid200 lengths. This protects
protocol correctness/access-denial handling; it does not claim to resolve the
separate real later-range denial, change recording selection/routing, or migrate
data. Local analysis and421 aggregate tests pass. Both Windows strict suites
remain FAIL16+24; all40 actuals are byte-exact to their established control,
representative master/actual/diff images inspected, references unchanged.

The Windows build forecast is corrected without lowering configured8GiB heap,
4GiB metaspace or80% threshold:32GiB commit,20GiB C: writes,6GiB V: writes.
It covers a possible second similarly sized compiler/worker JVM, native/host
overhead and potential configured heap dumps. Six offline refusal/forwarding
contracts pass. A live admission-only check projected85.27% and refused; no build
launched. Heap dumps are ignored by Git and remain private diagnostics. Revise
the forecast only after measured qualification, not to force admission.

Signed/native/last-mile gates remain separate. All source/proof lineage is retained;
no denied source replay, identity switch, account/proxy secret, production action,
emulator launch or live-data change occurred during this investigation.

## Concrete provider result and required storage adoption, 2026-10-13

Exact fe0335ff24fa9e2917a924bf1f0b1682100ff27a passes
[CI 38381772666](https://github.com/topcat432/musify-personalized/actions/runs/38381772666).
Its delta from verified acb07a20 is only this map; product/native lineage remains
unchanged. Continuing provider consent was explicitly received at10:17 UTC.
Samsung is intentionally last-mile only: stop routine presence/reconnection
requests while predeployment engineering remains incomplete.

The prepared host diagnostic completed in340ms:1 metadata POST HTTP200,
0 media probes/downloads, no declared compatible muxed format. This narrow result
is not a timeout or proof that production's audio-only fallback is absent.
After deterministic production-selector/SDK guard qualification, a bounded
three-recording follow-up selected offered Opus/WebM itag251 for its first case.
Metadata HTTP200, one-byte probe206, four256KiB ranges206 (exactly1MiB delivered),
then range1048576-1310719 HTTP403. The wave immediately stopped; other cases were
untouched, no complete download published, no retry/client/source switch occurred.
Counts:1 metadata,1 probe,5 range requests,0 completed downloads. This is a real
later-range denial, unlike the earlier harness guard/timeout findings. Private
proof: host-provider-diagnostic/wave-real-20261013T104621532/
production-followup-proof.json outside Git. The earlier15,818,625-byte transfer
and312,291-ms native provider pass remain valid for one different source.

The follow-up guard initially intercepted403 before production could classify
it; its resulting network label is a harness artifact, not an established app
classification defect. An offline adapter repair now preserves the response for
production while blocking every later transmission. No denied source is replayed.

The owner's storage standard is now required by AGENTS/CONTRIBUTING and
[STORAGE_WORKFLOW.md](STORAGE_WORKFLOW.md). Windows tool/dev.ps1 workload actions
actually invoke the existing exact-hash session helper with declared C:/V: writes
and commit; setup remains configuration only. Missing guard/V: fails closed.
Five offline workflow contracts pass; a small existing-helper session qualifies
V: TEMP/TMP, owned rename and caller-environment restoration. No build/pub/test,
emulator, SDK installation, global setting change or automatic purge occurs in
those contract checks. The external provider entrypoint also uses the session
helper and enforces10MiB/three-generation logs with confirmed owned cancellation.
The emulator guard's26GiB allowance is unchanged; native lifecycle/renderer
qualification remains separate, not implied by mock/host-session checks.

No product behavior/schema/scoring/routing/selection change is introduced by
storage adoption. Provider reliability remains the predeployment blocker; exact
signed disposable in-place delivery and last-mile physical acceptance are still
separately gated. No production signing/publication, integration or installation.

## Resumed independent preparation, 2026-10-13

Read-only reconciliation confirms clean candidate
acb07a2080d2d92a1255211613893047660fc563 passes
[exact CI 38333791829](https://github.com/topcat432/musify-personalized/actions/runs/38333791829).
Sole PR23 remains draft; protected master remains
a786323556275a0de745ffca4d3affc088ac2055. Product/native b1dc64fa receipts below
remain valid; no product change or repeated acceptance run is introduced here.

The scoped batch's later authorized harness repair/retry supersedes the earlier
guard-only receipt below. It skipped case1 to retain its consumed metadata
request, then case2 hit a 30-second manifest timeout. Cumulative counts are
3 metadata attempts, 2 selected one-byte probe attempts, 0 downloads and
0 completed cases; case3 was not processed. Probe status/itag/URI fingerprints
were not retained, so neither exact response outcomes nor a new HTTP denial can
be inferred. Per-recording repeat guards were strengthened afterward, with
5 offline regressions passing and no subsequent network run. This budget and
deadline are exhausted. The earlier 15,818,625-byte transfer and 312,291-ms
native provider background playback pass remain proven for one recording;
broader coverage and the separate audio-only later-range403 remain open.

A separate host-only recording2 diagnostic is prepared outside Git, pinned to
acb07a20: at most1 metadata POST,1 selected one-byte GET,0 downloads,2minutes;
no HEAD, automatic retry, redirect following, account/client switch or raw signed
URI logging. Eight deterministic fake-transport tests pass with zero external
requests. Its README records the exact guarded command. Continuing provider
payload authority is still pending; generic development continuation does not
authorize this new network budget. No real diagnostic has run.

Host storage cleanup is coordinated in a separate lane. Current read-only
resources show about51.8GiB free on C:,39.24% host commit, and available V:/Gradle
cache paths; the older259MiB checkpoint below is historical. Storage work still
owns the stopped AVD/historical evidence move: do not read/mutate those trees or
launch until its clearance. Future owned rehearsals require the external
Invoke-OwnedRehearsal.ps1 admission/lease/graceful-shutdown wrapper; its default
26GiB projected-commit allowance is unchanged. GPU/RAM runtime qualification
remains unproven; no launch/configuration/security change occurred.

Only the selected Samsung was queried; it remains absent. Fresh phone identity,
pre-update backup/recovery and audible/focus/accessory acceptance remain gated on
connection and their scoped authority. The exact-source release sequence is
prepared: close product gates, approve integration, pin resulting default tip,
approve coupled signing/publication, verify artifact and signed disposable
in-place preservation, then authorize the exact live update. No production
action occurred. D-017 supported baseline and D-018 nonblocking stretch intent
are unchanged. No new production defect is established by the harness timeout.

## Release preparation and scoped provider attempt, 2026-10-13

Final candidate 6c05206b2045f27039114bdc0639fc14249c2281 passes
[exact CI 38332605213](https://github.com/topcat432/musify-personalized/actions/runs/38332605213).
PR23 remains clean, draft and mergeable; master remains a7863235. This receipt
does not prove merged, signed, phone-installed or release-ready status.

The owner answered the specific three-recording payload/destination request;
the approval retry was allowed. A fixture-only erroneous await was removed after
an initial compile failure with zero requests. The batch then stopped on case1
after one metadata request: the bounded harness rejected the resolver's HEAD
content-length request before transmission. Zero media probes/downloads and
completed cases; cases2/3 untouched. This is a request-allowlist failure, not a
new provider HTTP denial or playback pass. No broadened requests, batch retry,
client/identity switch or denied-source replay occurred. Existing audio-only
later-range HTTP403 and complete provider listening/download/preview gates remain.

Read-only check of only the selected Samsung reports device not found. Current
package/version/signer therefore cannot be revalidated; prior public identity
receipts remain historical. No security/ADB-server/device change was attempted.
Preserved installed baseline APK and real backup/re-export hashes were rechecked
and match prior receipts. The real independent restore/reboot/typed comparison
remains available; fresh pre-update phone inventory/backup is still required.

Exact physical/signed-preserving-update preparation is outside Git at
continuing-acceptance-20261012/release-preflight-20261013/
physical-and-release-sequence.md. It records artifact locations, fresh latest
legacy release manifest, installed signer, monotonic workflow formula, actual
default-tip gate and staged backup/disposable/live acceptance order. Signing and
publication are coupled in signed-release.yml and need approval together after
product gates and approved integration. No workflow was dispatched.

Minimal physical participation is reconnect/unlock through the existing setup,
identify available speaker/wired/Bluetooth outputs, and human audible/focus/
reconnect confirmation after approved exact installation. Unavailable outputs
stay unverified. Local free space at this checkpoint is about 259MiB, below the
three-case maximum media budget plus staging/build overhead; reserve space before
any future authorized larger transfer/build, preserving private evidence/data.
Independent preparation is exhausted at these named gates; no optional backlog
or production action is started. Normal b1dc64fa debug app remains stopped.

## Optional Spotify identity checkpoint, 2026-10-13

Exact source b1dc64fa54d87f966aabea0823f284a837d3c8ea passes
[Linux CI 38331748430](https://github.com/topcat432/musify-personalized/actions/runs/38331748430):
clean analysis, aggregate tests, both strict reference visual suites and all
Android build boundaries. Local analysis and 418 aggregate tests pass, including
25 new synthetic provenance cases. Windows strict comparisons remain FAIL
16+24; all40 actuals are byte-exact to the established Windows control and the
reference images are unchanged. No goldens were rebaselined.

New CSV imports optionally retain a validated Spotify track URI/ID pair through
matching checkpoints. Selection, scoring, routing payloads, library identity,
playback and old classifications are unchanged. No adapter/archive-version
change, migration, historical backfill or mandatory reimport is introduced.
[SPOTIFY_PROVENANCE_SLICE.md](SPOTIFY_PROVENANCE_SLICE.md) records accepted and
rejected forms, partial-state behavior, all18 contract dispositions and rollback
limits. Verified 733a5a9409695298348c023ecbb6e46f511ae036 remains the recovery
reference. This optional metadata preparation does not fulfill D-018 listening.

Owned emulator-5556 / musify_rehearsal_api35 ran the source-pinned isolated
native fixture: first checkpoint, partial replacement rollback, cold resume and
completed read-only restart. Three independent stopped Hive reopens prove exact
source identities/order, completed selected recording, absent legacy fields,
unrelated user/settings/cache/offline values and owned WAV/artwork. Controlled
lookups were 1/2/0; no provider requests or playback were performed. Normal four
Hive files remain byte-exact at every fixture capture and both installations.

Normal lib/main.dart b1dc64fa is restored and stopped after inspected Home and
Library. Installed debug APK SHA-256
cb062973a316761fedcc3feeac60d1cfa6ce01141817c1e33a07a596965e977c
matches the source-pinned build and retained debug signer. Independent normal
post-startup reopens preserve user/settings/offline values and all cache values.
Private receipts remain outside Git under continuing-acceptance-20261012:
provenance-native-independent-proof.json and normal-b1-library-final-proof.json.

PR23 remains draft/source-only; protected master is unchanged at
a786323556275a0de745ffca4d3affc088ac2055. The held three-recording batch,
unresolved later-range HTTP403, physical acceptance and approved signed delivery
remain separate gates. No phone, merge, publication, account or security action
occurred. This checkpoint stops before any larger provenance/UI/engine slice.

## Spotify stretch clarification, 2026-10-13

D-018 supersedes the external-app handoff suggestion as stretch fulfillment.
Required stretch listening is inside Musify, ad-free and without Premium;
handoff, ads and previews do not qualify. No handoff code was added. The approved
YouTube/saved-offline/Spotify-metadata baseline and passing f579b371 CI
38327263611 remain unchanged. Neither Spotify-led discovery with alternate audio
nor Spotify-delivered audio is claimed to fulfill the clarified goal. No access/
ad-entitlement bypass, account action or three-recording approval is inferred.

## Supported-scope native closure, 2026-10-13

Exact source 52576c31e6457d239c36563d20b22c2dacaa1630 passes
[Linux CI 38326041187](https://github.com/topcat432/musify-personalized/actions/runs/38326041187):
clean analysis, 393 tests, all 40 strict reference visuals and Android boundaries.
Local 14 targeted/393 aggregate tests and analysis pass. Windows strict results
remain FAIL 16 + 24; all 40 current actuals are byte-exact to the established
control and reference PNGs remain unchanged. This is a known cross-platform
reference mismatch, not a detected current product rendering regression or
an unexplained product release blocker. Exact rasterization cause is unisolated.

The owner-approved D-017 baseline is implemented through the existing Offline
mode switch and actual-source details. Native English/Spanish copy is readable;
two online/offline cycles change four/three-tab navigation and survive restart.
Seven independent stopped reopens preserve exact expected settings, recording
order/memberships, owned WAV/artwork and unrelated values. Deliberate rehearsal
queue starts have narrowly audited monotonic recency/statistics changes, and only
two owned guard-fixture cache timestamps refresh. Every stopped fixture capture
preserves the normal four Hive files byte-exact. Repeated native absent/missing
saved-file cases reject the synthetic cached online slot before source loading,
retaining the current source, selected recording and queue. No provider media
request is used. Evidence: supported-mode-native-independent-proof.json and
the seven supported-mode-52576c31 snapshots outside Git.

Normal lib/main.dart 52576c31 is restored/stopped on emulator-5556 with the
retained debug signer. Installed/source APK SHA-256
92c74cbb0d09ae5bb8c5c38ec46f3ab39646f7e6e5fe55bd2320c56456b938e3
matches. Installation preserves four Hive files byte-exact; post-startup
Home/Library independent reopen preserves user/settings/offline values, with
one separately recorded derived cache timestamp refresh and all other cache
values exact. Evidence: normal-scratch-52576c31-install-proof.json and
normal-525-observed-final-proof.json. No migration, phone, signing or merge.

Spotify stretch assessment: official
[Android content linking](https://developer.spotify.com/documentation/android/tutorials/content-linking)
supports explicit external content handoff, and Spotify's
[Free experience announcement](https://newsroom.spotify.com/2025-09-15/free-experience-updates-features-tips/)
describes Free song-selection features. Neither establishes Musify SDK playback
or guaranteed external playback completion. The current SpotifyImportTrack
model/parser does not retain the exact Spotify URI, even when Track URI identifies
the CSV format. Spotify is absent on the approved emulator, so installed/logged-out/
unavailable/return/overlap acceptance is unavailable. Exact-identity propagation,
durable old-state handling and native external-app verification make this more
than a small link-only addition to the present data model. Retain it as a
high-priority post-release candidate; no search substitution, fake playback mode,
SDK/account action or external handoff is added to the approved baseline.

Remaining actual acceptance inputs: explicit three-recording payload/destination
consent, broader provider playback/download/preview proof and original audio-only
HTTP403 resolution; actual physical output/focus/accessories and phone acceptance;
eligible exact-tip integration, approved signed publication/in-place rehearsal
and live installation. No new queue-recovery or Spotify engine decision blocks
the approved supported scope. Master remains unchanged; sole PR23 stays draft.

## Approved supported playback scope, 2026-10-12

Owner decision D-017 accepts YouTube playback plus saved/offline audio, with
Spotify used for metadata import. Existing Offline mode behavior is retained:
on uses saved files only; off prefers saved audio when available, otherwise the
selected YouTube recording. English/Spanish Settings and source-details copy
now state this scope explicitly. No new provider modes, routing, adapter,
migration or queue-persistence architecture is added. Spotify-capable no-Premium
listening remains a high-priority stretch goal, not the release baseline.

Targeted 14 tests, aggregate 393 tests and clean analysis pass. Two repeated
mode-toggle/reopen cycles preserve the offlineMode key and unrelated data;
English/Spanish source details remain usable at narrow width/large text.
Native UI/reopen and exact-source CI verification are pending. The previous
source-mode gap is superseded by the owner's supported-scope approval.
Offline-only edge correction, 2026-10-13: a synthetic fresh cached location
reproduced unsaved queue playback while Offline mode was on (expected false,
actual true). The resolver now rejects absent/missing saved audio before any
cache or online resolution and preserves the offline-unavailable reason. Both
controlled cases pass without provider traffic. Native owned guard/reopen proof
is pending. Exact copy-only 410370e5 CI 38325048313 passes 392 tests and all 40
strict Linux visuals; the guarded source requires its own exact verification.

Provider batch consent, provider breadth/403, physical output/device acceptance
and signed delivery gates remain separate. No phone/signing/merge work occurs.

## Production queue closure and release checklist, 2026-10-12

Native source 809cf56d64c7270388bc52c3d7dc9ec4212383a5 adds only owned test support:
the shell helper can omit queue bootstrap, so restart observations come from the
production handler. Three independent stopped reopens verify 33 native assertions.
Two shuffle-on/off cycles, repeated same-mode actions, natural source-order
restoration, selected recording retention, repeated Stop and explicit replay pass.
Two real process restarts preserve shuffle/repeat preferences, remain stopped
without autoplay, and explicit Play resumes the exact latest recording as one item.
The full former queue/order is not restored across cold process startup: production
has no durable queue recovery path. No tested session behavior defect was reproduced.

Independent reopen verifies exact saved shuffle/repeat settings, likes/source order,
offline memberships and owned WAV/artwork payloads. Other user keys remain exact
apart from the explicit rehearsal checkpoint and separately audited replay
recency/statistics: monotonic counts/timestamps and deterministic added normalization
fields, with original recording metadata exact. Every stopped capture preserves
the normal four Hive files byte-exact. Evidence: queue-restart-independent-proof.json
and queue-restart-809cf56d-stage-0/1/2 outside Git. No production data/schema changes.

Normal lib/main.dart 809cf56d is restored/stopped on emulator-5556 after inspected
Home/Library. APK SHA-256
05544bce374e7d5a9f317d684c623ccc90aad90a14645116843c682fbad2278e
matches installed hash and retained debug signer. Installation preserves four Hive
files byte-exact; independent post-startup reopen preserves normal user/settings/
offline values and reports zero cache timestamp changes. Evidence:
normal-scratch-809cf56d-install-proof.json and normal-809-observed-final-proof.json.

Local targeted 17 tests, aggregate 391 tests and clean analysis pass. Both strict
Windows visual suites remain FAIL (16 + 24); representative before/after/diff
images were inspected and references unchanged. Receipt-only 6212e50d CI
38320919234 was cancelled by the subsequent source run, not passed.
Exact 809cf56d CI [38321448856](https://github.com/topcat432/musify-personalized/actions/runs/38321448856)
passes clean analysis, 391 tests, all 40 strict Linux visuals and Android boundaries.

Current-version reconciliation (canonical acceptance rows below retain their exact
historical source/evidence; these categories do not collapse device/release gates):

| Area | Implemented and independently verified | Genuine remaining capability or dependency |
|---|---|---|
| CSV/import/review/routing | Four selectors; exact alternate/order; successful identity snapshots; unknown legacy baseline; stale/repeat/restart guards; durable decisions and explicit destinations | Online provider preview/identity availability still lacks broader acceptance; no new import architecture is included |
| Backup/recovery/offline | Saved-file checksums/semantic reopen, corrupt/cancel/rollback/crash recovery, owned download boundaries/retry/reopen and registry preservation | Full live-phone signed update/data acceptance remains required |
| Home/Search/player/preferences | Bounded Home/shell/accessibility, search lifecycle, native controls/queue/shuffle/repeat/preview and reversible settings with preservation | Cold full-queue restoration is absent; clarify whether exact queue/position recovery is required for this version before durable-state design |
| Listening/source modes | YouTube-primary compatibility, saved local playback, active-source details with truthful format/quality limits; Premium-free CSV metadata import | Requested visible provider-selection modes are not implemented. Source attribution does not provide YouTube-only/Spotify-only/both policy controls. No working no-Premium Spotify exact-track engine or other feasible replacement is proven |
| Provider reliability | One complete muxed provider recording plus owned finite-range seek/tail/next/background proofs | Original audio-only HTTP403 remains unresolved; sustained catalog stream/download/review-preview acceptance is unmet. A three-recording private-payload batch remains consent-held and is not a repair or release pass |
| Visual/CI | 391 local tests/analysis; exact 809cf56d Linux 40 strict visuals and Android CI pass | Windows strict comparisons remain failed |
| Physical listening | Scoped emulator media state/background/queue behavior | Audible speaker/wired/BT output, focus/reconnect and actual-phone native/data acceptance require device/output access and separately approved installation |
| Signed delivery | Retained package/signer/default-tip/updater rejection boundaries | Passing product gates, approved integration, exact default-tip signed/published artifact, monotonic code, v2/v3/source/APK checks and disposable in-place rehearsal precede approved live-phone delivery |

D-006 keeps Spotify metadata migration usable without OAuth/Premium; it does not
establish Spotify playback. D-015 still requires visible source/optional modes and
the intended recording experience. The unsupported engine/mode gap remains a
current outcome limitation requiring a feasible bounded provider design or an
explicitly revised supported-mode acceptance decision; no nonfunctional selector
is added to imply success. Full cold queue recovery is a separate durable-feature
scope question, not a permission to migrate the library.

The provider batch remains paused without owner payload/destination approval.
No denied provider source is replayed/rerouted and no account/cookie/security work
is authorized. Richer ZIP/JSON/TSV, multi-membership sync/share intake and canonical
multi-source architecture remain future scope. Independent owned acceptance is
complete for this continuation; remaining work crosses the named capability/
consent/device/release boundaries. This candidate is not release-ready.

## Native controls and scope reconciliation, 2026-10-12

Exact e1498a180bf3a500e458d520712ce9719f848e2b passes Linux CI
[38318503873](https://github.com/topcat432/musify-personalized/actions/runs/38318503873):
391 tests, clean analysis, all 40 strict Linux visuals and Android boundaries.
Windows strict visuals remain FAIL (16 + 24); references are unchanged.

On owned emulator-5556, manual preview play/pause/resume/pause retains one source
load, and auto-preview off prevents the next deferred row loading until enabled.
Rapid mini taps/swipe open one player, one Back returns to Library, and queue
dismissal returns to the player with the same two owned recordings. The actual
local source dialog identifies local playback and honestly leaves codec/quality
unverified. Native repeat cycles through all/one/off; repeat-one remains selected
after restart. Shuffle toggles on/off. The fixture deliberately rebuilds its queue
on each launch and resets shuffle when replacing it: this does not prove production
queue/shuffle restoration. Notification Stop produces an inactive session, state
NONE and position zero; production stop/restart persistence remains unverified.

Two Blue/Sky and Spanish/English cycles save and reopen successfully. Independent
stopped Hive audit passes ten expected preference states, exact owned payloads,
offline registry and unrelated user values; deliberate queue starts affect only
monotonic recency counts/timestamps plus separately excluded statistics. The failed
English-label driver in a Spanish picker is retained and excluded; corrected
Inglés retry passes. Preview and player receipts remain outside Git:
preview-e149-controls-proof.json and player-e149-preferences-independent-proof.json.

Normal lib/main.dart source e1498a18 is restored in place on emulator-5556,
inspected at Home/Library and stopped. APK SHA-256
84d5560cf288371f9b3e9b7c29a4980d9304684cece5f8f6de7fe9519b4afa98
matches the installed APK with the retained debug signer. Four normal Hive files
are byte-exact through installation; independent post-startup reopen preserves
user/settings/offline values, with zero cache timestamp changes.
Evidence: normal-scratch-e1498a18-install-proof.json and
normal-e149-observed-final-proof.json outside Git. No schema changes or phone work.

Current-version implementation includes the four routing selectors, retained
alternate recording/order/successful identity snapshots, resumable review and
explicit routing, CSV intake, backup/recovery, offline/download surfaces, and
bounded preserved #22 Home/shell/accessibility. Their detailed proofs and remaining
release limits are recorded below; this is not a claim that all product gates pass.

Scope correction: the previous entry's “richer approved import” wording did not
establish a current-version cutoff. PRODUCT_ACCEPTANCE's Owner intent and scope,
CONTRIBUTING and D-016 retain playlist-aware ZIP/JSON/TSV, multi-membership repeat
synchronization/share intake and the wider canonical-library phases as future
work. They require a bounded design/current-version decision before architectural
implementation; roadmap approval alone is not a claim that they are shipped.

Remaining current acceptance: broader provider stream/download/preview coverage
(the three-recording private-payload batch is held for explicit owner approval),
production stop/restart and queue/shuffle restoration, unresolved original
audio-only HTTP403, Windows strict visual failures, and physical-phone acceptance.
One complete provider muxed recording is proven, not general catalog reliability.
Free Spotify exact-track playback is unproven; source controls cannot imply a
working Spotify-only/both mode. Signing/publication, exact default-tip integration,
monotonic update/signature checks and live-phone data/audio acceptance stay gated.
Master remains a786323556275a0de745ffca4d3affc088ac2055; sole draft PR23 is source-only.

## Owned review closure, 2026-10-12

Exact cadc2b6d9a301d1e5040266d2c9309898a2b56bd passes Linux CI 38317502932:
clean analysis, 391 tests, all 40 strict visuals and Android boundaries. Local
391 tests/analysis pass; Windows strict suites remain FAIL (16 + 24), unchanged.
The v1 review fixture replaced Musify's root, whose dispose closes Hive; it was
not valid evidence of a production gesture/persistence failure. V2 was rejected
by the owned-namespace guard before setup. Both failed receipts remain retained.
V3 mounts review once after owned setup, preserving production shutdown behavior.

Native V3 passes upward Later, right Accept and left No match. Independent stopped
Hive reopen preserves the selected accepted recording, source row order, unresolved
row and reopenable manual-unmatched state, with no permanent exclusion or implicit
routing. Restart excludes the accepted row from the unresolved queue; repeated
No match preserves the accepted/deferred rows and changes only its own review
audit timestamp. Existing likes/settings/cache/offline memberships stay exact
across those snapshots; deliberate owned queue starts can update recency/statistics.
The owned 70-second preview stops at 12.003 seconds through the real native player.
This is local preview/decision proof, not provider preview or physical-audio proof.
Evidence: review-cadc-independent-proof.json and
review-cadc-native-preview-cutoff-proof.json outside Git.

The earlier 32 preference snapshots now independently pass exact expected settings,
offline registry/payload and unrelated user-value checks. The recency exception is
explicit and narrow: same recording identity/order/all other metadata, monotonically
increased listeningCount/lastPlayed from deliberate queue starts; statistics remain
separately excluded. The earlier failed whole-user audit remains retained.
Evidence: preferences-switches-recency-audited-proof.json (source 980323bb).

Normal lib/main.dart cadc2b6d is restored in place and stopped after Home/Library
inspection. APK SHA-256 f53f313b714be7ebe8fc35eeb900a0a2bed6007d721f77c5c86bb9528df125b1
matches installed hash/retained debug signer. Install preserves four files byte-exact;
independent post-startup reopen preserves user/settings/offline values with zero
cache timestamp changes. Evidence: normal-cadc-observed-final-proof.json.

Remaining native work: preview pause/resume/auto-preview toggle; rapid mini gestures,
queue dismissal/stop restart; shuffle/repeat persistence; source-details attribution;
Blue/Sky accent and Spanish/English selection cycles/restart. Richer approved import
formats/multiple memberships/repeat sync/share intake and full release/phone gates
remain open. The three-recording provider batch remains paused for explicit owner
approval. Only one provider recording has completed; original audio-only HTTP403
remains unresolved. Spotify free exact-track playback is not established; no
nonfunctional Spotify-only/both controls or silent substitutions are introduced.

## Owned review continuation, 2026-10-12

Exact documentation tip 164ec7dbcbe6bea33b65ef9941b18d4d6f415c2c passes
Linux CI 38313767077 (389 tests, 40 strict visuals and Android boundaries).
Native v1 owned review loads local previews and upward Later rotates to row 2
without resolving row 1. Subsequent right swipes/Accept leave row 2 unchanged.
Those observations remain FAIL/pending; a real-service diagnostic succeeds on
an independently copied snapshot, so the native cause is not yet established.

A widget regression independently reproduces a failed decision's error disappearing
when its preview restarts. Workflow and preview errors now have separate ephemeral
state, retaining the failed-save message and allowing retry. Keeping the message
visible exposed short-card overflow; a compact source/suggestion/preview layout
retains controls when available height is below 270. Failure/retry and keyed
Later-to-Accept regressions pass. Local 391 tests and clean analysis pass; both
unchanged Windows strict suites remain FAIL (16 + 24), with reference PNGs unchanged.
No data schema changes. V2 review uses a fresh owned namespace and scoped native
player/service event traces; no provider requests, normal-data reset or v1 deletion.
Native v2 acceptance and normal restoration remain required before a checkpoint.
The approved provider batch remains paused pending the owner's scoped approval.

## Playback attribution and download integration, 2026-10-12

Exact cdf9ba660ec964cb6920e9460bd5af59d5b0a4f8 Linux CI 38306925264
passes analysis, 377 tests, all 40 strict visuals and required Android boundaries.
Normal cdf9ba66 lib/main.dart is installed on emulator-5556 and stopped after
inspected Home/Library. APK SHA-256 is
82ed05a63b6c424bab6b524b1a4fd7a0019f8737d7493e5179cf6aeab983dd18;
installed hash/debug signer match. Install preserves four files byte-exact;
independent copied-Hive reopen preserves user/settings/offline values with zero
cache timestamp changes. Evidence: normal-cdf-observed-final-proof.json outside Git.

The continuation shows ephemeral attribution only after a source loads, clearing
it during transition/stop. YouTube delivered MP4/WebM MIME distinguishes audio
from audio plus video; unknown formats and local files acquire no codec/bitrate/
lossless claims. English/Spanish details explain video data cost and capabilities:
YouTube or local files; Spotify imports are metadata, with playback unavailable.
No nonfunctional Spotify mode is introduced.

Manifest validation probes the format selected before playback rather than blindly
probing the first offered format. Ordinary extraction stays on the existing
ANDROID client, without watch-page prefetch or automatic identity fallback.
Selected-format HTTP403 remains terminal. Downloads select the same compatible
recording/format and use finite production HTTPS ranges, retaining complete-body,
partial-file and registry checks and the existing transaction protocol. There is
no library schema migration or new account/service/proxy/credential configuration.

Local 388 tests and clean analysis pass. Selected-format denial and complete/
truncated/denied/repeat downloads use synthetic regressions. English/Spanish source
details pass narrow-width/large-text checks. Both unchanged Windows strict suites
remain FAIL (16 + 24), with references unchanged. The prior native 312-second
provider success remains one recording, not catalog-wide recovery.

Three additional existing recording choices were selected outside Git, excluding
the prior success and named synthetic-media rows. These IDs were read from the
disposable AVD's public-metadata acceptance fixtures, not a live-phone query.
The title filter alone did not establish real-user provenance; no permission is
inferred from this correction. Automatic approval review rejected the
combined command before execution because sending video identities derived from
private Hive data to YouTube lacked explicit approval for that payload/destination.
No batch provider requests were made. That scoped approval is pending; approved
code pushes and owned disposable-native acceptance continue independently.
The original audio-only later-range HTTP403 and physical/signed release gates
remain open. No provider batch delivery/preview/download success is claimed.

The typed-row follow-up reproduces a real repeat-download failure when an older
registered offline song has no artwork and the playlist row is Map<String,String>:
assigning null to artworkPath throws and prevents completion. The narrow fix
removes a missing optional artwork path instead. Its regression fails before and
passes after, preserving source order, keeper payload and one playlist on repeat.
Local aggregate now passes 389 tests with clean analysis; both unchanged Windows
strict suites remain FAIL (16 + 24). Exact e75df0f671589a607483dd0e2ebabced7e6657ff
Linux CI 38310733410 passes 388 tests/all 40 strict visuals and Android boundaries.

The first owned native playlist driver failed on ADB's missing-file output; retain
that failed receipt. Its corrected attempt exposed the typed-row failure plus a
fixture missing the normal audio handler for toasts. The fixture now initializes
that handler and uses a slower cancellation body in a fresh v2 namespace, retaining
all v1 data/evidence. Whole-playlist native acceptance remains pending this rerun.
Normal four files remained byte-exact at stopped v1 captures; no provider requests.

Native whole-playlist source 2327ee54463d1962a076b1c230f224103a50f9ec now
passes all seven v2 cases: interruption, reopen, cancellation, truncated body,
retry, repeat and final reopen. Completion is absent until retry; repeat performs
zero loader calls and introduces no duplicate playlist or recording. Independent
copied-Hive reopen verifies preferences/cache, likes/memberships, retained offline
records, registry order and selected playlist member order; saved owned bodies
reopen byte-exact. Derived offline path/download timestamp refresh on repeat is
recorded, not called a complete durable no-op. Normal four files remain byte-exact
at every stopped capture. The two failed v1 driver/fixture attempts remain retained.
Evidence: playlist-native-2327ee54-v2/independent-proof.json outside Git.

Normal lib/main.dart 2327ee54 is restored in place and stopped after inspected
Home/Library. APK SHA-256 ed6c0c1b9b57ba9de87c214bed1e30769fbae873b14e2f1b5b8db5703c0e50d2
matches installed hash and retained debug signer. Install preserves four files
byte-exact; independent post-startup reopen preserves user/settings/offline values
with zero cache timestamp changes. Evidence: normal-2327-observed-final-proof.json.
Exact Linux CI 38312103902 attempt 1 failed before analysis/tests during pinned
NDK preparation: Error on ZipFile unknown archive. One unchanged-source rerun is
completed successfully as attempt 2: clean analysis, 389 tests, both strict Linux
visual suites (40 images) and required Android boundaries pass. No security,
license or SDK pin changed. Local 2327ee54 checks pass 389 tests and clean analysis;
Windows strict FAIL 16 + 24 remains unchanged. Broader provider approval is pending.

## Playback compatibility continuation, 2026-10-12

Source 7242644a7dc5d67b4c9d044b57de013c0f6cc2a0 passes exact Linux CI
38295877881: clean analysis, 375 tests, all 40 strict visuals and required Android
boundaries. Local 34 targeted/375 aggregate checks pass; Windows strict suites
remain FAIL (16 + 24), with references unchanged. Muxed-only manifests can select
formats of the same chosen video; explicit prefer-muxed resolution uses a separate
cache. Foreign video identities/unsupported codecs are rejected. MP4/WebM audio
and video MIME declarations reach the decoder intact. At that source, audio preference remained
primary; provider source modes are not yet exposed in the UI.
A later denied range remains terminal, with no alternate-identity/URL retry.

Native source 992be053 decoded the owned 70-second muxed MP4 and served its full
1,403,799-byte body beyond 1 MiB. Its first background attempt failed because the
driver missed the start window; the subsequent run advanced in background but
stalled at end-of-stream. Source d0a31cdf disables video tracks in the audio-only
Android player; it then advanced to the owned 8-second track and completed it in
background. That run's harness still failed by checking the decoder's single-source
index instead of Musify's logical queue index. Corrected harness 707b28d4 passes native continuous
70-second background playback, automatic next and complete 8-second playback,
then middle/tail seek and next on replay. Independent served-segment hashes and
range union verify complete 1,403,799/162,825-byte owned bodies; normal four files
remain byte-exact. This is controlled muxed decoder/transport proof, not provider
or physical-audio proof. Exact d0a31cdf Linux CI 38300035170 passes; 707 changes
only the harness's queue observation. Preserve the earlier failed attempts as
failed. Evidence: owned-muxed-native-preservation-proof.json outside Git.

Normal lib/main.dart c6f4a2a7 was restored before this rehearsal. APK SHA-256:
b8814f456903a704b1e31240d1077ec63f6333de0beae0d4b4b656963e1989e4.
Installation preserved four normal files byte-exact; inspected fresh Home/Library
pixels and independent copied-Hive reopen preserve user/settings/offline values
exactly, with one derived cache timestamp refresh. Core rehearsal used separate acceptance_muxed_transport_v1
storage on emulator-5556. Normal lib/main.dart 1e5c1fdca5c1c0f0361fe272666618a8c398150d
was restored in place and stopped after inspected fresh Home/Library pixels.
APK SHA-256 377c936b891d3c4a94c80694c142cde53e6266679c0b3e73de5b493c3d2fcda9
matches the installed package and retained debug signer. Installation preserves
all four normal files byte-exact; independent post-startup reopen preserves
user/settings/offline values exactly with zero additional cache timestamp changes.
Evidence: normal-1e5-observed-final-proof.json outside Git. The earlier C6 timestamp
refresh remains separately recorded. The task loopback server is stopped and its
single ADB reverse mapping removed. Emulator memory is overridden to 1024 MiB
for this process only; no physical-device/performance equivalence is claimed.

The earlier metadata eligibility tool call was rejected before execution. After
explicit owner authorization clarified that normal compatibility tests were
approved, the exact retry succeeded: anonymous unchanged-ANDROID metadata reports
the same video playable, no live/preview substitution, and a 312-second muxed MP4.
One bounded full transfer through the production byte source received all
15,818,625 bytes; saved-file SHA-256 is independently recorded outside Git.
No cookies, credentials, token modification, proxy, changed identity or alternate
source retry was used. The original denied audio-only URL was not replayed.
Native source 6cb01ba12d3beda82c190f68023e3afb7339e693 then completed
312,291 ms of that provider track in background on emulator-5556, with one
source attempt, no fallback/retry and no transport errors. Four normal Hive
files remained byte-exact. This is decoder/background proof with muted output;
physical audio and phone acceptance remain open. The normal resolver now prefers
a compatible same-video muxed stream before playback, using its separate cache.
Audio-only remains eligible when none exists; a denial stays terminal.
Muxed streams carry video bytes and do not promise the selected audio bitrate.
Source controls and visible compatibility attribution remain open.
Evidence: public-muxed-native-preservation-proof.json outside Git.
Evidence: provider-muxed-eligibility.json/provider-muxed-full-transfer-proof.json.
The original audio-only later-range HTTP403 remains unresolved for that format.


Latest normal entrypoint restored on emulator-5556 is source
398d8c1b264a9a8ce3ed97e90a1427c7dd5458dc, APK SHA-256
41ac05e6376ac7b98ccbd10f1ef70aed051e91ff01eb0154681a0567db5e5dfc.
Retained debug signer and installed APK hash match. Install preserved four files
byte-exact; inspected Home/Library and independent post-startup Hive reopen
preserve all user/settings/offline values and record zero derived cache timestamp
changes. Evidence: normal-398-observed-final-proof.json outside Git.
The resolver/default regression suite passes 36 targeted and 377 aggregate tests,
with clean analysis. Both unchanged Windows strict suites remain FAIL (16 + 24).
Playback cache publication and transient-error invalidation now share the resolver's
mode key, preserving separation from the explicit audio-only cache.

Current justacalico fork 292778ec includes muxed filtering/page parsing, but also
inherits a visionOS default. PR390 explicitly describes PoToken bypass; it is not
applied. Musify PR972 buffer-file playback is resilience, not a demonstrated 403
remedy. Invidious is a separate accountless same-video architecture, with operator
trust/privacy and actual availability unverified. No denied request is routed
through a proxy. Public-source comparisons and all diagnostics remain outside Git.

The completed preference batch changed/restored dynamic accent, pure black,
predictive Back, listening stats, update checks, SponsorBlock, automatic next and
external recommendations twice each, plus Offline mode restoration. Normal four
files stayed byte-exact at stopped captures. The stricter scratch-user audit found
fixture recency counts/timestamps changing across deliberate queue starts; that
whole-user equality audit remains FAIL until precisely scoped and reconciled.
Existing picker cancellation/selection inventories retain their narrower PASS.
Whole-playlist and review native harnesses are built but unrun. Remaining gestures,
accent/language selection, source controls/attribution and richer import roadmap
remain open. No phone install, merge, production signing or publication occurred.

## Offline ownership recovery and Android picker continuation, 2026-10-12

Candidate product source 980323bbdce1a6252a5f37e57d15fb3b7119d4c1 passes
[exact Linux CI 38287176093](https://github.com/topcat432/musify-personalized/actions/runs/38287176093):
clean analysis, 365 tests, both strict visual suites (16 + 24), and required
Android build boundaries. Local analysis/365 tests pass; Windows strict visual
suites remain FAIL (16 + 24 comparisons). No references or comparisons changed.
Documentation-only fee672a1 and 5d077194 have identical product files to 67496cfa;
fee CI 38268270524 passed, while superseded 5d CI 38269729856 was cancelled.
The cancelled run is not acceptance proof.

Offline source f0fac6c339ef3f3961245a966bd3a52760c6dc4f adds a flushed schema-1
ownership sidecar before rename. Explicit retry can roll back and redownload a
hash/length/path/identity-verified unregistered owned final. It preserves any
payload referenced by a current registration, including another identity's alias.
Unknown/legacy orphan payloads and invalid markers remain untouched and are never
adopted. No Hive adapter/schema migration or blanket orphan cleanup is included.
Native emulator-5556 acceptance_offline_boundaries_v1 passes 32 cases: crash,
reopen, retry and repeat at body flush, ownership flush, before/after rename,
registry write/flush, ownership removal and before return. Independent copied-Hive
reopen, exact owned payloads and preserved existing/unrelated inventories support
these bounded claims. Completion is never reported before return. This supersedes
the older individual-transfer rename/registry-unrun clause; native whole-playlist
interruption and hardware power-cut durability remain open.

Source 65d86c5354685992380f7efc81fa88bedfa8b523 fixes slow mini-player upward
drags by accumulating movement and guarding duplicate player navigation. The
meaningful before-failing widget test passes after repair; an actual 500-ms slow
upward swipe opens the local player, and one Android Back returns to Library.
Animated player hierarchy acquisition failed; fresh inspected pixels and the
subsequent fresh Library hierarchy provide the bounded native evidence.

Source 387f19d3's persistent-sheet shell regression passed widgets/CI but failed
actual Android picker Back, exiting the app. Source 980323bb puts the four
preference pickers on the root modal navigator. Native repeated Back cancellation
(two per accent/theme/language/quality picker), open-picker process interruption
and restart pass. Independent reopen of all eight captures confirms exact settings,
likes, offline registrations and owned WAV/art payloads. All normal four Hive files
are byte-exact at every stopped capture and fixture install. Selection, switch and
remaining gesture cases are still in progress; these results are not a blanket
T01/I04 PASS or physical audio/provider provenance proof.

Current emulator-5556 uses the temporary 980323bb synthetic preferences entrypoint;
normal entrypoint restoration remains required before ending rehearsal. It is the
verified musify_rehearsal_api35 AVD, with process-local ANDROID_AVD_HOME at the
existing musify-source-comparison/emulator-rehearsal/avds directory. Normal data is
retained; no uninstall/clear, live phone, signing/publication or merge occurred.
Private evidence stays in continuing-acceptance-20261012, including
preferences-cancel-reopen-proof.json and offline-boundaries-f0fac6c3-reopen-proof.json.
Master remains a786323556275a0de745ffca4d3affc088ac2055; PR23 remains draft.

Explicit remaining safe cases: repeated/restarted accent and language selection;
System/Light/Dark and Low/Medium/High selection (running); repeated/restarted
switches for dynamic accent, pure black, predictive Back, listening stats, offline
mode, update checks, SponsorBlock, automatic next and external recommendations;
shuffle/repeat, rapid mini-player actions, local seek/tail, queue dismissal and
mini-stop/restart; native review Later/Accept/No-match swipe interruption/repeat;
native whole-playlist partial/retry/completion. Proxy/security changes stay outside
scope. Complete allowed provider media, physical phone/output/focus/accessories
and signed delivery remain distinct release gates.

## Controlled lookup and production-shell acceptance, 2026-10-12

Product source 67496cfaa074e72c2a2da3d01658d4f8f472d347 passes
[exact Linux CI 38264000991](https://github.com/topcat432/musify-personalized/actions/runs/38264000991):
clean analysis, 355 tests, all 40 strict visuals and required Android boundaries.
Fifteen targeted matching checks pass. Before-failing controlled tests exposed
cancelled fallback requests, unavailable sources falsely marked unmatched, stale
review/overlap/exclusion overwrites and mutable checkpoint-list aliasing. Matching
now validates the import and saved results/cursor/exclusions between lookup stages,
preserves newer decisions, keeps healthy candidates, distinguishes unavailable
from empty sources and isolates checkpoint list containers. No durable schema or
adapter change was introduced. Windows strict suites remain FAIL; references and
comparisons are unchanged.

Native emulator-5556/acceptance_lookup_v1 verifies real matching-page disposal
while an owned delayed HTTP response is pending: one music request, no fallback,
paused 1/4 cursor and unchanged retained alternative/like. Process stop while the
next owned request is pending leaves the durable 1/4 checkpoint intact. Restart
and resume reach 4/4 with ordered unique manually-matched/unmatched/error/excluded
states. Independent copied-Hive reopen and owned request telemetry verify these
claims; this is not provider catalog or playable recording proof.

Separate acceptance_mini_v1 runs the real Musify router, shell and mini-player
with a paused two-track local synthetic queue. Inspected normal and dimension-
checked 320-dp/1.6-text screenshots preserve player/navigation usability; the final
Library row and its menu remain accessible above the player at the scroll end.
Dynamic accent, pure-black and predictive-back switches survive actual process
restart, and independent settings reopen confirms all original values restored.
Earlier two normal preference restart/restore checks remain pinned to d35b4b4e.
Neither these fixtures nor waveform playback establish physical acoustic/focus/
accessory acceptance. The corrected album-classification native retest at
fee672a1 passes: the owned Search album opens with Album classification and its
recording, then Back returns to results. Remaining unlisted preference combinations
are still open; no blanket row-level PASS.

Normal lib/main.dart fee672a1 is restored in place and stopped after Home/Library.
This emulator-only android-x64 debug APK is SHA-256
b81317c546deafaa311c65322d0927bdee2edf1b68f1cc628294d2dc43106c1c,
with the retained debug signer. Four normal files are byte-exact through install;
independent post-startup comparison confirms every stored value exact and zero
new cache timestamp changes relative to the pre-install checkpoint. The earlier
one derived timestamp refresh during normal preference testing remains separately
recorded. Display overrides are reset. All evidence remains outside Git in
continuing-acceptance-20261012, including matching-lookup-native-proof.json and
normal-fee-observed-final-proof.json. Documentation source fee672a1 also passes
[exact Linux CI 38268270524](https://github.com/topcat432/musify-personalized/actions/runs/38268270524).

Host disk-full compiler failures were recorded as failures. Space recovery removed
only hash-verified duplicate task build outputs and regeneratable task-local native
intermediates/Dart build cache; source, unique APKs and recovery evidence were
preserved. Only compiler-failed task-owned Dart runners were stopped; shared SDK
locks and other workloads were untouched. There was no approval-review denial.
Master remains a786323556275a0de745ffca4d3affc088ac2055. PR23 stays draft/unmerged.
Provider playback remains blocked after the retained denial; no new denied-provider
request, phone operation, production signing/publication or deployment occurred.

## Lyrics, offline transfer and compact Library continuation, 2026-10-12

Completed source 4939fffed242fb37fedefb2f4b77c8a19c6b7720 passes
[exact Linux CI 38247252808](https://github.com/topcat432/musify-personalized/actions/runs/38247252808):
clean analysis, 343 tests, all 40 strict visuals and required Android boundaries.
The candidate now stages audio bodies, rejects incomplete/oversized/unknown-length
responses, serializes durable registrations, preserves unknown existing files,
rolls back injected registry failures and requires every playlist member before
claiming complete offline availability. Twelve targeted regressions cover overlap,
cancellation, deletion during transfer, malformed old state, rollback, reopen and
explicit retry. No registry schema, adapter migration or automatic orphan adoption
was introduced. Rename/registry crash windows remain unverified.

Native 4939fffe uses emulator-5556, separate acceptance_gap_v1 storage and an owned
loopback server. Complete transfer, cancellation, process stop during transfer,
reopen and explicit retry pass. Both complete 8192-byte files independently match
SHA-256 25df2449b2e5a35fea14e02a7158e283801a1069c9f84631b9a9dacb2f809a7f.
Copied Hive reopen confirms ordered unique registration, no cancelled/interrupted
registration, retained imports/likes/preferences and unrelated offline keys.
The interrupted unregistered staging file is preserved. One synthetic artist-cache
DateTime refresh is recorded separately; normal four-file hashes remain exact.
This is controlled transfer evidence, not playable provider download acceptance.

Earlier native 5784c6fc verifies recording-owned lyrics A/B with identical labels,
refresh without refetch and distinct unavailable lyrics, plus actual Android
equalizer enable/preset and individual-band persistence through restart. Cache
identity includes recording ID and late responses cannot replace current lyrics.
The retained lyrics provider still searches artist/title; recording provenance and
physical acoustic output remain unverified.

Current product source d35b4b4e84b9b151faebe4b518d57651669d109d adds an offline
lyrics lookup guard and wrapping enlarged section headings. Seven targeted checks,
345 aggregate tests and clean local analysis pass; strict Windows suites remain
FAIL against their font references. No golden/comparator changed. Exact
[Linux CI 38249479399](https://github.com/topcat432/musify-personalized/actions/runs/38249479399)
passes with 345 tests, all 40 strict visuals and required Android boundaries. Native normal Library at 320 dp/1.6 text exposed
heading clipping in 4939fffe; dimension-checked before/after images confirm the
heading fully wraps beside both actions in d35b4b4e. Mini-player/inset combinations
and remaining preference/network-lookup clauses are still open. Native listening-statistics and automatic-next-song switches survive restart; both original values are restored. Independent four-box reopen preserves user/settings/offline values; one derived cache DateTime refresh is recorded.

Normal lib/main.dart d35b4b4e is installed in place and stopped after Library and reversible preference checks.
APK SHA-256 a29fe2633fa0871820359fa5e8640a8d9413ed1c0c931c0b55758472893d9e69;
retained debug signer unchanged. Four normal Hives remain byte-exact at installation;
independent post-startup audit confirms every normal stored value exact (zero timestamp changes). Display overrides are
restored. Evidence stays private outside Git in continuing-acceptance-20261012.
PR23 remains the sole draft candidate; master, phone, signing/publication and the
captured provider-denial release blocker are unchanged. No new provider request.

## Native acceptance gaps and Search repair, 2026-10-12

Source 13218daa3cf2a4b598575d1451cc84cdb8a7aeee passes exact
[Linux CI 38235074425](https://github.com/topcat432/musify-personalized/actions/runs/38235074425):
analysis, 326 tests, all 40 strict visuals, debug/F-Droid boundaries and unsigned
release assembly. Local analysis and 16 targeted Search/lifecycle checks pass;
both strict Windows suites retain their font-reference failures. No references
or comparisons changed. Three new regressions failed before the repair.

Controlled native metadata failures exposed silent history fallback and loss of
healthy categories when an artist/album request threw. Search now isolates all
categories, preserves healthy recordings/videos/playlists, distinguishes empty
from unavailable sources and offers Retry. Native emulator-5556 verifies failure
messaging, retry, healthy category retention without duplicates and empty feedback.
These are synthetic metadata responses, not provider listening/catalog proof.

Earlier native ff9c5e3f checks use separate acceptance_gap_v1 storage: malformed
and unsupported CSV rejection, valid replacement-preview cancellation, partial
write failure/rollback, four destructive-dialog cancellations, confirmed scoped
history/recents/stats/download/cache clearing and matching pause at 10/50,
process interruption at durable 20/50, then resume/completion at 50/50. Independent
Hive inspection preserves source rows, selected alternate, likes, unrelated
preferences and clear scope. Matching rows after the retained first result are
excluded synthetic rows; in-flight network lookup interruption is still unrun.
Cached native artist/album-fixture/playlist navigation and missing/empty/failed
artist states are pinned to 7b0565bc. Album classification was corrected in the
fixture at 13218daa and still needs its own native retest.

Explicit normal lib/main.dart source 13218daa is restored and stopped after
Home/Library checks. Installed APK SHA-256:
c12b60f55a37c2f0739fc1b738ee814f8294d17901ead0467858ac2eb0a7b003.
The retained debug signer is unchanged. All four normal files remained byte-exact
through scratch rehearsals and in-place return; every normal typed value remains
exact after startup, with zero derived timestamp changes. Scratch imports,
preferences and synthetic files are separate and retained.
Private proof: search-repair-native-proof.json, normal-13218daa-proof.json,
normal-13218daa-resume-preservation-proof.json, gap-* copied inventories/UI records.

Remaining safe native work is explicit in PRODUCT_ACCEPTANCE.md: recording-aware
lyrics/equalizer controls, controlled download commit/interruption, other preference
persistence, compact Library/mini-player combinations and network lookup interruption.
No absence of a known repair is treated as full native acceptance. Complete
provider media, physical audio/focus/accessories and signed delivery remain held.

## Legacy stale-transfer guard repair, 2026-10-12

Final partial-state review reproduced two unsafe completions: a legacy resolved
row without its historical source position could be excluded or have its chosen
recording changed during the pending write, yet the obsolete recording transferred.
The transient stale-check fingerprint now includes those rows and their status;
durable identity-baseline reliability remains conservative and unchanged.
A rejected retry also restores an older pending marker, including malformed/null
markers, so an interrupted transfer cannot become falsely known after rejection.
Old history and destination contents remain intact. No persisted schema changes.

All 22 targeted selector checks, 323 aggregate tests and clean analysis pass.
Both strict Windows suites retain their failures; no image/comparator changed.
Exact source a0e252d65161e3eaa494812c27ff84be2287fef5 passes
[Linux CI 38227069783](https://github.com/topcat432/musify-personalized/actions/runs/38227069783):
analysis, 323 tests, both strict suites (40 images), debug/F-Droid boundaries and
unsigned release assembly. No references changed for this repair.
On emulator-5556 / musify_rehearsal_api35, three isolated native cases reject
legacy exclusion, changed alternate and a stale retry with prior pending state
before destination writes. Existing likes/history survive Hive reopen; prior
uncertainty remains unknown. Independent copies confirm all four normal files
and all four earlier selector scratch files remain byte-exact.

Explicit normal lib/main.dart source a0e252d6 is restored in place and stopped
after Home/Library navigation. Installed APK SHA-256:
221e778ef9d7768f7fb98d45dceb7604485cc6e26946759744f65d063ba03b3d.
The debug signer remains f6569faab3364a5d3c9261d2b3da6939728f49f31405165ccc29da085d33c9a3;
all four normal Hive files are byte-exact across return installation.
Independent post-startup inspection also finds every normal user/settings/offline
and cache value unchanged (zero derived timestamp changes).
Private evidence: i11-guard-a0e-native-proof.json, normal-a0e252d6-proof.json and
normal-a0e-resume-preservation-proof.json.
Earlier four-mode/restart proof remains pinned to e705fb2b, not relabelled as a0e.

## Selector native completion and normal-entrypoint return, 2026-10-12

Candidate source 70313ae8c0a6c899f646d1f69810ad091dc2f97d passed exact
[Linux CI 38216623100](https://github.com/topcat432/musify-personalized/actions/runs/38216623100):
clean analysis, 319 aggregate tests, all 40 strict visual comparisons, debug and
F-Droid boundaries and unsigned release assembly. Only the six deliberately
reviewed selector/hub reference images changed across this work; five preserved
Home/shell references were added. The comparator and other references are intact.

The isolated Android selector entrypoint at e705fb2bce3853d41005181cfc3328cf931fff05
passed all four selection modes on explicit emulator-5556 / musify_rehearsal_api35.
Individual selection retained the alternate and source order; a repeat added zero.
Resolving only scratch row 4 produced a one-recording newly resolved transfer,
excluding the previously unselected resolved row. All mode added only the one
remaining recording. First-N retained two after transfer and repeat. Independent
copied-Hive inspection verifies all six audits, source rows, chosen identities,
existing like and exact scratch values across process restart. All four normal
Hive files remained byte-exact through scratch installation, execution and restart.
Scratch files are retained separately; there was no normal dataset replacement.

Explicit lib/main.dart source 70313ae8 was then built and restored in place.
APK SHA-256: 2e0e2158a8f8da887800351d7e28f828d92717c1b2fd5ac667362182bb728dde.
Installed APK hash, embedded source stamp, debug package/signer and all four normal
Hive files were verified. Normal Home/Library navigation passes; independent
inspection retains every user/settings/offline value and identifies exactly one
derived cache timestamp change. The normal app is stopped; the synthetic entrypoint
is not wired into production startup. Post-70313 changes in this checkpoint are
documentation only and do not change its tested product code.

Private supporting records remain outside Git in continuing-acceptance-20261012:
i11-scratch-native-proof.json, normal-70313ae8-proof.json and
normal-70313-resume-preservation-proof.json. Retained D05 source 251f5c43 evidence
also passes actual malformed/truncated/tampered picker rejection, valid-control
cancellation, in-process rollback and five staged recovery cases (first replacement,
between renames, corrupt/missing journal and verified new pair). The staged cases
use the production recovery routine in scratch directories, not a claim of killing
an actual restore at each instruction. Original normal files remained exact.

The approved bounded deferred Home/shell delta is in the sole draft PR #23.
Master remains a786323556275a0de745ffca4d3affc088ac2055; nothing is merged.
Complete provider listening/download/preview, physical focus/audibility/accessories,
signed in-place rehearsal and production delivery remain held. No provider-media,
phone, signing/publication, deployment, account or security action ran.

## Approved deferred Home/shell scope, 2026-10-12

The owner approved carrying current-version deferred work into the sole candidate.
The bounded Home/shell product and regression delta from preserved f14a73fb is
applied to PR #23: shared spacing tokens, playlist/recommendation semantics,
announcement typography/shape tokens, a labelled 48-pixel dismiss target, eight
Home/shell tests and five inspected preserved Linux references. No retired PR,
workflow or old source branch is revived. Import hub copy now describes chosen
resolved songs. Production startup never imports the Android-only synthetic
selector entrypoint under test/support; it opens only separate scratch boxes.

The eight scoped tests, full analysis and all 319 aggregate tests pass. Earlier
runs exposed a first-N widget's fixed-delay I/O race and background shuffle-fixture
preloads reopening a deleted cache. The tests now wait for a durable routing audit
and isolate queue-state assertions from unrelated preloading; product assertions
and production audio code are unchanged. Failed and passing logs are retained.
Both strict Windows suites fail all 40 comparisons. Exact source e705fb2b passed
319 tests and all 24 priority visuals in
[Linux run 38215906252](https://github.com/topcat432/musify-personalized/actions/runs/38215906252).
Only the three deliberate hub-copy screenshots failed. Their reference
before/after/diffs were individually reviewed and only import_hub_light,
foundation_import_hub_light and foundation_import_hub_dark were adopted from
that exact run. Strict rerun and native acceptance remain required; the comparator
is unchanged.

I11 reference source 07508cbd4eda8b33640d00195b3f52a75ebb2f8d passed exact
[Linux CI 38212793878](https://github.com/topcat432/musify-personalized/actions/runs/38212793878).
Normal-entrypoint native e1b1bbd8 verified reverse selection/source-order preview,
cancellation, two zero-addition transfers and restart retaining an empty newly
resolved delta. Copied-Hive inspection confirms every library/source value,
old audit, setting and offline registration exact. Only two confirmed routing
audits and the resolution baseline were added; four normal Hive files were
byte-exact across installation. The nonempty delta rehearsal uses isolated
synthetic boxes and has not yet completed. This is not phone/provider/signed
delivery acceptance. Master remains unchanged and production gates remain held.

## Import subset routing verification, 2026-10-12

The owner approved I11 individual and newly resolved selectors for the current
version. The candidate preserves all/first-N modes, chosen alternate recordings,
source order, existing destination contents and staged import decisions. Newly
resolved compares source-row/recording identities against every resolved row at
the last successful confirmed transfer, including rows not selected then.
Legacy count-only audits and interrupted/unverified writes remain unknown;
explicit selection is available to establish a real baseline.

The additive versioned metadata is confined to existing import metadata maps;
there is no Hive adapter/schema migration or live-data operation. A pending
marker precedes destination writes, final tracking failure reports saved music
with unknown tracking, and matching/review checkpoints preserve newer routing
state. All 14 Hive-backed feature tests and four actual destination-page tests
pass; full analysis is clean and all 311 aggregate tests pass. Both unchanged
strict Windows visual suites fail. Deliberate destination changes were inspected
in before/after/diff images; reference Linux visual verification and exact-source
CI/native acceptance remain required. Initial exact Linux run 38212210623 passed
analysis, 311 tests and all 19 priority visuals, and failed only the three intended
destination screenshots. Their Linux before/after/diffs were deliberately
reviewed; only import_destination_light, import_destination_compact_dark and
import_destination_options_compact_dark were replaced from that pinned run.
The comparator is unchanged and strict rerun remains required. The normal
e1b1bbd8 debug APK installed on explicit emulator-5556 / musify_rehearsal_api35
with all four normal Hive files byte-exact; this is not a signed or phone update.

The takeover preserved all seven inherited dirty files at 251f5c43. The ignored
D05 native scratch source was preserved outside Git in the existing private
acceptance evidence directory so full analysis does not scan that rehearsal.
Protected master remains a7863235 and PR #23 remains draft. Provider completion,
physical acceptance and signed delivery remain held; no new provider request,
phone action, merge, signing or publication is authorized by these checks.

## Normal Search categories and owned background checkpoint, 2026-10-12

Normal Search now displays provider-typed songs under Songs / YouTube Music
and retains generic results under YouTube videos. A generic video is no longer
implicitly labelled a song. Only exact IDs already in the song category are
removed from the video category; unknown and long results remain discoverable.
There is no duration cutoff. Metadata, result order and explicit recording
choices remain intact. Generic lookup and unrestricted manual matching are
unchanged. A failed category does not discard the other category, and available
videos avoid repeated failed artist-song lookups. Existing lifecycle guards
cover both categories; no media transport, account or data schema changed.

All 13 actual-Search category/lifecycle checks, clean analysis and 294 aggregate
tests pass. The initial Windows aggregate run passed the 294 test assertions but
failed at shuffle-test Hive teardown with an OS file lock; the unchanged isolated
suite and aggregate rerun pass. Both strict Windows suites remain FAIL, with all
35 actual images byte-exact to the retained control. No goldens/comparator changed.
Exact Linux CI and native metadata runs are stamped separately to their source/APK;
these checks cannot establish provider listening or physical playback.

Retained normal-entrypoint source 5721bb181a9674e2a7ca16e4a0f062f734cfc1f0 passed
owned-file Home/background/screen-off queue advance and natural final pause on
emulator-5556. Native media-session dispatch paused at 26,501 ms, held position,
resumed the same item and paused at 29,975 ms while Android reported Asleep.
Input-key attempts were inconclusive and are not product-failure evidence.
Offline mode was restored to false, the app stopped and all three owned WAV
hashes retained. Only fixture recents/listening stats changed; all other keyed
values, original recents/order and non-fixture stats remain exact. Audibility,
focus, output accessories and complete provider playback remain unverified.

## Search lifecycle repair and native metadata verification, 2026-10-12

Search now rejects obsolete completions after a newer submission, input change,
clear or disposal. Old requests cannot replace current results, clear the current
loading indicator, touch disposed notifiers or continue obsolete artist fallback.
A new search clears the previous results so a failure cannot present old songs
under the new query. Existing metadata services remain the production defaults;
optional loaders keep the actual-widget lifecycle fixtures offline.

Four original lifecycle failures and the stale-results-on-failure case were
reproduced before repair. All seven lifecycle/fallback checks, clean analysis and
288 aggregate tests pass. Both strict Windows suites still fail; every one of
35 actual images is byte-exact to the retained control. No golden/comparator,
media transport, client identity, credentials or user-data schema changed.

Normal-entrypoint source 663f22dbf0d593f1496f6d89fbc1ba375404f8da was separately
rehearsed on owned emulator-5556: Search displayed real artists and songs without
a captured parser/search error. All four Hive files were byte-exact across the
in-place debug update; after metadata browsing, user/settings/offline registries
remain byte-exact and the only cache-value difference is one derived timestamp.
No song/preview/download was activated. This verifies metadata/UI, not provider
playback. Exact repaired source 5721bb181a9674e2a7ca16e4a0f062f734cfc1f0 passed
[Linux CI 38195882671](https://github.com/topcat432/musify-personalized/actions/runs/38195882671)
and normal-entrypoint native loaded results, clear and Library return. All four
Hive files remained byte-exact through that Search/navigation phase. Controlled
widget fixtures establish obsolete/disposed completion safety; native browsing
alone does not force those races. Later fixture-play changes are recorded above.

## Owner clarification and attribution correction, 2026-10-12

The owner is implementation-flexible, with avoidance of approaches risking a
YouTube account ban as the stated implementation constraint. The mission is to
restore the original listening result; engine/provider/routing may change while
preserving YouTube-primary preference, no subscription dependency, native queue
and background/screen-off playback, intended recording identity and all library
data. The boundary against evading verification/access restrictions is an
assistant execution constraint, not an owner-imposed no-spoofing rule. Unofficial
software or public protocols are not inherently classified as evasion.
See [decision D-015](DECISIONS.md#d-015---listening-outcome-and-execution-boundary-attribution).

This is a documentation correction only. Technical/native/CI evidence keeps its
original source stamp; provider recovery remains unproven. No media, account,
device, product-code or data action is part of this correction.

## Upstream remedy review and Search metadata correction, 2026-10-11

The actual PR 390 patch and linked alternatives use Apple/VISIONOS identity
substitution for their reported streaming remedy. That was not applied under
the assistant execution boundary against evading verification/access restrictions;
it was not an owner-imposed no-spoofing preference. Availability/header corrections
are already present; WEB/HLS hunks do not repair the captured fifth-range refusal.
Official Musify's related buffering PR 955 was merged then reverted; its current
cleartext-proxy correction is separate from this provider denial.

A small ordinary date-parser correction from the linked branch was isolated after
reproducing the retained Search FormatException. Compact streamed date labels now
leave an unknown optional date while retaining the full results. Four new offline
fixtures pass (three reproduced failures before repair); analysis and all 281
aggregate tests pass. Windows strict failures remain, with all 35 actual renders
exactly unchanged. Original headers, resolver identity, URLs, user-data schema and
terminal 403 handling are unchanged. The 0bcb90f1 / 4e9325d0 native evidence is
preserved; no new provider request, APK install or deployment occurred.
See [the source/patch review](YOUTUBE_UPSTREAM_REMEDY_REVIEW.md) for actual changes,
release status, reproduction limits and the protected boundary. The Search repair
is not a provider-completion pass; future roadmap and production gates remain held.

## Owned native pass and fresh provider denial, 2026-10-11

Runtime source 4e9325d07c0bd0fae4295e6c9226c1a6d904292c retains the production
transport correction from 54c3ed85 and adds only an isolated test entrypoint.
[Exact Linux CI 38179065225](https://github.com/topcat432/musify-personalized/actions/runs/38179065225)
passed analysis, 277 tests, 35 strict visuals, flavor boundaries and unsigned assembly.
On owned emulator-5556 / musify_rehearsal_api35, generated Opus/WebM passed full
70-second playback, 35-second seek, 68-second tail/completion and natural advance
through a full 8-second second file. Independent range inspection verifies every
first-file byte, a completed tail beyond 1 MiB and no source failure. No provider
was requested during the owned test; volume zero does not prove audibility.

After restoring the normal entrypoint, exactly one never-denied fresh recording
initialized native Opus and advanced, then the originating headers-phase response
was HTTP 403 for bytes 1048576-1310719 of a 5,108,604-byte source, after exactly
1 MiB delivered. The proxy source/responseDone chain retains the same origin;
synthesized runtime nativeCode is null. The URL was unexpired, its original
User-Agent has exact-URL provenance, and the resolver configuration was unchanged.
The owned app was stopped immediately, with no manual replay or denied retry.
This establishes that denial, not its account/IP/token cause or a global outage.
Complete provider listening/download/preview remains FAIL/BLOCKED.

All four normal Hive files were byte-exact through both owned runs and installs.
After normal browsing/playback, only search history, recents/listening stats and
eight derived cache additions changed. Every other user value, all settings,
usernobackup and original cache values remain exact; no keys were removed.
The normal app is installed and stopped on the owned AVD. No phone operation,
merge, signing/publication, deployment or migration ran. See
[AUDIO_TRANSPORT_DIAGNOSTICS.md](AUDIO_TRANSPORT_DIAGNOSTICS.md) for the native gate,
fixture setup correction, private evidence location and separate search parser failure.

## Originating audio failure evidence, 2026-10-11

Checkpoint 77f339a697e0a752db505d93cdf64f695c7fc023 passed exact
[Linux CI 38173114591](https://github.com/topcat432/musify-personalized/actions/runs/38173114591):
261 tests, 35 strict visuals, analysis, flavor boundaries and unsigned assembly.
Its normal fresh owned-emulator playback failed after Opus initialization; the
primary HTTP status was not retained. This does not prove a new 403. The app was
stopped at the first error with no manual replay; full-song/next-song remain held.

The follow-up preserves safe structured originating HTTP/range/body failures and
proxy completion chains. It fixes demonstrated valid Content-Range rejection
and prevents an already active read yielding bytes after another read fails.
Original URLs/agents and true-403 terminal handling remain unchanged. Diagnostic
fields exclude URLs, tokens, arbitrary header/body text and private metadata.
The old player code 0 can be synthesized by the app and is not HTTP evidence.
[Transport diagnostics](AUDIO_TRANSPORT_DIAGNOSTICS.md) records contract comparison,
offline fixtures and the specific next discriminating tests, which have not run.
Clean analysis and all 277 aggregate tests pass; 60 focused tests cover the
transport/provenance/runtime paths. Four private offline controls against the
preserved 77f339a6 source reproduce the old defects. Both strict Windows suites
still fail all 35 images; 33 images exactly match the retained unchanged-source
control, with the two About differences confined to prior identity/version fixture
labels. Representative expected/actual/diff images were inspected. No goldens or
comparator changed. Exact Linux checks on the new source remain required.
No phone install, deployment, data migration or new public-media request occurred.

Recorded 2026-10-11. This is the living map; verify current GitHub heads/runs
and connected device identity before relying on dated observations.

## Header provenance and independent upstream comparison, 2026-10-11

The last committed checkpoint is f8702efee24711aa2e40f95f3ff61eef447a982b.
Its exact [Linux CI](https://github.com/topcat432/musify-personalized/actions/runs/38165158295)
passed analysis, 253 tests, 35 strict visuals, flavor boundaries and unsigned assembly.
The follow-up repair preserves the User-Agent from the existing resolving request
through manifest/length probes, downloads, native playback and exact-URL derived
cache contexts. It changes no client profile or authentication, forwards no session
credentials and keeps real HTTP 403 terminal. Unknown/partial cache contexts are
retained but never assigned a guessed identity. No user-data schema changes.

Local analysis and all 261 tests pass, including eight new provenance fixtures and
restart coverage. Both unchanged strict Windows suites still fail their 35 images;
the current render artifacts are compared against the retained source control.
No goldens or comparator were changed. Exact Linux checks for this follow-up and
a native complete-provider pass remain required.

Official upstream 10.5.3, source a5edc73c501aea5428b419ec14eaa46bc2fef83e,
was separately installed on the task-owned musify_rehearsal_api35 emulator.
Startup ANRs preceded playback and recovered after the host reboot and normal
Wait action. One fresh normal source selection then failed natively because
Android rejected cleartext HTTP to 127.0.0.1, used by upstream's header proxy.
The app was stopped after the error. This independently confirms a local upstream
transport defect; it does not establish a global YouTube failure or candidate
playback recovery. The fork uses supported native URI headers while preserving
its existing GitHub-only bounded-source loopback allowance. No security policy,
phone installation, signing, publication or merge changed.

## Playback compatibility investigation, 2026-10-11

Checkpoint 70b96f8e93e319da9ccdac4a284788a6e5d77f50 remains recoverable.
The selected Samsung is available again; its unchanged preview APK has the
previous recorded hash and source stamp. A normal baseline online attempt
failed at manifest availability (HEAD, stream 313). Existing downloaded audio
completed and naturally advanced; background/screen-off playback remained active.
Playback was paused and Offline Mode restored to false. This validates baseline
local behavior, not candidate physical acceptance or audible output.

Retained candidate URL metadata rules against expiry at the recorded failures:
the two URLs expired after 14:26 UTC, while failures occurred before 10:07 UTC.
Signed query strings are unchanged; ranges fit their declared sizes; neither URL
contains an n challenge. A service requirement on the anonymous media-delivery
path is the leading remaining hypothesis, not a proven account/IP/token cause.
The upstream PR #390 discussion independently reports a similar initial-buffer /
later-range failure. Its proposed identity switching to avoid verification
was excluded by the assistant execution boundary, not an owner preference.

Scoped compatibility changes replace the fresh manifest HEAD preflight with a
one-byte GET, cancel its response body, and treat genuine 403 as terminal without
client fallback or download URL refresh. A retained same-URL HEAD 403 / GET 206
pair justifies the method correction. Download requests also use uppercase GET
and clamp their range to the remaining file length; those defects were reproduced
by the owned 16-byte fixture. The native bounded transport already did both, so
these downloader corrections do not explain its earlier mid-song failure.

Local analysis and all 253 aggregate tests pass, including eight new extractor /
download fixtures. Both strict Windows visual suites retain their prior bounded
rendering failures; no goldens/comparator changed. Exact Linux CI is required;
read the current source-pinned checks on PR #23 for its result.
No denied media was requested again, no credentials or
security settings changed, and no new native complete-provider playback pass is
claimed. See PRODUCT_ACCEPTANCE.md for hypotheses and supported integration
options. Merge, signing, publication and live installation remain held.

## Prior local acceptance checkpoint (70b96f8e)

Sole candidate remains draft PR #23. Latest tested code is
769d60f404f7b7ad041a6708916dec194574c831; protected master remains
a786323556275a0de745ffca4d3affc088ac2055. Clean local analysis and all 245 tests
pass. Both Windows strict visual suites still fail with the previously bounded
text-rendering differences; no goldens/comparator were regenerated or weakened.
Reference CI is [38145671652](https://github.com/topcat432/musify-personalized/actions/runs/38145671652).
It completed SUCCESS: 245 tests, both strict Linux suites (35 images), all
debug/F-Droid boundaries and unsigned release assembly. Prior exact a3f12e89 CI
[38143273232](https://github.com/topcat432/musify-personalized/actions/runs/38143273232)
passed 241 tests, 35 strict Linux images, debug/F-Droid boundaries and unsigned
release assembly. CI builds are not signed updates.

The latest verified disposable debug APK has SHA-256
ccf2c8d9fb0a6e4c1ad08e8774e1c690ae1255cd466c1f46cf1a1032a877024a,
package com.topcat432.musifypersonalized.preview.debug, code 300000002 and an
embedded exact 769d60f4 source stamp. Both recent owned-emulator in-place
updates preserved all three synthetic Hive files byte-for-byte before launch.
No Samsung update occurred. Private evidence stays outside Git under
musify-source-comparison/emulator-rehearsal; see runtime-debug-769d60f4-proof.json
and 769d60f4-install-preservation-proof.json.

Three additional native defects were reproduced and repaired: destination refresh
expanded an approved first-N count to all resolved songs; deleting a folder from
its nested page popped the root shell and left a blank screen; offline Library
showed undownloaded custom playlists and hid its local-song entry. Actual-widget
regressions and durable import/cleanup/settings/updater fixtures cover the fixes
and scope boundaries. First-one confirm/refresh/review passes natively on a3,
and full Android reboot preserves every Hive byte and selected/excluded state.
The folder repair passes natively on 58f1edbb; downloaded-only Library and
local Offline/Recents playback pass on 769d60f4. Final full Android reboot
preserves all three Hive bytes. Independent closure-final-preservation-proof.json
retains exact original playlists/likes/imports/results/selected/excluded state
and nine settings, explicitly accounting for routing audits, local playback
Recents/stats, selected High quality, empty generated-folder/pin keys and three
owned fixture cache entries. No provider download is represented by that cache.

PRODUCT_ACCEPTANCE.md now reconciles all 38 matrix rows with named A/E/D/R
subgates; chronological pending/failure prose below it is historical. All 28
safe rows have bounded local or fixture evidence; that does not turn online,
physical-output or exact signed-release subgates into passes. Complete provider
listening/download/preview remains FAIL/BLOCKED after the observed later-range
403; no denied media was requested again. Selected Samsung availability,
physical focus/output/accessories, the I11 subset-delivery scope decision and
exact signed in-place rehearsal remain prerequisites. Master, signing,
publication and live-phone changes stay on hold.

The earlier checkpoints below retain source/data/channel history. Treat their
old test counts and pending repair statements as historical supporting evidence;
the current checkpoint and reconciled matrix supersede them.

Expanded production acceptance now has conditional owner authorization for
integration, the existing signed publication workflow and an in-place Samsung
update only after backup, product, visual and signed rehearsal gates pass.
See PRODUCT_ACCEPTANCE.md for the source-linked scope and per-path ledger.
The Samsung was unlocked and its actual app-supported export was saved and
independently inspected. The owner confirms its empty library was expected and
plans a fresh supported Spotify export/reimport. Do not substitute historical
imports for this current state. No merge, signing or live update has occurred.
Disposable real-export restore/full restart/native re-export passed with every typed key/value exact and no exceptions. Final signed in-place rehearsal remains a gate.

The current candidate also fixes two reproduced PlaylistPage defects: its
unavailable-state sliver must be hosted by a scroll view, and its Shuffle button
must submit natural-order songs with player shuffle enabled. Targeted regressions
(12 tests), aggregate tests (161) and local analysis pass. Final strict Linux CI
and actual final-APK runtime coverage remain required. Controlled disposable
same-name backup inspections read fresh counts 2/1/2 without restoring; the earlier
stale-selection observation did not reproduce in that bounded check.

The latest disposable runtime checkpoint is recorded in PRODUCT_ACCEPTANCE.md.
Native public-fixture decisions preserve the exact accepted alternate, reopenable
No match metadata, exclusion audit, all source rows and existing likes. All-resolved
routing and a repeated no-additions transfer ran with an unresolved row retained.
Additional playlist, restart, backup and playback paths remain open. A reproduced
covered-card accessibility defect has a candidate repair; local analysis and all
162 tests pass. Host ranged audio GET success does not satisfy native playback.

## Source and channels

| Item | Proven state |
|---|---|
| Repository | topcat432/musify-personalized |
| Integration | Protected master, observed a786323556275a0de745ffca4d3affc088ac2055 |
| Sole active candidate | Draft PR #23, agent/local-stable-consolidation |
| Initial candidate commit | 16d06d92d4da8354a0d03e765ec77a53dbd2f626; check PR HEAD for later commits |
| Foundation | #20 head 395ecace3da567ef1437c7a2229252ef84ee94de |
| Playback intent | #21 head 76201eeb409594117c873716a41f7ebc6dd3224d, with both P1 defects corrected |
| Deferred Home/shell | #22 head f14a73fb7b9b56682d72fa9868a9dec3ffb1a2ac; preserved, not integrated |
| Retained stable identity | com.topcat432.musifypersonalized.preview |
| Debug isolation | com.topcat432.musifypersonalized.preview.debug |
| F-Droid | Existing com.gokadzev.musify.fdroid identity/permission boundary preserved |

Get the current candidate with gh pr view 23 --repo topcat432/musify-personalized
--json headRefOid,statusCheckRollup. Do not confuse PR test merge refs, branch
HEAD, installed baseline and published source.

## Installed binary baseline

Selected Samsung SM_G998U1, Android 15/API 35. Read-only evidence proved
the daily package com.topcat432.musifypersonalized.preview, label
Musify Personalized PREVIEW, versionName preview.0.1.1, versionCode 300000001.
Installed APK SHA-256:
2dd3360db7f5376fbe6768709554c2ebc8991a1588d87750d474ffe55e3ab1ea.
Public signer SHA-256:
58c5316466da7a426c4411beb33b3b594ef58875bcfa31e092a5afce8cf9999e.
The signed APK is preserved outside the repo; it is not a data backup.

The actual app-supported export contains the compile-time GIT_SHA source stamp
0ea1b44dad777efd03c819becd31acffa996427f, verified against that source's
String.fromEnvironment implementation. Its legacy package/version labels are
hardcoded; Android package manager and the extracted APK establish identity.
Original preview run 29479259739's artifact expired, so comparison against that
original CI artifact remains unavailable. The stamp strengthens source
attribution without proving an exact historical CI-artifact hash match.
The old About 10.1.0 was hardcoded and cannot identify the binary.

Actual Samsung export SHA-256:
9f74763b07e2dbd89336d58c37a3379282a49bfcddf37cbb2dd773957770bc34.
Its 251,405 bytes contain four user keys and three settings keys: empty liked
playlists, two recent songs, two search entries, listening statistics and the
three existing settings. Imports, matches, favorites and custom playlists are
zero. Independent whole typed-map SHA-256:
ae6c1be7d8fe8aa9f1e3b9dc460626c7e7a4f0ab2dcc66410f362eba0468fa17.
Private exports and UI evidence remain outside Git and Library.

Latest tested candidate: 26bd0e98f4980f69c017aee52c62fd93965b1d16,
CI 38123616644 successful (analysis, 171 tests, 35 strict goldens and APK builds).
Its exact emulator debug APK hash is
785f0fadee679c4c2c3f811ebc1207abeb4ad7f4f1e3ca17dc7e0350c884d55b.
Native public-track playback still fails HTTP 403. Host finite-range GET
acceptance does not prove native decoding, preview timing or completion. The
provider accepts a finite 256 KiB range but rejects full and open-ended requests.
The owner subsequently approved a GitHub-flavor-only IPv4 loopback exception:
HTTP 127.0.0.1, includeSubdomains=false; external cleartext remains denied.
The pending candidate uses just_audio's standard byte source to supply finite
HTTPS ranges through its random-port loopback server and fresh UUID-v4 source
path. Requests are lazy, bounded to 256 KiB, limited to four concurrent reads,
validated against exact Content-Range, timed out and closed on cancellation.
No device-wide policy, credentials, cookies, proxy or client impersonation changed.
Local analysis and all 208 aggregate tests pass. Native healthy playback on this
new code remains blocked. Exact-source CI 38128871154 passed all required gates.
Its emulator APK SHA-256 is
8049a5bda7b5f7b415215eee9f8d7845c74d712a8081594830e2cd3068188c9b.
Native controlled PCM 1/2/3 advance and pause the completed tail correctly;
shuffle-off restores order and Play Next insertion survives queue replacement.
Public Here Comes The Sun and Dreams initially decode but truncate after the
first MiB. Bounded diagnostics of both native cached URLs return HTTP 403 at
offset 1048576 while accepting the first finite range. No denial workaround was
attempted. Sustained listening, preview timing, seeking and clean failure remain
release blockers. Pending repair connects just_audio 0.10.6's separate errorStream
API, stops repeated upstream requests to a failed source and cancels superseded
queue retries; exact-source/native acceptance must follow.

The same repair pauses a completed non-repeating queue tail, preserves
SponsorBlock seeking for byte sources, starts manual preview's 30-second timer
without awaiting playback completion, and uses public YouTube oEmbed metadata
for exact-video lookup. Quick Review keeps its existing 12-second preview.
oEmbed has no duration; the candidate does not invent one. Denial, redirect,
oversized metadata and timeout fail without authentication fallback or saving.

## Signed published release is a different package

Historical tag personalized-v0.1.100000010, source
27256cedefd915e905d7478107104cebdbbecebc, package
com.topcat432.musifypersonalized, versionCode 100000010.
APK SHA-256:
d77204a480a56cd5dfb5a62d27b9a8910a148528ec97adf3de37bf4b498059bc.
Same public signer, different Android data container. It is not an in-place
update for the current Samsung app. No consolidated candidate has been signed,
published, merged or installed on that phone.

## Validation and acceptance

Local initial candidate: 157 aggregate tests passed, targeted regressions and
analyzer passed; unsigned assembly succeeded. Unsigned APK code 300000002,
versionName 0.1.300000002, retained package, correct label, non-debuggable.
Linux reference run 38112105227 on initial candidate: aggregate checks passed;
33 unchanged strict goldens passed, only the two intentional About images failed.
Both Linux About before/after pairs were reviewed; only those two PNG baselines
were deliberately replaced. Subsequent exact-head CI must prove the result.

Run 38113993655 on 12e709c6 passed analysis, aggregate tests and all 35 strict
goldens. Its Android build stopped because the runner lacked the pinned NDK;
both canonical workflows now prepare that exact SDK component explicitly,
using existing licenses and rejecting new prompts.
Run 38114487224 passed the same strict gates after the restore fix and reached
native compilation, then stopped because CMake 3.22.1 was missing. That exact
component is now explicit too. Verification also checks out the candidate SHA
directly and embeds it, instead of attributing a temporary PR merge ref to the
candidate branch.

Run 38115096390 on exact candidate 953e652c3031abd0dc3e3e59e3ca22875981786d
completed successfully: analysis, aggregate tests, 35 strict goldens, universal
debug identity, F-Droid permission boundary and unsigned release integrity/
package/version/non-debuggable checks. The three obsolete publishing workflows
fdroid.yml, pre_beta.yml and pre_fdroid.yml are removed in the subsequent
consolidation: their analysis/build roles have canonical coverage; their upload
steps incorrectly targeted gokadzev/Musify and are intentionally retired. No
legacy publication is recreated. The retained F-Droid code/identity remain.

Run 38117095235 on 73ff5421e3f941909e4e164a6b43c9660b3afa0d also completed
SUCCESS after both restore fixes and workflow retirement: clean analysis,
aggregate tests, all 35 strict goldens, debug/F-Droid builds and unsigned release
verification. The intervening 2f61715e run stopped only on import ordering;
73ff corrected that directive. No signing or update artifact was published.

The visual suites now share one loader. The official DejaVu pinning experiment
did not match the stored Linux baseline and was backed out. CI captures its
exact selected font/toolchain for bounded rendering diagnosis. Windows is not
the pixel reference. Do not report a visual PASS until strict comparisons pass.

Official emulator 37.2.12 and Android 35 Google APIs x86_64 image installed on
DESKTOP-OPE9IIV with existing accepted licenses unchanged and usable WHPX.
Task-owned AVD musify_rehearsal_api35, emulator-5556, is separate from other
projects. Actual Samsung export and disposable restore/full reboot/re-export
passed as recorded above. Historical 2,643/2,454 counts are not today's inventory.
Signing/publication and live-phone update remain held.

The preserved installed APK failed synthetic file-picker restore on the
disposable emulator: the selected temporary file was removed before asynchronous
inspection completed. The candidate now awaits inspection before cleanup; a
picker regression reproduces the old failure and all 17 backup service tests
pass after the fix. Candidate emulator inspection then exposed a second defect:
LayoutBuilder in AlertDialog's intrinsic layout left the validation modal blank.
The extracted summary now uses an intrinsic-compatible Table; its failing-before/
passing-after dialog regression and all 17 service tests pass.

Synthetic Android restore/restart/native export is now verified on that disposable
AVD using isolated .preview.debug. Tested APK source is
2f61715e26cda6a3e01e66cfa09f647f0929478e (73ff only reorders an import), SHA-256
1f8900cc060cafc180da132c03fa9c7a4aa9b5fe90d85b6ba6581410e2d61e09. Its signature,
embedded source SHA and ZIP integrity passed. Picker/review/restore succeeded;
UI verified 2 favorites and the custom playlist's recording 2 before recording 1,
including after a full Android reboot. Android System UI initially stalled but
recovered after a bounded Wait; the subsequent app restart and export succeeded.
Native saved-file reopen and an independent Hive inspection proved 5 imported
tracks/results, 2 strong matches, 1 review, 1 unmatched, 1 excluded, 0 errors,
2 favorites, 1 playlist and exact original typed key/value/list preservation.
The explicitly selected first-run No response added only
settings.shouldWeCheckUpdates=false; whole-map equality without accounting for
that action correctly failed, and the exact expected addition comparison passed.
Export SHA-256 b1811e90da8a1b4b9d0f3d941da82a453c02bc9d949f56bfe5dc6194bd9e7af7.
This is synthetic evidence, not real Samsung data acceptance or playback proof.

Bounded observations to review before production: overwriting a selected backup
under the same filename appeared to reuse the earlier picker payload; a distinct
filename restored the corrected synthetic fixture. Root cause is unproven.
An invalid playlist lookup also exposed a RenderBox/Sliver mismatch in the
error-screen branch of PlaylistPage. These were recorded, not silently passed
or expanded into unrelated engineering. Use a distinct export filename meanwhile.

## Recovery and retired work

Before cleanup, all 25 original branches, tags and 22 PR heads were bundled,
restored with identical refs and passed git fsck --full.
Task-local bundle: musify-source-comparison/repo-recovery-20261011/
musify-pre-cleanup.bundle (outside the checkout), 40,945,016 bytes.
SHA-256: 10eb04fe3319d31ac5bc6af08862f8c923ae0eb3524cdd10d9bdf75c325e325a.
Adjacent inventory/classification/proof records contain exact branch/PR heads.
Cleanup dispositions were verified after each authorized action.
PRs #4/#7/#19/#20/#21/#22 were closed unmerged with factual dispositions.
All 24 original non-master branches were retired with fresh guards and exact-SHA
leases after verified preservation. Fresh reconciliation proves only protected
master and agent/local-stable-consolidation remain, with only draft PR #23 open.
Master is unchanged; no tag, release or artifact was removed. The initially
rejected cleanup passed fresh review after explicit authorization; diagnostic
and transient DNS pauses were reconciled without repeating completed actions.
Exact retired heads and deferred #22 are indexed in REPO_RETIREMENTS.md.
No unique commits are discarded; #22 remains a roadmap reference, not an active
parallel candidate. Recovery instructions are in CONTRIBUTING.md.

## Single operating path

Runtime checkpoint: ee5ea7c93ecda846c7b3921dc6d134031b5e412d passed exact-source
CI 38131947201 (213 aggregate tests, 35 strict goldens and all build boundaries).
Its verified disposable debug APK was installed with byte-exact Hive
preservation. Native public playback now advances once per failed track and
stops at the failed tail after exactly three failures. Complete streaming still
fails: first ranges return 206, but the first nonzero 1 MiB range returns 403
for two independently checked sources. Probes stopped at denial. A third source
also truncates in native playback; independent 403 attribution is unproven.

Bounded follow-up observes just_audio stream-response completion errors using
a licensed local copy of the already pinned 0.10.6 package, cancels failed source
reads, stops native retries promptly, blocks replay of a known failed source,
and exposes a Library action with a sanitized error. This repair is committed
at d3d353fc1a2ac5483ffb0a74048513b2de7318b1; exact CI 38134013870 passes all
225 aggregate tests, 35 Linux strict goldens and all build boundaries. All 35
unchanged Windows strict goldens fail; inspected differences concentrate in
text rendering. Disposable native damaged-local-file error and Library action
pass, then the original WAV hash is restored and selecting healthy local audio
clears the error. This does not prove native denied-source handling or complete
external streaming. No provider was requested again.

The same native local-control check reproduced two existing defects: zero seek
reports position 0 to Android but leaves 00:09 on the slider, and completed-tail
Replay seeks zero but remains paused. A bounded follow-up updates zero/duration
states without retaining a previous widget's global position and resumes the
healthy Replay through the existing play handoff. Automated and native checks
must pin this follow-up's exact committed SHA. No release/Samsung update occurred.

Read AGENTS.md and CONTRIBUTING.md; use debug.yml for Linux verification and
signed-release.yml only for separately approved release. Product vision/import
roadmap and VISUAL_SYSTEM.md remain useful design references. This map tracks
facts, not blanket permission. Next gates: verify current-head CI and full product
runtime/visual acceptance, exact signed in-place real-data rehearsal, reviewed
integration and publication, then conditional in-place phone acceptance.

## Incoming-file ownership correction, 2026-10-14

Exact source a24730c00e8b0dd3c12a7aa39a5cc42834739c32 CI38628233753
is terminal FAIL698 passed/one failed; analysis/49 Java/3310 inflater passed,
visuals and APK builds skipped. Its correction is bundled with reviewed pending
finish/global-preview ownership/early incoming-row-budget fixes; all remain
unqualified pending successor exact-source CI. Fresh20:12:38Z normal3GiB host
admission refused100.84%; no local test/build launched and no worker budget reduced.
Cold semantic audit28208 is completed PASS on immutable signed c249, not pending:
independent saved-file cold-export restore/reopen whole user/settings typed hashes
match the preupdate baseline. About/Back, empty-library/rollback, picker/cancel/Save
and approved playback queue remain separate pending gates. Samsung and other
workloads remain untouched; no new signing, release, install or publication.
## CI-qualified incoming ownership source, 2026-10-14

544192c4b9a9ebef5c48d50c3e42c86af21e98b6 exact CI38630742666 PASS:702
aggregate/40 strict Linux visuals/analysis/49 policy-reader/14 actual channel/
3310 inflater/all required Android builds. Exacta247 control reproduces the
pending-cancellation defect. Source-only lifecycle contract tests are the next
bounded follow-up; current Windows and native intake remain unverified. Signed
c249/runtime/normal-clone receipts are preserved. Cold semantic audit28208 is
completed PASS; About/Back and subsequent native gates remain pending.
## Whole-source readiness milestone in qualification, 2026-10-14

Qualified base8ff4297fbe80b29c073a0c362253f996c6256d02 exactCI38633231647
PASS702 aggregate/40 strict Linux visuals/30 channel/49 reader-policy/3310
inflater/all required builds. Current dirty successor implements the approved
whole-source-ready option, live raw-data checks, authoritative exclusion-index
projection and current stored destination collection protection; [contract](SPOTIFY_WHOLE_SOURCE_ROUTING.md).
First targeted43 PASS/seven FAIL and complete rerun45 PASS/five FAIL are retained;
Final targeted51 PASS; analysis and722 aggregate PASS. Both Windows strict suites
FAIL16+24; all40 actual image hashes equal the preserved F02 control, with no
reference updates. Exact Linux CI remains pending for this source.
Normal3GiB host admission is available (last67.12%). Fresh21:52:32Z26GiB native
admission refused99.65%; nothing launched. c249 cold semantic audit28208 remains
completed PASS, with About/Back/reliability/provider gates separate and open.
## Whole-source integrity review correction, 2026-10-14

The ce6bf615 candidate was independently reviewed before release acceptance.
Eight new contract regressions reproduce declared-total omission and revival of
missing stored destinations from stale display caches. The retained exact source
control fails8/8; correction passes8/8, clean analysis and730 aggregate tests.
Missing or malformed declared total leaves legacy completeness unknown; explicit
partial selectors remain available. Named totals count every source membership,
including repetitions and unsupported rows, rather than unique recordings. Total
changes are fingerprinted and revalidated. Absent Hive collection keys now mean
empty, including first use, deletion and empty restore; newer saved values remain
authoritative. No schema, adapter, migration or backup format changes.

The predecessor exactCI38646404403 result is recorded separately; its technical
checks do not resolve these reproduced review defects. Successor exact Linux CI
is pending. Windows strict rerun FAIL16+24; all40 actuals again match the F02
control byte for byte, with no reference updates. Signed c249 and cold audit28208 are unchanged;
native and phone gates are not inferred from host proof.

## Explicit empty source creation in qualification, 2026-10-14

Qualified predecessor7db12a5d2bd76d5fbfca48931e2f09ded272e4c3 exact
CI38647486899 PASS; host730/analysis and both Linux strict suites/builds pass.
Current successor adds explicit zero-song confirmation for genuinely empty named
sources, source-identity reuse, preserved destination edits and zero-song audits
that leave recording baselines unchanged; [contract](SPOTIFY_EMPTY_SOURCE_PLAYLIST.md).
Synthetic pure/widget/rollback/reopen/saved-file independent restore regressions
are present but not yet qualified. Fresh22:49:42Z3GiB host guard refused92.63%;
formatter, analyzer and tests did not launch. Nativec249/cold audit28208 PASS
remain separate, with actual runtime/reliability/provider/phone gates open.


Initial empty-source3a6eb762 exactCI38650766562 terminal FAIL on one redundant
StateError message conversion; tests/visuals/builds skipped. Separate-copy format
suggestions succeeded and source checkout remained exact. Correction is bundled
with frozen staged-value rollback comparisons and two in-place owner-edit
regressions; successor exact-source qualification remains pending.


Empty-source5967a624 CI38651502558 passed analysis/staged-value control, then
was cancelled for fake-clock IO harness correction. Actual saved-backup independent
restore/reopen and owner-edit service cases passed. c88dc79a exactCI38652526860
terminal FAIL757 passed/two failed: one miswired injection and one offscreen
compact repeat tap. Successor corrects those fixtures without weakening checks.


47a6ba02 exactCI38653580549 terminal FAIL despite759 assertions reported
passed: expected stale-source error escaped the widget root IO zone and failed
subprocess finalization. Successor bridges failure values into the caller's zone
and checks live emptiness before projecting an obsolete source snapshot; no
assertion or visual comparison is weakened. Full successor qualification pending.


050f00e7 exactCI38654623831 terminal technical PASS; feature acceptance HOLD
for reviewed false unchanged wording after a committed empty-source write.
Successor uses committed/unverified outcome and truthful saved feedback, retains
destination/newer source/pending audit, and covers reopen plus explicit existing-
destination reconciliation with no duplicate. Exact successor CI pending.


## Qualified truthful empty-source reporting, 2026-10-14

Exactb0e8d9f82bf335e95445c17e8da90b2ba9ace262 CI38655879713 PASS:
765 aggregate/analysis/16+24 strict Linux visuals/49 reader-policy/30 actual
channel/3310 inflater checks/all required Android builds. Exact050f00e7 control
reproduces false unchanged feedback after a committed write. The corrected
service/widget/reopen/reconciliation path preserves the saved destination, newer
source and uncertain audit with no duplicate creation. Nativec249 and its audit
remain separate; fresh23:51:29Z26GiB guard refused126.83%.

Next pure occurrence-plan prototype is staged without a production caller or
mutation API; [contract and decisions](SPOTIFY_OCCURRENCE_PLAN.md). It preserves
manual entries/order/removals and selected recordings, refuses unknown ownership
and ambiguous changed anchors, and does not introduce a storage schema or use
queue IDs as import ownership. Its13 pure tests are present but unqualified.
Fresh23:53:13Z3GiB guard refused100.87%; no formatter/analyzer/test launched.

## Occurrence capacity/schema proof and c249 About/Back, 2026-10-15

Qualified6a8d18fc CI38657271707 PASS778/analysis/40 Linux visuals/all builds.
Independent review found the pure planner bounded input but could propose10001
entries after appending to10000 retained entries. Successor refuses all appends
when destination plus proposal exceeds10000, preserving manual entries; exact
capacity/retry tests cover the edge. Ownership/collision sets remove quadratic
scans. Existing-schema tests cover ordered repeats/Hive reopen, saved-file checksum
inspection/independent restore, rollback of an unrelated owned write and distinct
runtime queue IDs without durable mutation. Guarded analysis and784 aggregate
PASS. Strict Windows FAIL16+24; all40 actual PNG hashes match the retained F02
control exactly. No comparator/golden changed. Exact successor CI is pending.
[Conservative create-only ownership design](SPOTIFY_OCCURRENCE_PLAN.md) is a
proposal: no production writer, marker, migration or playback change. Filtered
playlist playback still finds the first repeated recording and needs slot-aware
qualification before integrating exact recreation.

Host admission resumed at38.57% for3GiB checks; native26GiB admitted69.6%.
Pinned c249 About/Back rehearsal PASS on owned emulator-5558: four tabs selected,
About actual version300000015, Back returned to Settings, then Home selected.
All four normal-debug Hive files restored byte-exact/mode600 and owned graceful
shutdown verified. Canonical navigation proof is indexed by private
host-provider-diagnostic/c249-navigation-index.json and the existing native
milestone/acceptance ledger. Current successor source was not installed; c249
remains the immutable signed baseline. Earlier black/SystemUI failures remain
retained, so this is no blanket cold-start reliability pass. Empty/rollback,
picker/playback and eventual actual-phone gates remain. No merge/sign/publication.

5e45753af1ce0baec1f2031b85ffb5aded82bec8 exactCI38660191691 terminal FAIL
before aggregate checks: the new negative-control shell file-size limit also
constrained Dart's objective_c hook.dill compilation. It did not reach the
capacity assertion; no source qualification is claimed. Successor caps only its
owned captured command log at10MiB, refuses overwrite, stops its owned writer on
overflow/deadline, and requires assertion failure exit1 plus the named reason.
Synthetic logger contracts cover stream/exit propagation, compiler output outside
the log cap, existing evidence, overflow and timeout. No app/test/visual assertion
is weakened. The bounded negative control remains required before qualification.

## Qualified capacity correction and logger cleanup review, 2026-10-15

Exact1192aa56bfb428499d236f665922e93f9015206e CI38660962087 PASS784,
analysis/16+24 strict Linux visuals/5 logger contracts/49 reader-policy/30 channel/
3310 inflater checks/all required builds. The exact6a8d18fc negative control
reproduced the10001-entry proposal. Current Windows strict FAIL16+24, all40 actual
PNGs byte-identical to the retained control; no comparator/reference edits.

Independent review then found the CI-only command logger could leave a TERM-
resistant command or pipe-holding descendant alive after its leader exited.
Successor cleanup sends bounded TERM then KILL to its own private process group,
reaps the command, and preserves124/125 timeout/overflow and normal exit results.
Three Linux regressions check resistant timeout/overflow and an exited leader's
pipe-holding descendant, including no live owned writer. An exact1192 control
must reproduce the old cleanup failure; failed controls also clean their fixtures.
No app/library/playback behavior changes in this correction.

Signedc249 empty-library rehearsal is not qualified: two pre-restore harness
checks were corrected, then execution supervision lost the final process result.
The receipt has no UI snapshots/exports/restart/rollback proof and the independent
audit correctly refuses it. Four normal-debug Hives were restored byte-exact.
Read-only verification found no owned emulator process and the lease available
without abandonment. A new complete owned rehearsal and audit are required;
About/Back remains independently PASS. Current source is not installed.

4d720732 exactCI38663178136 terminal FAIL in the new logger contracts before
aggregate checks: owned writer cleanup passed, but the exited leader's flushed
prefix was lost while buffered read waited for8192 bytes. Successor consumes
available chunks with read1 and adds a cross-platform short-output timeout
regression. No deadline, output bound, cleanup or data assertion is weakened.

## System rendering isolation in progress, 2026-10-15

Retainedc249 System UI ANRs occur before restore. One fresh original5558 diagnostic
kept Musify stopped and captured system_server65% CPU, total73% (59% kernel,
6.8% IO wait), multi-second binder/overlay contention and MemAvailable about1.5GiB.
UIAutomator could not obtain a usable idle hierarchy; no app launch or restore
followed. This supports guest boot/rendering pressure, not proven RAM exhaustion
or a product restore-code defect. The prior black/ANR evidence remains retained.

The authorized isolated profile uses serial5560 with a flattened working clone,
720x1280/density320 and modern swiftshader, preserving API35/guest CPUs/RAM and
all host ceilings. Original5558 images/configuration stay unchanged and hash-
verified. Source wrapper adds explicit isolated cold-boot mapping and fixes
single-object process counting on PowerShell5;15 offline lifecycle contracts PASS.
Creation/native qualification remain pending in the private canonical ledger.
No app, phone, signing or publication change. See STORAGE_WORKFLOW for the map.

The isolated creation used self-contained QCOW2 images after raw conversion failed
at2GiB; that partial raw file is retained and hashed. The original source hashes
match before/after creation, and the cloned active userdata/encryption images must
pass logical qemu-img comparison without backing dependencies before native boot.
This changes disk representation and rendering environment, not application data
or the installed c249 APK. Native qualification remains separate from clone proof.
