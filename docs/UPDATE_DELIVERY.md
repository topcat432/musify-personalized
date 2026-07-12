# Update delivery plan

## Current failure

GitHub Actions currently produces debug APKs on fresh hosted runners. Those APKs are not guaranteed to share one persistent debug signing certificate, so Android may reject a new APK as an update to the installed build.

## Permanent approach

- Use one permanent application ID for Musify Personalized.
- Generate one long-lived private Android signing keystore.
- Store the keystore and credentials only in secure CI secrets and offline backup storage.
- Build user-facing APKs as signed release/update builds, not ephemeral debug-signed builds.
- Increment the version code for every distributed build.
- Verify every release by installing it directly over the previous release without uninstalling.
- Keep normal full APK updates available even if a future Dart code-push system is added.

## Migration

Because already-installed debug builds may have unknown or inconsistent signing certificates, one final uninstall/install migration may be unavoidable. Before that migration, export `user.hive` and `settings.hive` using the app's backup tool, then restore them into the permanently signed build.
