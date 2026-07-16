# Musify Personalized preview channel

`preview/latest-debug` is Daniel's isolated bleeding-edge preview branch.

## Purpose

- Build the newest deliberately selected committed app state, including known
  bugs or unfinished review work.
- Keep preview installs separate from both production and the preserved debug
  fallback.
- Provide a repeatably signed APK that Android can update in place across
  future preview builds.

## Android identity

- Package: `com.topcat432.musifypersonalized.preview`
- Label: `Musify Personalized PREVIEW`
- Storage: separate from production and debug
- Signing: the existing long-lived Musify signing key, restored only inside the
  isolated signing step from GitHub Actions secrets

The preview package is intentionally a third app. Never uninstall or clear the
production app or the debug fallback to install it.

## Update model

Every push to `preview/latest-debug` runs the preview workflow and uploads a
signed APK artifact. The branch does not update itself automatically: advance
it only to a deliberately selected current commit while preserving the preview
flavor and workflow.

The artifact is a development preview, not a production release. It may contain
known bugs, incomplete review work, or temporary test infrastructure. The only
approved production release path remains `.github/workflows/signed-release.yml`.
