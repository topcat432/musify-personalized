param(
    [Parameter(Position=0)]
    [ValidateSet('setup','test','visual','verify','build')]
    [string]$Action = 'verify',
    [string]$StorageSessionScript = 'C:\Users\james\Documents\Codex\2026-10-12\task\task-storage-session.ps1'
)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExecutable = if ($flutterCommand) { $flutterCommand.Source } else { 'C:\devtools\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterExecutable)) { throw 'Flutter is missing; this helper does not install it.' }
if (-not $env:JAVA_HOME -and (Test-Path -LiteralPath 'C:\devtools\jdk-17.0.19+10')) { $env:JAVA_HOME = 'C:\devtools\jdk-17.0.19+10' }
if (-not $env:ANDROID_SDK_ROOT -and (Test-Path -LiteralPath 'C:\devtools\android-sdk')) { $env:ANDROID_SDK_ROOT = 'C:\devtools\android-sdk' }
if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = $env:ANDROID_SDK_ROOT }
$toolPaths = @((Split-Path -Parent $flutterExecutable))
if ($env:JAVA_HOME) { $toolPaths += Join-Path $env:JAVA_HOME 'bin' }
if ($env:ANDROID_SDK_ROOT) { $toolPaths += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools' }
$env:Path = ($toolPaths -join [IO.Path]::PathSeparator) + [IO.Path]::PathSeparator + $env:Path
function Invoke-FlutterCheck([string[]]$Arguments) {
    & $flutterExecutable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter check failed with exit $($LASTEXITCODE): $($Arguments -join ' ')" }
}
$versionText = & $flutterExecutable --no-version-check --suppress-analytics --version --machine
if ($LASTEXITCODE -ne 0) { throw 'Unable to read Flutter version.' }
$version = ($versionText -join [Environment]::NewLine) | ConvertFrom-Json
if ($version.frameworkVersion -ne '3.44.5') { throw "Expected Flutter 3.44.5; found $($version.frameworkVersion)." }
Write-Output "Flutter $($version.frameworkVersion); Java $env:JAVA_HOME; SDK $env:ANDROID_SDK_ROOT"
if ($Action -eq 'setup') { return }
if (-not (Test-Path -LiteralPath $StorageSessionScript -PathType Leaf)) { throw 'Required storage-session helper missing; do not bypass admission.' }
if (-not (Test-Path -LiteralPath 'V:\') -or -not (Test-Path -LiteralPath 'C:\Users\james\.gradle\caches')) { throw 'Required V: working volume or Gradle cache lookup unavailable.' }
$harness = Join-Path $PSScriptRoot 'dev-workload.ps1'
$harnessHash = (Get-FileHash -LiteralPath $harness -Algorithm SHA256).Hash
$build = $Action -eq 'build'
$savedAction = [Environment]::GetEnvironmentVariable('MUSIFY_DEV_WORKLOAD_ACTION','Process')
try {
    $env:MUSIFY_DEV_WORKLOAD_ACTION = $Action
    $global:LASTEXITCODE = 0
    & $StorageSessionScript -Project 'musify' -HarnessScript $harness -ApprovedHarnessSha256 $harnessHash `
        -ExpectedCWritesBytes $(if ($build) { 21474836480 } else { 2147483648 }) `
        -ExpectedVWritesBytes $(if ($build) { 6442450944 } else { 5368709120 }) `
        -ExpectedCommitBytes $(if ($build) { 34359738368 } else { 3221225472 })
    if ($LASTEXITCODE -ne 0) { throw "Guarded workload failed with exit $LASTEXITCODE." }
} finally {
    if ($null -eq $savedAction) { [Environment]::SetEnvironmentVariable('MUSIFY_DEV_WORKLOAD_ACTION',[NullString]::Value,'Process') }
    else { $env:MUSIFY_DEV_WORKLOAD_ACTION = $savedAction }
}
