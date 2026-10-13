# Invoked by task-storage-session.ps1 after exact harness hash/admission checks.
$ErrorActionPreference = 'Stop'
$workloadAction = $env:MUSIFY_DEV_WORKLOAD_ACTION
if ($workloadAction -notin @('test','visual','verify','build')) { throw 'Invalid guarded Musify action.' }
. (Join-Path $PSScriptRoot 'dev.ps1') setup
$flutterExecutable = (Get-Command flutter).Source
function Invoke-FlutterCheck([string[]]$Arguments) {
    & $flutterExecutable --no-version-check --suppress-analytics @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter check failed with exit $LASTEXITCODE." }
}
Invoke-FlutterCheck -Arguments @('pub','get')
if ($workloadAction -in @('test','verify')) {
    Invoke-FlutterCheck -Arguments @('analyze','--no-pub','.')
    Invoke-FlutterCheck -Arguments @('test','--no-pub')
}
if ($workloadAction -in @('visual','verify')) {
    Invoke-FlutterCheck -Arguments @('test','--no-pub','tool/visual_review_test.dart')
    Invoke-FlutterCheck -Arguments @('test','--no-pub','tool/visual_review_priority_test.dart')
}
if ($workloadAction -eq 'build') {
    if (Test-Path -LiteralPath 'android/key.properties') { throw 'Expected unsigned build; signing configuration exists.' }
    if (Test-Path -LiteralPath 'android/app/key.jks') { throw 'Expected unsigned build; key file exists.' }
    $sourceCommit = & git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot establish source commit.' }
    if (& git status --porcelain --untracked-files=normal) { throw 'Commit changes before attributing an APK to a commit.' }
    # This process only; avoid a task build leaving a shared persistent daemon.
    $env:GRADLE_OPTS = ($env:GRADLE_OPTS + ' -Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1').Trim()
    Invoke-FlutterCheck -Arguments @('build','apk','--no-pub','--release','--flavor','github',"--dart-define=GIT_SHA=$sourceCommit")
}
& git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Git whitespace check failed.' }
