# Current38-row release bridge,2026-10-13

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



This reconciles evidence; it does not upgrade old native results to a current full-product pass. Product3b012181 was tested for214s saved playback;9c89d4a1 exact CI38412302996 passes439 tests/all40 Linux visuals. Frozen transport/rehearsal sourcef314b3aa adds bounded same-provider redirects and sign-only defaults;460 local tests/clean analysis and11 offline workflow contracts pass. Its real production review preview passes12,042ms cutoff after seeking, pause/resume, Later cancellation and repeated decisions; independent post-UI and cold-restart Hive reopen passes. Normal-main integration remains separate.

Code carry-forward checked independently: backup service has no diff251f5c43→3b012181; screens/widgets/main/router have no diffb1dc64fa→3b012181. Transport changes affect live resolution/preview and need their own evidence. Original AVD durability is not inferred from persistent5558 clone proof. Samsung is deliberately last-mile, not an engineering setup blocker.

| Row | Existing subgate lineage | Current qualification / next gate |
|---|---|---|
| I01 | Actual disk-full/device failure is not simulated by the injected exception | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| I02 | These checkpoint passes use excluded synthetic rows, not provider searches | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| S01 | Complete playable provider result remains blocked | Earlier UI/decision evidence retained; real12s preview PASS; current normal-main search-to-play integration OPEN, not full-catalog proof. |
| T01 | Provider/proxy/security changes remain excluded | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| T02 | Operations ran only on separate synthetic storage | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| T03 | Acoustic/audibility proof requires physical outputs; title/artist lookup does not establish recording provenance | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| O01 | Complete provider download/play remains blocked | Component/pipeline narrowed:214s saved/native restart and186s redirected full host save PASS; full normal-UI source and broader provider/physical subgates remain separate. Known251/403 preserved. |
| D01 | D PASS package/version/signer/APK hash and export source stamp; historical CI artifact expired; R HOLD | Prior recovery/identity evidence retained with explicit source; persistent5558 clone four-Hive cold restart PASS; fresh phone/signed subgates separate. |
| D02 | A/D PASS saved real export and independent typed inventory; owner confirms empty library; R HOLD | Prior recovery/identity evidence retained with explicit source; persistent5558 clone four-Hive cold restart PASS; fresh phone/signed subgates separate. |
| D03 | A PASS validation/rollback; E PASS real export restore on 26bd; live restore excluded; R HOLD | Prior recovery/identity evidence retained with explicit source; persistent5558 clone four-Hive cold restart PASS; fresh phone/signed subgates separate. |
| D04 | E PASS real restore/reboot/re-export exact typed semantics on 26bd; synthetic full reboot a3 also byte-exact; D/R HOLD | Prior recovery/identity evidence retained with explicit source; persistent5558 clone four-Hive cold restart PASS; fresh phone/signed subgates separate. |
| D05 | A PASS; E PASS same-name 2/1/2 at 2f61715e; E PASS 251f5c43 malformed/truncated/tampered rejection, cancellation, rollback and five staged production recovery cases in scratch directories; D/R HOLD | Prior recovery/identity evidence retained with explicit source; persistent5558 clone four-Hive cold restart PASS; fresh phone/signed subgates separate. |
| P01 | A PASS queue/shuffle fixtures; E PASS controlled local queue; complete provider listening FAIL/BLOCKED; D/R HOLD | Component/pipeline narrowed:214s saved/native restart and186s redirected full host save PASS; full normal-UI source and broader provider/physical subgates remain separate. Known251/403 preserved. |
| P02 | A PASS source/order/start-index fixtures; E PASS controlled playlist, offline/recents local entries; sustained provider playback FAIL/BLOCKED; D/R HOLD | Component/pipeline narrowed:214s saved/native restart and186s redirected full host save PASS; full normal-UI source and broader provider/physical subgates remain separate. Known251/403 preserved. |
| P03 | A PASS error ownership, zero/duration, paused snapshot, rapid-input fixtures; E PASS 49d controls, bc error, 5da paused duration; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| P04 | A PASS manual-entry shuffle/restoration; E PASS 9f92 current retained, natural order restored and Play Next insertion/replacement; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| P05 | A PASS stop/stale/three-failure/repeat; E PASS 49d healthy Replay and repeat one/all, natural tail pause; provider terminal callback remains BLOCKED; D/R HOLD | Component/pipeline narrowed:214s saved/native restart and186s redirected full host save PASS; full normal-UI source and broader provider/physical subgates remain separate. Known251/403 preserved. |
| P06 | E PASS owned 5721 screen-off queue completion and native media pause/hold/resume; audibility/focus/accessories unverified; D BLOCKED selected phone/output accessories unavailable; R HOLD | Component/pipeline narrowed:214s saved/native restart and186s redirected full host save PASS; full normal-UI source and broader provider/physical subgates remain separate. Known251/403 preserved. |
| I03 | A PASS reopenable No match/errors after routing in durable fixture; E PASS completed/empty review access without restart matching; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| I04 | A PASS actual review widgets/swipes/prefetch; E PASS review entry/empty return and prior decision persistence; complete online preview BLOCKED; D/R HOLD | Earlier UI/decision evidence retained; real12s preview PASS; current normal-main search-to-play integration OPEN, not full-catalog proof. |
| I05 | A PASS manual unrestricted candidates/warnings/scoring/exact choice; E persisted selected public alternate; complete preview BLOCKED; D/R HOLD | Earlier UI/decision evidence retained; real12s preview PASS; current normal-main search-to-play integration OPEN, not full-catalog proof. |
| I06 | A PASS exact ID/oEmbed/denial/timeout/no raw-stream persistence; E selected exact URL decision retained; complete preview BLOCKED; D/R HOLD | Earlier UI/decision evidence retained; real12s preview PASS; current normal-main search-to-play integration OPEN, not full-catalog proof. |
| I07 | A PASS selected alternate -> route/audit -> Hive reopen; E PASS exact selected IDs and audit survive a3 full reboot; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| I08 | A PASS explicit exclusion/source/audit/backup/reopen; E PASS all four source rows and excluded outcome survive reboot; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| I09 | A PASS all/first-N to liked/new/existing with source order; E PASS a3 first-one amount retained after confirm/refresh; earlier 5da expansion FAIL repaired; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| I10 | A PASS empty/stale target rejection and reopened idempotence; E PASS a3 repeat still 0 new/1 existing and no duplicate library change; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| I11 | A PASS 22 targeted checks, 323 aggregate and exact CI a0e252d6; E PASS e705fb2b four modes/delta/order/restart, plus a0e252d6 legacy stale/pending rejection and reopen with normal/earlier scratch files exact; D/R HOLD | All four selectors and legacy/stale/pending/native restart evidence retained; not an unapproved/missing feature. |
| L01 | A PASS folder filtering/liked models; E PASS generated folder/member/pin plus original membership across full reboot; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| L02 | A PASS nested-navigation Cancel/Delete and child retention/reopen; E PASS create/rename/move/pin/unpin/validation/delete Cancel; E PASS repaired folder Delete returns to Library on exact 58f1edbb APK; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| L03 | A PASS unavailable/empty widget regressions; E PASS generated empty-folder entry/Back; provider unavailable state represented by local source-error fixture; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| L04 | E PASS local share-link copy, no external send, CSV SAF entry/Cancel; CODE compact link expansion uses metadata service; live recipient delivery excluded; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| O02 | A PASS offline placeholder/folder filtering; E PASS 5da three/four-tab toggle and local-file controls; E PASS 769d60f4 downloaded-only Library, Offline Songs entry/3-song Play/pause, online restoration and full reboot; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| T04 | A PASS actual About identity widget; E PASS About debug version/upstream attribution, Licenses/Back, translation/sponsor entries inspected without sends/purchases; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| U01 | A PASS 14 updater rejection checks incl. old/debug identity, checksum, interrupted body and inspection failure; E PASS disallowed manifest rejection/dismiss with no install; D/R HOLD | Automated current suite passes; prior named native clauses retained, not relabelled as full current runtime/device/signing proof. |
| U02 | A PASS production workflow/channel/invalid-artifact boundaries; CI unsigned builds only; R BLOCKED exact signed in-place rehearsal and full product gates | Signed/default-tip in-place or phone gate OPEN; no publication/installation inferred. |
| U03 | D/R BLOCKED phone unavailable and signed/product release gates; no live install/restore/uninstall/clear-data | Signed/default-tip in-place or phone gate OPEN; no publication/installation inferred. |
| V01 | A Windows strict FAIL; exact Linux 70313ae8 all 40 strict PASS, only named deliberate images reviewed; E real-artwork/long-label evidence and normal Home/Library at 70313ae8; D/R HOLD | 40 strict Linux visuals PASS; Windows strict FAIL16+24, actuals unchanged. Current normal-main Home/Library/Settings/About/scroll/Back PASS on frozenf314b3aa; baseline rollback and full cold-restart exact APK/four Hives/private writable modes PASS. |
| V02 | A PASS actual review, error/text-scale and slider widgets; E PASS keyboard, content scroll, safe Back, paused mini-player; folder-delete root pop FAIL repaired with A proof and native 58f1edbb Library return PASS; D/R HOLD | 40 strict Linux visuals PASS; Windows strict FAIL16+24, actuals unchanged. Current normal-main Home/Library/Settings/About/scroll/Back PASS on frozenf314b3aa; baseline rollback and full cold-restart exact APK/four Hives/private writable modes PASS. |

