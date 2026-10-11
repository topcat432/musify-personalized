param(
    [Parameter(Position=0)]
    [ValidateSet('setup','test','visual','verify','build')]
    [string]$Action = 'verify'
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
$versionText = & $flutterExecutable --version --machine
if ($LASTEXITCODE -ne 0) { throw 'Unable to read Flutter version.' }
$version = ($versionText -join [Environment]::NewLine) | ConvertFrom-Json
if ($version.frameworkVersion -ne '3.44.5') { throw "Expected Flutter 3.44.5; found $($version.frameworkVersion)." }
Write-Output "Flutter $($version.frameworkVersion); Java $env:JAVA_HOME; SDK $env:ANDROID_SDK_ROOT"
if ($Action -eq 'setup') { return }
Invoke-FlutterCheck -Arguments @('pub','get')
if ($Action -in @('test','verify')) {
    Invoke-FlutterCheck -Arguments @('analyze','--no-pub','.')
    Invoke-FlutterCheck -Arguments @('test','--no-pub')
}
if ($Action -in @('visual','verify')) {
    Invoke-FlutterCheck -Arguments @('test','--no-pub','tool/visual_review_test.dart')
    Invoke-FlutterCheck -Arguments @('test','--no-pub','tool/visual_review_priority_test.dart')
}
if ($Action -eq 'build') {
    if (Test-Path -LiteralPath 'android/key.properties') { throw 'Expected unsigned build; signing configuration exists.' }
    if (Test-Path -LiteralPath 'android/app/key.jks') { throw 'Expected unsigned build; key file exists.' }
    $sourceCommit = & git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot establish source commit.' }
    if (& git status --porcelain --untracked-files=normal) { throw 'Commit changes before attributing an APK to a commit.' }
    Invoke-FlutterCheck -Arguments @('build','apk','--no-pub','--release','--flavor','github',"--dart-define=GIT_SHA=$sourceCommit")
}
& git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Git whitespace check failed.' }
