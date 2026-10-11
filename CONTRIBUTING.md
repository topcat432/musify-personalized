# Working on Musify Personalized

Start with AGENTS.md and docs/RELEASE_STATE.md. This is the operational guide
for fixes, updates and features; product direction stays in PRODUCT_VISION.md
and IMPORT_AND_MATCHING_ROADMAP.md under docs.

## One source line

Repository: https://github.com/topcat432/musify-personalized.
Protected integration branch: master. Until approved integration, draft PR #23
on agent/local-stable-consolidation is the one active candidate. It preserves
#20's foundation, corrected #21 intent and installed identity. #22 Home/shell
work is recoverably preserved as a deferred roadmap item.

Before work:
~~~bash
git status --short --branch
git remote -v
git fetch origin
gh pr list --repo topcat432/musify-personalized --state open
gh run list --repo topcat432/musify-personalized --limit 10
git rev-parse origin/master
~~~
Do not switch/reset unrelated dirty work. Continue the assigned clean candidate
or use a clean worktree. After consolidation, start features from fresh
origin/master on one task branch/PR, avoiding competing overhaul branches.

## Toolchain and checks

Flutter 3.44.5 / Dart 3.12.2, Java 17, wrapper Gradle 8.14.3, compile SDK 36,
NDK 28.2.13676358, CMake 3.22.1. Pubspec/workflows pin Flutter. Resolve dependencies normally
through pub.dev, Gradle Plugin Portal, Maven Central and Google. Do not bypass
denials, silently upgrade tools, change security/global Git trust or remove
shared SDK locks.

On DESKTOP-OPE9IIV, tool/dev.ps1 discovers existing C:\devtools tools and sets
only process-local variables. It does not install tools, access secrets, change
remotes or install APKs:
~~~powershell
.\tool\dev.ps1 setup
.\tool\dev.ps1 test
.\tool\dev.ps1 visual
.\tool\dev.ps1 verify
.\tool\dev.ps1 build
~~~
Equivalent checks on configured hosts, from repository root:
~~~bash
flutter pub get
flutter analyze .
flutter test
flutter test tool/visual_review_test.dart
flutter test tool/visual_review_priority_test.dart
git diff --check
flutter build apk --release --flavor github --dart-define=GIT_SHA="$(git rev-parse HEAD)"
~~~
Run targeted regressions first. Product edits need aggregate checks, both
strict visual suites and Android CI; documentation-only edits need text/link/
state checks. debug.yml is the Linux reference and verifies debug/F-Droid
boundaries and unsigned release assembly. CI artifacts are evidence, not updates.
sdkDownload=false prevents implicit SDK installation: name missing components
and use official SDK manager only within approved installation scope.

## Visual changes and features

Keep goldens during diagnosis. Inspect actual/expected/isolated/masked diffs
and run unchanged source controls. Windows identical controls bound a regression
claim, not Linux PASS. Review intended changes on the reference host; update only
named inspected PNGs and rerun strict comparisons. Never bulk regenerate
unexplained failures or relax the comparator.
For features, state behavior/files/data/acceptance criteria; check existing and
deferred work; reuse models/tokens. Add meaningful synthetic regressions for
actual risk, including old/partial durable state. Maintain one PR describing
final behavior/evidence. Green CI does not approve merge or release.

## Data, release and cleanup

Use docs/DATA_RECOVERY_RUNBOOK.md for app-supported export/disposable restore
and docs/TESTING_DATA_SAFETY.md for acceptance. An APK is not a data backup.
Never clear/reimport to manufacture acceptance. Every device command names its
approved serial. Keep personal backups/screenshots outside the checkout and
Library unless sharing that data is explicitly authorized.

The workflows are debug.yml (verify) and signed-release.yml (unsigned
build, isolated sign/verify/publish using existing CI-held secrets). Never read
secret values locally. Signing/publication require separate approval for exact
current default-tip SHA after checks. See docs/RELEASE_SIGNING.md.

Before approved retirement, inventory heads/PRs/protections/activity, bundle
exact branch/tag/PR heads, restore all refs and run git fsck --full. Record hash
and per-line dispositions; immediately recheck each head/activity and use an
exact-SHA deletion lease. Keep default/protected/active branches, tags, releases
and artifacts. Do not merge obsolete code to simplify cleanup. Recover into a
fresh local review branch, never blindly resurrect old workflows.