## Genuine remaining order

1. Current normal-main Home/Library/Settings/About, scroll/Back, exact baseline rollback and full cold restart on5558 PASS. APK SHA256c891bba6dc443aafcdc095756b68e1532a4bc74e343b0f278a977566b6e27bdf; sourcef314b3aa. This closes navigation, not every provider/playback/physical subgate.
2. Production review12s cutoff, pause/resume, Later cancellation and repeated decisions PASS on frozenf314b3aa; independent Hive audit after UI and full cold restart PASS. SourceURI remains within approved recording2. This does not prove physical output or all-catalog availability.
3. Search-result-to-play/current-source/unsupported feedback using bounded consented resources. Transport302→HTTPS Googlevideo→206 now full host save verified;403/401/cross-provider remain terminal, not exclusions.
4. Exact-source CI and immutable source/APK/signer linkage after coherent push.
5. Sign-only workflow execution and signed disposable in-place data/restart rehearsal. GitHub supports candidate --ref dispatch; rehearsal code pins the sole candidate branch/dispatch SHA/current tip. Publication retains default-tip gates. Sealed sign-only38434666060 PASS for018bb5c7; Publish skipped. Baseline data preparation and signed in-place/restart rehearsal remain UNVERIFIED.
6. Fresh authorized phone recovery/update plus physical output/focus/accessories as final mile.

No recording set proves all catalog availability. No credentials, identity switching, denied251 replay, reset/reimport or schema migration is authorized by this bridge. D-017 baseline remains YouTube/saved audio plus Spotify metadata; D-018 ad-free in-app/no-Premium Spotify remains a separate nonblocking stretch.

## Normal-main harness recovery,2026-10-13

The first current normal-main run showed HiveError/Box not found, then rollback copy failed. All four Android clone Hive files had mode0444 inherited from immutable host copies. Owned5558 recovery reinstall without uninstall/clear restores the exact b1dc64fa baseline APK and four Hive hashes, with private writable0600. Host originals and original5556 AVD remain untouched. That recovery is not a normal-main UI pass; subsequent normal-main navigation and cold restart PASS. The original failure is retained as harness evidence, not relabelled a product pass.

Measured normal-main receipts: `host-provider-diagnostic/normal-ui-f314b3aa-attempt5/ui-result.json`, `normal-restored.json`, `network-restored.json`, `avd-restart-proof.json`. Exact clone recovery receipt: `normal-clone-recovery-proof.json`. No original AVD or live phone operation; no additional provider request.
