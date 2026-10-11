# Update delivery plan

## Retained stable update identity — local candidate, 2026-10-11

The authorized candidate consolidates PR #20's foundation with corrected PR #21
playback behavior. PR #22 is deferred. It keeps the installed package
`com.topcat432.musifypersonalized.preview` and the existing long-lived signer.
The suffix does not imply a new preview channel. The stable app label is
`Musify Personalized`; debug builds use `.preview.debug` and the DEBUG label.
F-Droid's existing package and permission boundary remain unchanged.

The installed Samsung baseline is versionCode `300000001`. The local candidate
uses `0.1.300000002+300000002`; approved signed releases select their monotonic
version in `signed-release.yml`. The in-app updater accepts only the retained
package and matching signer. Legacy releases for
`com.topcat432.musifypersonalized` remain separate-app historical artifacts and
are rejected as updates to the retained app.

About reads Android versionName/code rather than the former hardcoded `10.1.0`.
New Android backups record actual package/version metadata and stable/debug
channel. Schema 1 payloads, checksums, semantic validation and rollback remain
unchanged. Historical production/debug backup origins remain readable because
older builds, including the installed preview candidate, recorded those origins.
Origin metadata alone is not proof of saved data or successful restore.

## Remaining acceptance gates

This is local implementation, not a signed release or phone-tested update.
Before distribution: review the final candidate, pass aggregate and visual
checks, approve repository integration, verify the exact default-branch tip,
then separately authorize signing/publication through the sole release path.
Before installation: separately authorize and verify a real data backup and
independent restore; verify in-place installation, launch, restart, saved data
invariants and playback. Never uninstall or clear storage to force acceptance.
The installed APK extraction preserves only the binary, not private app data.

## Historical plan superseded

Earlier notes proposed reset/reimport into a separate production package and
assumed a surviving debug dataset. The read-only 2026-10-11 investigation found
only the retained `.preview` Musify package on the selected Samsung. The user
selected the data-preserving route. No reset, reimport, migration or fallback
removal is authorized by this candidate.
