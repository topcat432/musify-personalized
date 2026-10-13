# Fixed disposable Musify target. Dot-source for offline lifecycle contracts.
function Get-MusifyOwnedEmulator {
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(emulator|qemu-system.*)\.exe$' -and
        $_.ExecutablePath -like 'C:\devtools\android-sdk\emulator\*' -and
        [regex]::Match([string]$_.CommandLine,'(?:-avd\s+|@)([^\s"]+)').Groups[1].Value -eq 'musify_rehearsal_api35'
    })
}
function Invoke-MusifyOwnedAdb([string[]]$Arguments) {
    $result = & 'C:\devtools\android-sdk\platform-tools\adb.exe' -s emulator-5556 @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Owned ADB command failed: $($Arguments[0])" }
    $result
}
function Get-MusifyRehearsalAdmission {
    $memory=Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
    if (-not $memory.CommitLimit) { throw 'Commit metrics unavailable' }
    [pscustomobject]@{
        CFreeBytes=[IO.DriveInfo]::new('C:\').AvailableFreeSpace
        VFreeBytes=[IO.DriveInfo]::new('V:\').AvailableFreeSpace
        CommittedBytes=[double]$memory.CommittedBytes
        CommitLimit=[double]$memory.CommitLimit
    }
}
function Invoke-MusifyOwnedRehearsal {
    [CmdletBinding()]
    param(
        [string]$HarnessScript,
        [string]$ApprovedHarnessSha256,
        [switch]$CheckOnly
    )
    $ErrorActionPreference='Stop'
    $admission=Get-MusifyRehearsalAdmission
    $projected=100*($admission.CommittedBytes+27917287424)/$admission.CommitLimit
    if ($admission.CFreeBytes -lt 12884901888 -or
        $admission.VFreeBytes -lt 23622320128 -or $projected -gt 80) {
        throw 'Owned rehearsal26GiB/disk budget not admitted; nothing launched'
    }
    [pscustomobject]@{ProjectedCommitPercent=[math]::Round($projected,2);EmulatorCommitBudgetBytes=27917287424}|ConvertTo-Json -Compress
    if ($CheckOnly -or -not $HarnessScript) { return }
    $harness=(Resolve-Path -LiteralPath $HarnessScript).ProviderPath
    if ([IO.Path]::GetExtension($harness) -ne '.ps1' -or
        -not $harness.StartsWith('C:\Users\james\Documents\Codex\2026-10-10\task\musify-source-comparison\',[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Callback must be an owned external PowerShell harness'
    }
    if ($ApprovedHarnessSha256 -notmatch '^[a-fA-F0-9]{64}$' -or
        (Get-FileHash -LiteralPath $harness).Hash -ne $ApprovedHarnessSha256) {
        throw 'Callback hash mismatch'
    }
    $lease=[Threading.Mutex]::new($false,'Local\MusifyRehearsalApi35StorageLease')
    $held=$false
    $priorAvd=$env:ANDROID_AVD_HOME
    try {
        try {$held=$lease.WaitOne(0)} catch [Threading.AbandonedMutexException] {$held=$true}
        if (-not $held) {throw 'Owned rehearsal lease busy'}
        if ((Get-MusifyOwnedEmulator).Count) {throw 'Pre-existing owned emulator; no adoption or shutdown'}
        $started=[datetime]::UtcNow
        $env:ANDROID_AVD_HOME='C:\Users\james\Documents\Codex\2026-10-10\task\musify-source-comparison\emulator-rehearsal\avds'
        try {
            Start-Process -FilePath 'C:\devtools\android-sdk\emulator\emulator.exe' -ArgumentList @('-avd','musify_rehearsal_api35','-port','5556','-no-window','-no-audio','-gpu','swiftshader_indirect','-no-snapshot-load','-no-snapshot-save') -WindowStyle Hidden | Out-Null
            $end=[datetime]::UtcNow.AddSeconds(150)
            $booted=$false
            do {
                Start-Sleep -Seconds 2
                try {$booted=(Invoke-MusifyOwnedAdb @('shell','getprop','sys.boot_completed')|Out-String).Trim() -eq '1'} catch {$booted=$false}
            } while (-not $booted -and [datetime]::UtcNow -lt $end)
            if (-not $booted) {throw 'Owned emulator boot deadline'}
            $owned=Get-MusifyOwnedEmulator
            if (-not $owned.Count -or @($owned|Where-Object {$_.CreationDate.ToUniversalTime() -lt $started}).Count) {throw 'Unexpected emulator process ownership'}
            $identity=Invoke-MusifyOwnedAdb @('emu','avd','name')|Out-String
            if ($identity -notmatch '(?m)^musify_rehearsal_api35\s*$') {throw 'Owned AVD identity mismatch'}
            $global:LASTEXITCODE=0
            & $harness
            if ($LASTEXITCODE -ne 0) {throw "Owned callback failed: $LASTEXITCODE"}
        } finally {
            $owned=Get-MusifyOwnedEmulator
            if ($owned.Count) {
                if (@($owned|Where-Object {$_.CreationDate.ToUniversalTime() -lt $started}).Count) {throw 'Foreign process; shutdown refused'}
                $identity=Invoke-MusifyOwnedAdb @('emu','avd','name')|Out-String
                if ($identity -notmatch '(?m)^musify_rehearsal_api35\s*$') {throw 'Unverified AVD; shutdown refused'}
                Invoke-MusifyOwnedAdb @('emu','kill')|Out-Null
                $end=[datetime]::UtcNow.AddSeconds(15)
                while ((Get-MusifyOwnedEmulator).Count -and [datetime]::UtcNow -lt $end) {Start-Sleep -Seconds 1}
                if ((Get-MusifyOwnedEmulator).Count) {throw 'Graceful shutdown incomplete; no force kill'}
            }
        }
    } finally {
        [Environment]::SetEnvironmentVariable('ANDROID_AVD_HOME',$priorAvd,'Process')
        if ($held) {$lease.ReleaseMutex()}
        $lease.Dispose()
    }
}
