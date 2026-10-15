# Required Windows storage workflow

Adopts the owner's Windows Project Storage Standard, Library version1,
effective2026-10-13. Authoritative local copy on this host:
C:/Users/james/Documents/Codex/2026-10-12/task/storage-standard.txt.
Read this at task start/handoff/retirement alongside RELEASE_STATE/CONTRIBUTING.

## Controls actually used

Use tool/dev.ps1 test/visual/verify/build rather than unguarded native commands.
The entrypoint requires V: and the existing Gradle lookup, hashes its owned
dev-workload.ps1, and invokes task-storage-session.ps1 with that exact hash.
It declares these conservative planning allowances before any pub/test/build:

| Work | Expected C: writes | Expected V: writes | Additional host commit |
|---|---:|---:|---:|
| test/visual/verify | 2GiB | 5GiB | 3GiB |
| unsigned build | 20GiB | 6GiB | 32GiB |

The build forecast preserves the configured8GiB Gradle heap,4GiB metaspace and
512MiB code cache. It conservatively allows a similarly sized compiler/worker JVM
plus7GiB host/native overhead; this is a planning envelope, not proof those limits
are reached simultaneously. C: includes4GiB staging plus up to16GiB potential
heap dumps because HeapDumpOnOutOfMemoryError is configured. No heap/metaspace
limit or80% admission threshold is lowered to fit. Refuse the build when this
envelope is not admitted; qualify actual peaks before revising the allowance.

The existing session checks C: reserve10GiB plus declared C: writes, V: reserve
20GiB plus declared V: writes, and projected commit below80%. It sets only that
session's TEMP/TMP/npm/pip cache paths on V:, writes a small session manifest and
restores the prior environment afterward. Setup alone only discovers/configures
existing tools; it does not authorize or run a workload. No automatic cleanup.

Current helper: C:/Users/james/Documents/Codex/2026-10-12/task/task-storage-session.ps1.
On another Windows host supply its verified mapped helper via StorageSessionScript;
do not replace it with a no-op or bypass resource checks. Linux CI retains its
pinned reproducible workflow and separate runner resources.

For a new diagnostic/harness, pin its source/hash and invoke the session helper
with realistic C:/V: writes and commit, including staging/downloads/extraction/
cache misses/output/snapshot costs. Declare a larger allowance when needed;
defaults are forecasts, not capacity proof. Qualify cross-volume operations with
owned fixtures; if atomic operations require C:, use KeepTempOnC and budget their
full C: cost. Never relocate protected source/data/originals to force success.

## Rehearsal lifecycle and durable paths

Emulator harnesses additionally run through
C:/Users/james/Documents/Codex/2026-10-10/task/musify-source-comparison/emulator-rehearsal/Invoke-OwnedRehearsal.ps1.
It enforces admission, an exclusive owned lease, identity and graceful finally
shutdown. Preserve the default26GiB emulator commit allowance until measured
lower-memory qualification supports less; guest RAM flags are not a host cap.
The reviewed tool/Invoke-OwnedRehearsal.ps1 implementation now owns launch and
boot as well as shutdown; the external invocation path delegates to that code.
Pass an explicit owned callback and ApprovedHarnessSha256. The callback contains
acceptance operations only, never an emulator launcher. CheckOnly launches
nothing. Offline lifecycle contracts cover callback/boot failure, pre-existing
process and foreign-AVD refusal, hash/admission rejection and successful cleanup.
Abrupt supervisor termination can leave an orphan, which the wrapper refuses to
adopt. Stop only verified owned work; never kill unrelated workloads or remove
SDK locks. A passing mock lifecycle is not a qualified native launch.

The Gradle lookup C:/Users/james/.gradle/caches and existing owned AVD path have
verified V: junction destinations. Keep V: available; do not change global
GRADLE_USER_HOME/TEMP, SDK locations, paging, hibernation, security or other agents.
V: is striped working storage, not an established independent recovery backup.

## Owned Windows command lifetime

The October13 TSV/JSON acceptance harnesses launched Flutter directly; their
five surviving tester identities matched the exact checkout and guarded storage
sessions, with absent parents. Their parent exit causes were not retained.
They predate the bounded logger, whose Windows cleanup also only terminated an
immediate live leader. Normal dev commands had no descendant lifetime owner.
The original harnesses/manifests remain lineage evidence, not reusable launchers.

