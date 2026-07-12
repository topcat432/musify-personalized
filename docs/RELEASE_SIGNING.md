# Stable Android signing requirement

The GitHub Actions debug APK is currently unsuitable for seamless on-device updates because each hosted runner may create a different Android debug keystore. Android only accepts an APK as an update when its package name and signing certificate match the installed app.

Before the next user-facing APK release:

1. Choose the permanent Musify Personalized application ID.
2. Generate one long-lived private Android signing keystore.
3. Store the keystore and passwords outside the public repository, using GitHub Actions encrypted secrets for CI builds.
4. Configure Gradle and CI to sign every user-facing APK with that same key.
5. Increment the Android version code for every distributed build.
6. Verify update installation over the previous signed build without uninstalling.
7. Keep the signing key backed up securely; losing it prevents future seamless updates.

Do not commit private signing keys or passwords to this public repository.

## Temporary data-preservation rule

Until stable signing is configured, users should back up the `user` and `settings` Hive boxes from **Settings → Tools → Back up user data** before uninstalling any test build. The backup includes imported Spotify records and matching progress because those records live in the `user` box.
