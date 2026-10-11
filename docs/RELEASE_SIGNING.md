# Stable Android signing requirement

## Installed identity retained — local candidate, 2026-10-11

The authorized consolidation keeps `com.topcat432.musifypersonalized.preview`.
The historical suffix is permanent Android identity; the stable launcher label
is `Musify Personalized`. Changing the package would create a separate app and
would not retain the current app's private data.

Read-only Samsung evidence established versionCode `300000001`, versionName
`preview.0.1.1`, and public signer certificate SHA-256
`58c5316466da7a426c4411beb33b3b594ef58875bcfa31e092a5afce8cf9999e`.
The installed APK hash is
`2dd3360db7f5376fbe6768709554c2ebc8991a1588d87750d474ffe55e3ab1ea`.
This establishes installed identity, not exact source attribution or data safety.

Do not generate or substitute another signing key. Preserve the existing alias
and encrypted CI secret configuration. This local candidate neither reads the
private key nor signs an APK. The public signer fingerprint is pinned in the
release verification gate.

## Distribution gates

The sole user-facing path remains `.github/workflows/signed-release.yml`, named
`Build and publish signed production APK`. Its operational name is historical;
its package checks now target the retained installed identity. Distribution
requires separately approved signing/publication at the exact default-branch
commit, passing aggregate and visual checks, a versionCode above `300000001`
and every prior release of the retained package, the pinned signer, v2/v3
signatures, matching versionName/code, a non-debuggable APK, and recorded hash.

Before any phone update, obtain separate authorization for a semantically
verified data backup and independent restore. Then verify an in-place update,
launch and restart, saved library/import/exclusion/settings invariants, and
playback on the actual phone. An extracted APK is not a data backup.

Debug APKs and unsigned local build outputs are verification inputs only.
Never uninstall, clear storage, rerun the completed import, or remove a fallback
to make an update succeed. No private signing material belongs in the repository.