Normal dev/setup commands and bounded logging now share an owned launcher.
On Windows it creates an unnamed, non-inheritable kill-on-close Job, starts only
its new command suspended, assigns that exact process handle, then resumes its
verified initial thread. Assignment/identity failure refuses before user code.
It neither enumerates processes to adopt nor signals the caller/shared tools.
The caller's held process handle is watched for exit; runner death closes the
Job through the OS. Cleanup closes the Job even after a leader already exited,
so pipe-holding or redirected descendants do not survive a successful/failed
command. A separately launched sentinel is part of the native acceptance proof.
The mechanism follows [Microsoft's Job lifecycle](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).

The console entrypoint writes no application-managed log; saved output still
requires the enforcing bounded logger. Its child deadlines are60s for version
queries,600s for checks and1800s for unsigned builds. Storage admission, declared
writes/commit, V: lookup and outer harness hashing are unchanged. Python must
already exist; no tool installation/global environment change is performed.
Ad-hoc future harnesses must likewise wrap their new commands (or whole harness)
with the owned entrypoint inside the admitted storage session. Do not rerun the
historical direct-launch scripts as current guarded commands.

This containment helper does not replace the emulator lease and verified graceful
finally shutdown, and must not be used to bypass native rehearsal controls.
Linux process-group behavior remains covered separately. Mocks or Linux skips do
not qualify the native Job implementation. The owner approved the following
narrow hosted-runner exception on2026-10-15 at10:12 UTC; routine reruns within this
scope need no repeated question. Native qualification remains evidence-dependent.

Only debug.yml's disposable windows-2022 Windows owned-command lifecycle job may
substitute its inline, runner-specific admission for the home C:/V: session
helper. Before checkout it resolves actual C:, workspace, runner TEMP and process
TEMP volumes; declares2GiB writes per distinct root together for action/source
staging, fixtures, Python cache misses, logs and uploads/outputs; aggregates aliases
sharing a volume; and retains10GiB free per involved volume after those writes.
It declares1GiB additional commit, requires projected commit strictly below80%,
and keeps2GiB available physical memory after that forecast. An absent/unknown
volume or unavailable memory limit refuses the job. Receipts record measurements,
allowances, source/workflow SHA and the eight-case result with source-file hashes.

The job uses only existing Python, has an8-minute job limit and120-second owned
command deadline, enforces a10MiB single-generation log and16KiB receipts, requires
all eight Windows cases to execute/pass without skips, and retains evidence7days.
No SDK/dependency installation, snapshots, paid service, credentials, persistent
access, emulator, phone, signing, publication or security change is authorized by
this exception. Home-PC session hashing, C:/V: reserves, admission thresholds,
existing helper, emulator lease and graceful-finally controls remain mandatory.

## Logs and canonical evidence

Any owned logger persisting debug output must implement10MiB per file and no
more than three generations per run, then stop its verified owned writer on
overflow/error loop. CODEX_TASK_LOG_* are hints only. Do not use unbounded Tee/
redirection for long runs. Preserve failure receipts; this policy does not permit
deleting unique logs, source, histories, chats or recovery state. Console-only
dev checks add no application-managed persistent log; callers that save stdout
must use an enforcing logger. This is not a machine-wide disk quota/watchdog.

Retain one canonical source/evidence set, latest necessary review package, hashes/
manifest and an index to earlier lineage. Avoid repeated full APK/media/history
copies. At handoff classify active, recovery/lineage, verified duplicate,
rebuildable, archive or unresolved items. Older than30days prompts review, not
deletion. Verify SHA256 and accessible good copy/restoration map before any
approved relocation. Permanent purge requires consolidated exact-path/size/
redundancy approval; never auto-purge protected originals or sole recovery copies.

The approved persistent acceptance target is musify_saved_acceptance_api35,
explicit emulator-5558, under V:/Storage-Recovery-20261013/ProjectWork/
musify-saved-acceptance/avds. Use Target saved; the wrapper pins that serial/name
and persistent userdata-qemu.img. BootstrapSaved is allowed only for that new
target, and its callback must reject an already installed baseline. ColdBootSaved
bypasses snapshot loading only on this persistent target to prove disk durability.
Those switches are refused for original/emulator-5556; preserve its configuration.
The shared owned lease prevents concurrent guarded Musify rehearsal sessions.

Creation/native sessions declared2GiB C: writes,20GiB V: writes and native26GiB
commit; creation alone used3GiB commit. Actual new AVD file lengths totaled
4,952,319,691bytes after three sessions. Existing Android35 Google APIs x86_64
image was reused without download or global SDK/config/security changes. Its
baseline is explicitly a clone of verified host APK/four-Hive copies, not proof
that the original AVD's package/data state survived restart. All three guarded
sessions ended with verified graceful shutdown.12 offline lifecycle contracts
cover original/saved target separation in addition to failure cleanup.
## Isolated rendering diagnostic profile, 2026-10-15

An explicitly authorized isolated comparison uses musify_isolated_acceptance_api35,
serial emulator-5560, under V:/Storage-Recovery-20261013/ProjectWork/
musify-isolated-acceptance/avds. Target isolated requires ColdBootSaved and retains
the same lease,26GiB host forecast,80% threshold and graceful finally shutdown.
Original/saved profiles and their5556/5558 paths/renderer remain unchanged.

The comparison uses the same API35 image, four guest CPUs and configured2G RAM,
with720x1280/density320 and the installed emulator's supported swiftshader mode.
Current userdata/encryption overlays are flattened offline into separate self-contained
QCOW2 images; no snapshots/cache/locks are copied, and original hashes must match
before/after creation. It is working storage, not an independent backup. No new
APK installation, phone operation, signing, schema migration or guest permission
change is implied. The profile is unqualified until exact package/hash/UID,
normal-data identity, system-control responsiveness and cold lifecycle are proven.
Record results against the actual target/profile, never against original5558.
