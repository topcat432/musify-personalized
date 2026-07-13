# Phone test data safety

Debug and production are separate Android packages with separate private data.
Uninstalling either package deletes only that package's data, but that loss is
permanent unless a verified backup exists.

## Current incident rule

Keep the installed debug app and its 2,643-track dataset untouched while the
corrected production app is installed and repopulated from the original CSV.
Do not uninstall either app, clear storage, or use an unsigned or ephemeral
debug APK.

## Corrected production validation

1. Install only the permanently signed APK for package
   `com.topcat432.musifypersonalized` over the existing production app.
2. Keep the debug package installed as an untouched fallback.
3. Import the original Spotify CSV into production and complete matching.
4. Confirm the expected total before finalizing.
5. Restart production and confirm the imported and matched totals persist.
6. Open **Settings → Tools → Back up user data**.
7. Save the proposed `.musifybackup` filename without changing its extension.
8. Accept success only when Musify reopens the saved file, proves it is
   byte-for-byte identical to the validated bundle, and shows the expected
   semantic counts in a **Backup verified** dialog.
9. Reject random files, renamed files, missing payloads, changed bytes, invalid
   checksums, and mismatched counts.
10. Prove restore and restart persistence on a disposable test installation
    before removing the debug fallback.

The one `.musifybackup` file contains both required Hive databases, their
checksums, key/type inventories, application identity, and semantic counts.
Downloads and cache data are not included.
