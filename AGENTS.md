# Musify Personalized agent instructions

Read docs/RELEASE_STATE.md for the living repository/device map, then
CONTRIBUTING.md for reproducible development and acceptance. Actual workflows
override summaries. MASTER_AGENT_HANDOVER.md is an index, not current proof.

## Work and authorization

Inspect status, remotes, current GitHub heads, PRs and checks. Preserve unrelated
work; never reset a dirty checkout or force-push over it. Until approved
integration, PR #23 on agent/local-stable-consolidation is the sole active
candidate targeting protected master. Continue it only when assigned.
After integration, use fresh origin/master and one agent/{task} branch/PR.
Do not revive retired PRs. Use one writer per file; spawn agents only if requested.
Commit/push/cleanup needs task authorization. Existing explicit approval remains
valid within scope; do not repeatedly ask for the same action.

## Product and data

Read PRODUCT_VISION.md, IMPORT_AND_MATCHING_ROADMAP.md and DECISIONS.md under
docs for product changes; read VISUAL_SYSTEM.md and reuse shared UI tokens.

- A song is a canonical recording identity, not just a video URL or ID.
- Preserve selected sources, source order, memberships, existing library,
  import sessions and completed work.
- Unmatched, review, error, accepted, routed and permanently excluded are
  distinct states; routing is explicit, audited and idempotent.
- File import remains usable without Premium or mandatory cloud access.
- Durable changes need migration, old/partial-state tests, rollback and restart
  coverage. A UI/workflow task does not authorize schema changes.
- Backup success needs saved-file reopen, checksums, semantic inventories,
  independent restore and restart proof. A picker/toast is insufficient.

## Verification and boundaries

Use CONTRIBUTING.md. tool/dev.ps1 configures only the calling Windows process
from existing tools. Run meaningful targeted tests, aggregate analysis/tests,
both strict visual suites and required Linux CI. Never use --update-goldens as
a test, weaken comparisons or declare failures a pass. Inspect before/after/diff
images; update only named, deliberately reviewed images.
Never commit personal exports, .musifybackup, device Hive files, histories,
private diagnostics, keys, passwords, tokens or private client IDs. Use synthetic
fixtures. Public fingerprints/secret names may be documented, never values.
Never read signing secrets locally, disable security, change global Git trust,
delete shared SDK locks or interrupt another workload. Tool installation needs
authorization; new legal terms require approval.

Unless separately approved for the exact action/current state, stop before
merge/auto-merge, signing/publication, live-phone installation, repository settings,
uninstall, clear-data, migration, live restore or reimport. Approval to code,
push, run CI, retire stale branches or rehearse on a disposable emulator does
not approve production work.
Retained package: com.topcat432.musifypersonalized.preview. Sole user-facing
path: .github/workflows/signed-release.yml, which both signs and publishes.
Preserve installed signer, monotonic version, exact default-tip gate, v2/v3 and
source/APK hashes. Never uninstall/clear to force an update. Read
docs/RELEASE_SIGNING.md and docs/UPDATE_DELIVERY.md first.
For data/device work read DATA_RECOVERY_RUNBOOK.md and TESTING_DATA_SAFETY.md
under docs. Always name the approved ADB serial, never the first connected
device. Restore only on a verified disposable target absent live-restore approval.

## Handoff

Report exact SHA, PR/check URLs, changes/data implications, checks/results,
recovery evidence and blockers. Distinguish merged, CI-verified, emulator-verified
and phone-verified. Compilation/package/signature proof is not data safety or
exact installed-source proof. Update the dated living map from evidence.
