# Musify Personalized data-recovery runbook

## Incident state

The debug and production apps are separate Android packages with separate
private storage:

- debug: `com.topcat432.musifypersonalized.debug`
- production: `com.topcat432.musifypersonalized`

An APK `.sha256` file verifies an APK download. An Android signing key proves
the publisher of an APK. Neither file contains Favorites, imported tracks,
matching results, playlists, history, or settings.

The matching dataset is expected in the installed debug package's Hive files,
primarily `app_flutter/user.hive`. Do not uninstall the debug package or clear
its storage until recovery is complete and independently verified.

## Required recovery evidence

Before extraction, open the debug app and record the displayed counts. The
known completed run should report:

- imported tracks: 2,643
- match results: 2,643
- strong: 2,128
- review: 353
- unmatched: 162

Do not run Rescue, Review Sprint, restart matching, restore data, or replace the
CSV before extraction.

## Extraction path A: existing legacy backup

If the installed debug app can create both files below, preserve the originals:

- `user.hive`
- `settings.hive`

The old success message is not evidence. Recovery is valid only when the new
legacy importer opens both Hive files and reports the expected 2,643 imported
tracks and 2,643 match results.

## Extraction path B: Android Debug Bridge

Use this when the installed debug app cannot create both legacy files. It does
not require the lost debug signing key, but the installed package must still be
debuggable.

Run these commands from Windows **Command Prompt**, not Windows PowerShell.
PowerShell 5 can corrupt binary output when `>` is used.

```bat
adb devices
adb shell run-as com.topcat432.musifypersonalized.debug ls -la app_flutter
adb exec-out run-as com.topcat432.musifypersonalized.debug cat app_flutter/user.hive > user.hive
adb exec-out run-as com.topcat432.musifypersonalized.debug cat app_flutter/settings.hive > settings.hive
dir user.hive settings.hive
certutil -hashfile user.hive SHA256
certutil -hashfile settings.hive SHA256
```

Stop if `run-as` reports that the package is unknown or not debuggable. Do not
uninstall or reinstall in an attempt to repair that error.

## Import into the permanent app

1. Install only a permanently signed production APK whose package is
   `com.topcat432.musifypersonalized` and whose version code is higher than the
   installed production version.
2. Open **Settings → Recover legacy debug data**.
3. Select exactly `user.hive` and `settings.hive`.
4. Confirm that the inspection screen reports 2,643 imported tracks and 2,643
   match results before continuing.
5. Restore. The app must create a verified rollback copy, replace both boxes,
   reopen them, and repeat the count checks before showing success.
6. Close and reopen the permanent app. Verify the counts again.
7. Create one new `.musifybackup` file. Verify the success message contains the
   saved path and expected counts.
8. Test that backup on a clean test installation before removing the debug app.

The debug app may be removed only after steps 1–8 pass and the original legacy
files plus the verified `.musifybackup` file exist in separate locations.

## Hard stop conditions

Stop recovery without modifying live data if any of these occur:

- either Hive file is missing or empty;
- the importer accepts a random or renamed file;
- imported-track and match-result counts differ;
- the expected 2,643 counts are absent;
- a checksum fails;
- either staged Hive box cannot open;
- rollback validation fails;
- the post-restore counts differ from the pre-restore inspection;
- the production APK has the debug package, debug label, or wrong signing
  identity.
