# Stable Android signing requirement

GitHub Actions debug APKs are unsuitable for user-facing updates because hosted
runners may create different debug certificates. Android accepts an update only
when its package name and signing certificate match the installed app.

Before the next user-facing APK release:

1. Choose the permanent Musify Personalized application ID.
2. Generate one long-lived private Android signing keystore.
3. Store the keystore and passwords outside the public repository, using GitHub Actions encrypted secrets for CI builds.
4. Configure Gradle and CI to sign every user-facing APK with that same key.
5. Increment the Android version code for every distributed build.
6. Verify update installation over the previous signed build without uninstalling.
7. Keep the signing key backed up securely; losing it prevents future seamless updates.

Do not commit private signing keys or passwords to this public repository.

## Current release gate

The branch contains permanent release-signing configuration, but configuration
alone is not proof. Before distributing an APK:

1. build through `.github/workflows/signed-release.yml` using the encrypted
   long-lived key;
2. require v2 and v3 signature verification;
3. require production package and label verification;
4. install over the existing production app without uninstalling;
5. confirm the existing production data remains readable;
6. record the signer certificate fingerprint for future releases.

The installed debug app remains untouched throughout this proof.
