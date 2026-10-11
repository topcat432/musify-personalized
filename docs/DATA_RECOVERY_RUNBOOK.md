# Musify data export and disposable restore

This procedure preserves the daily Samsung app. It replaces obsolete
debug-to-separate-production reset/reimport instructions; those remain in Git
history, not standing recovery instructions.

## Targets and data boundary

Verify the selected phone serial and actual package first:
Selected Samsung serial recorded in private task evidence; retained com.topcat432.musifypersonalized.preview.
Always use explicit adb -s SERIAL. Do not operate on the Retroid or another
project's emulator. A disconnected/locked phone needs reconnect/unlock; do not
enable debugging, alter security or restart a shared ADB server to force access.

The app's schema-1 .musifybackup contains user.hive and settings.hive, checksums,
key/type inventories and semantic counts. Downloads, cache, userNoBackup and
audio files are not included. Copy only the app-exported document; private
run-as extraction is unavailable for the installed non-debuggable release.
Never commit/upload personal data or screenshots without explicit sharing approval.

## Export without restoring over the live library

1. Within authorized data-export scope, launch the existing daily app and record
   current UI-visible Liked Songs/playlists/import/review/exclusion/settings
   state. Do not substitute old 2,643/2,454 counts for current measurements.
2. Use Settings -> Data safety -> Create verified backup -> Choose save location.
   Save locally through Android's document picker, preserving .musifybackup.
   Avoid cloud destinations. Export flushes/copies boxes; it does not replace
   the library. Do not match again, route songs or restore on the phone.
3. Preserve the exported original, copy the document to task-local private
   evidence storage, and record SHA-256, size, time and source-device identity.
4. Reopen that actual saved document using the app-supported backup inspector
   on the disposable target. Verify lengths/checksums, schema, both Hive boxes,
   semantic summary and key/type inventories. Android's export success returns
   after picker write and does NOT reopen the saved document; its toast alone
   is insufficient. Older valid exports may label preview as production; that
   known origin is accepted without changing schema or payload semantics.
5. Stop on missing, empty, corrupt, mismatched or unexpected data. Keep the
   phone unchanged and originals available; do not repair by reset/reimport.

## Independent Android restore/restart

Use only a designated fresh task-owned AVD or approved disposable device.
DESKTOP-OPE9IIV has official C:\devtools\android-sdk tooling and an isolated
Android 35 x86_64 AVD named musify_rehearsal_api35 (emulator-5556 during this
task). AVD/user-data files live outside the repository. Verify the AVD name
with adb -s SERIAL emu avd name and verify package inventory before install.
Never wipe or borrow an existing emulator's dataset.

1. Install the preserved signed baseline APK on the fresh target; record its
   package/version/hash/signer. This changes only disposable app storage.
2. Copy the exported .musifybackup into that emulator's local Documents/Download
   area. Use Settings -> Data safety -> Restore from backup and choose it.
3. Review Validated backup and its current counts before Restore verified data.
   Restore replaces only the disposable target's user/settings pair and uses
   staged validation/rollback. Never click restore on the live Samsung.
4. Verify recording/source identities, order, favorites, playlist memberships,
   import outcomes/sessions, exclusions and settings; compare with the source
   export/UI baseline, rather than counts alone.
5. Close/reopen and restart the disposable Android target; verify again.
   Re-export there, reopen it, and compare keyed semantic values/inventories
   against the original. Bundle timestamps/provenance and Hive file packing can
   differ; those differences do not justify ignoring data-value changes.
6. After separate signing approval, rehearse in-place update with the exact
   signed candidate on this restored disposable app and repeat acceptance.
   Ephemeral debug/unsigned builds cannot prove installed-signer continuity.

An emulator restore demonstrates Android recovery, not live-phone update,
background playback or network-source health. Those remain separately gated.
No fallback/old dataset may be removed to force success. Keep the original
backup and its independently verified copy.

## Reproducible synthetic/semantic tool

The manual Flutter support tool never accesses devices or live Hive paths:

```bash
flutter test test/support/backup_rehearsal.dart
```

With no input it creates only synthetic data in ignored build/backup-rehearsal,
with 5 import outcomes (2 matched, 1 review, 1 unmatched, 1 excluded), two liked
recordings and one playlist with deliberately reversed order. Its legacy origin
metadata is explicitly synthetic to exercise the installed APK's old contract.
It is not the owner's backup and cannot close the real-data gate.

Within explicitly approved export-inspection scope, set MUSIFY_BACKUP_FILE to
the saved local .musifybackup; optional MUSIFY_BACKUP_COMPARE names a re-export.
Run the same tool to validate schema/checksums/inventories and compare typed,
keyed semantic hashes (map order normalized, list order preserved). It prints
only summary counts and hashes, not song values. Set variables only for that
process and keep personal documents outside Git/Library. Successful comparison
is still not device restart or playback proof.
