# Musify Personalized

A personal, local-first music library and playback app, built from
[gokadzev/Musify](https://github.com/gokadzev/Musify) under GPLv3. Upstream authorship
and attribution remain preserved.

This repository is https://github.com/topcat432/musify-personalized.
Start with [the current state map](docs/RELEASE_STATE.md) and
[development guide](CONTRIBUTING.md). Agents must read [AGENTS.md](AGENTS.md).

## Current work

Protected master is the integration branch. [PR #23](https://github.com/topcat432/musify-personalized/pull/23)
on agent/local-stable-consolidation is the sole active stability candidate.
It keeps the installed Android identity, preserves #20's UI foundation and fixes
#21's shuffle/retry defects. #22 Home/shell work is preserved for later review.
A candidate passing CI is not a signed release or phone-tested update.

The retained stable package is com.topcat432.musifypersonalized.preview; its
historical suffix remains to preserve the existing data container. Visible
branding is Musify Personalized. Debug builds use .preview.debug and a DEBUG
label; F-Droid retains its separate package and permission boundary.

## Capabilities and roadmap

Existing source supports music search/playback, Liked Songs and playlists,
offline downloads, import/matching/review with explicit routing and exclusions,
listening history, schema-1 backup/restore and verified personalized updates.
Coverage and device gaps are explicit in the state map. Product direction and
future import/library/DJ work are in [PRODUCT_VISION.md](docs/PRODUCT_VISION.md)
and [IMPORT_AND_MATCHING_ROADMAP.md](docs/IMPORT_AND_MATCHING_ROADMAP.md).

## Checks and updates

[CONTRIBUTING.md](CONTRIBUTING.md) contains pinned tooling, commands, visual
review, feature procedures and branch recovery. On the configured Windows host,
tool/dev.ps1 configures existing tools without user setup or global changes.
Linux debug.yml is the reference verification path. signed-release.yml is the
only user-facing signing/publishing path, held for separate approval.

Historical releases for com.topcat432.musifypersonalized are a different app
container and do not update the current Samsung package in place. Debug and
unsigned CI outputs are not user updates. Do not download upstream releases
as replacements for this personalized app.

Use [DATA_RECOVERY_RUNBOOK.md](docs/DATA_RECOVERY_RUNBOOK.md) for local export and
disposable restore before an update. An APK is not a data backup; never
uninstall, clear storage or reimport to force acceptance.

## License and attribution

[GPLv3](LICENSE). Original Musify development by Valeri Gokadze and upstream
contributors; this fork adds personalized library/import/recovery/update work.
Test fonts come from the pinned Flutter SDK or the Linux reference environment;
CI records their provenance. Production typography is unchanged.
