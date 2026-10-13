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