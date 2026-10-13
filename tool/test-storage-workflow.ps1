# Offline contract tests: fake Flutter and session transport; no pub/test/build.
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('musify-storage-contract-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $fixture)
$fakeFlutter=Join-Path $fixture 'flutter.bat'
Set-Content -LiteralPath $fakeFlutter -Value '@echo off','echo {"frameworkVersion":"3.44.5"}'
$calls=Join-Path $fixture 'calls.jsonl'
$fakeSession=Join-Path $fixture 'fake-session.ps1'
@'
param($Project,$HarnessScript,$ApprovedHarnessSha256,$ExpectedCWritesBytes,$ExpectedVWritesBytes,$ExpectedCommitBytes)
if((Get-FileHash -LiteralPath $HarnessScript -Algorithm SHA256).Hash -ne $ApprovedHarnessSha256){throw 'Hash mismatch'}
[ordered]@{Action=$env:MUSIFY_DEV_WORKLOAD_ACTION;Project=$Project;C=[long]$ExpectedCWritesBytes;V=[long]$ExpectedVWritesBytes;Commit=[long]$ExpectedCommitBytes;HashVerified=$true}|ConvertTo-Json -Compress|Add-Content -LiteralPath $env:MUSIFY_MOCK_CALLS_FILE
$global:LASTEXITCODE=0
'@ | Set-Content -LiteralPath $fakeSession
$vars=@('Path','JAVA_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','MUSIFY_DEV_WORKLOAD_ACTION','MUSIFY_MOCK_CALLS_FILE')
$saved=@{};foreach($name in $vars){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
$passed=0
try{
 $env:Path=$fixture+[IO.Path]::PathSeparator+$env:Path
 $env:MUSIFY_MOCK_CALLS_FILE=$calls
 $env:MUSIFY_DEV_WORKLOAD_ACTION='prior-value'
 foreach($action in @('test','visual','verify','build')){
  & (Join-Path $PSScriptRoot 'dev.ps1') $action -StorageSessionScript $fakeSession
  if($env:MUSIFY_DEV_WORKLOAD_ACTION -ne 'prior-value'){throw 'Action environment leaked'}
 }
 $rows=@(Get-Content -LiteralPath $calls|ForEach-Object{$_|ConvertFrom-Json})
 if($rows.Count -ne 4){throw 'Every workload must invoke admission exactly once'}
 foreach($row in $rows){
  $build=$row.Action -eq 'build'
  if($row.Project -ne 'musify' -or -not $row.HashVerified -or
   $row.C -ne $(if($build){4294967296}else{2147483648}) -or
   $row.V -ne $(if($build){6442450944}else{5368709120}) -or
   $row.Commit -ne $(if($build){6442450944}else{3221225472})){throw 'Budget/hash forwarding mismatch'}
 }
 $passed++
 & (Join-Path $PSScriptRoot 'dev.ps1') setup -StorageSessionScript (Join-Path $fixture 'missing.ps1')
 if(@(Get-Content -LiteralPath $calls).Count -ne 4){throw 'Setup must not launch a workload'}
 $passed++
 $blocked=$false
 try{& (Join-Path $PSScriptRoot 'dev.ps1') test -StorageSessionScript (Join-Path $fixture 'missing.ps1')}catch{$blocked=$_.ToString() -match 'helper missing'}
 if(-not $blocked){throw 'Missing guard must fail closed'}
 $passed++
 $reject=Join-Path $fixture 'reject-session.ps1'
 Set-Content -LiteralPath $reject -Value "throw 'Synthetic admission rejection'"
 $blocked=$false
 try{& (Join-Path $PSScriptRoot 'dev.ps1') test -StorageSessionScript $reject}catch{$blocked=$_.ToString() -match 'Synthetic admission rejection'}
 if(-not $blocked -or $env:MUSIFY_DEV_WORKLOAD_ACTION -ne 'prior-value'){throw 'Admission failure leaked state or launched work'}
 $passed++
 foreach($file in @('dev.ps1','dev-workload.ps1','test-storage-workflow.ps1')){
  $tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $file),[ref]$tokens,[ref]$errors)|Out-Null
  if($errors.Count){throw "PowerShell syntax failed: $file"}
 }
 $passed++
 [ordered]@{Passed=$passed;NativeFlutterWorkloads=0;ProviderRequests=0;Evidence=$fixture}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $fixture 'proof.json')
 Write-Output "PASS $passed storage workflow contracts; no real pub/build/test or provider request. Evidence: $fixture"
}finally{
 foreach($name in $saved.Keys){if($null -eq $saved[$name]){[Environment]::SetEnvironmentVariable($name,[NullString]::Value,'Process')}else{[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}
 Set-Location -LiteralPath $repo
}
