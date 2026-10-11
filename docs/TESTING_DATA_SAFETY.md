# Android data acceptance checklist

Operational export/restore steps are in DATA_RECOVERY_RUNBOOK.md. Current
targets and evidence are in RELEASE_STATE.md. This checklist replaces old
reset/reimport assumptions; do not treat historical counts as today's data.

- Verify explicit target serial, package, version, APK hash and signer.
- Keep daily app installed and its library unchanged during backup rehearsal.
- Save and independently reopen the actual app-exported .musifybackup.
- Verify schema, both Hive payloads, lengths/checksums and key/type inventories.
- Compare recording/source identities, order, favorites, playlist memberships,
  import sessions/outcomes, permanent exclusions, settings and current counts.
- Restore only on a designated disposable Android target; prove reopen and
  restart persistence, then re-export and compare semantic values.
- Record coverage: user/settings are backed up; downloaded audio/cache are not.
- For a later signed candidate: exact source commit, retained package, one pinned
  signer, v2/v3 true, non-debuggable, increasing code and matching manifest/hash.
- Rehearse in-place update on the restored disposable app before live update.
- Live-phone installation needs separate approval, then launch/restart/data,
  healthy/failed/offline playback and background/queue/control acceptance.
- Never uninstall/clear, remove a fallback, rerun completed matching or discard
  unresolved rows to make a check succeed.
- Do not call a picker result, filename, toast, green test or compile data safety.
