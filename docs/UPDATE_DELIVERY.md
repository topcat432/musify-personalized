# Update delivery plan

## Previous failure

GitHub Actions produced debug APKs on fresh hosted runners. Those APKs were not
guaranteed to share one persistent debug signing certificate, so Android could
reject a new APK as an update to an installed build.

## Permanent approach

- Use one permanent application ID for Musify Personalized.
- Generate one long-lived private Android signing keystore.
- Store the keystore and credentials only in secure CI secrets and offline backup storage.
- Build user-facing APKs as signed release/update builds, not ephemeral debug-signed builds.
- Increment the version code for every distributed build.
- Verify every release by installing it directly over the previous release without uninstalling.
- Keep normal full APK updates available even if a future Dart code-push system is added.

## Current reset-and-reimport path

The completed debug dataset remains installed as a fallback. It will not be
updated, uninstalled, cleared, exported through the old broken backup path, or
used as the destination for the corrected build.

The corrected APK must update the existing production package in place. The
original Spotify CSV is then imported again into production, automatic strong
matches are retained, and only uncertain/unmatched tracks require manual work.
The debug fallback may be removed only after production survives restart and a
new verified `.musifybackup` passes independent restore testing.
