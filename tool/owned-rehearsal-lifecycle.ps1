# Fixed disposable Musify target. Dot-source for offline lifecycle contracts.
function Get-MusifyOwnedEmulator([string]$AvdName='musify_rehearsal_api35') {
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(emulator|qemu-system.*)\.exe$' -and
        $_.ExecutablePath -like 'C:\devtools\android-sdk\emulator\*' -and
        [regex]::Match([string]$_.CommandLine,'(?:-avd\s+|@)([^\s"]+)').Groups[1].Value -eq $AvdName
    })
}
function Invoke-MusifyOwnedAdbProcess([string[]]$Command,[double]$TimeoutSeconds) {
    $python=(Get-Command python -ErrorAction Stop).Source
    $runner=Join-Path $PSScriptRoot 'owned_command.py'
    $output = & $python $runner --timeout-seconds $TimeoutSeconds -- @Command 2>&1
    [pscustomobject]@{ExitCode=$LASTEXITCODE;Output=$output}
}
function Get-MusifyOwnedAdbTimeout([datetime]$Deadline) {
    $remaining=($Deadline-[datetime]::UtcNow).TotalSeconds
    if ($remaining -le 0) {throw 'Owned ADB phase deadline'}
    [math]::Min(5,$remaining)
}
function Get-MusifyOwnedBootStatus([string]$Previous,[string]$Current) {
    # Budget exhaustion is a wrapper condition, not the preceding guest/client result.
    if($Current -eq 'Owned ADB phase deadline'){return $Previous}
    $Current
}
function Invoke-MusifyOwnedAdb([string[]]$Arguments,[string]$Serial='emulator-5556',
    [ValidateRange(0.001,5)][double]$TimeoutSeconds=5) {
    $result=Invoke-MusifyOwnedAdbProcess -Command (@('C:\devtools\android-sdk\platform-tools\adb.exe','-s',$Serial)+$Arguments) -TimeoutSeconds $TimeoutSeconds
    $detail=([string]($result.Output -join "`n"))
    if($detail.Length -gt 512){$detail=$detail.Substring(0,512)}
    if ($result.ExitCode -eq 124) {throw "Owned ADB deadline: $($Arguments -join ' '); $detail"}
    if ($result.ExitCode -ne 0) {throw "Owned ADB command failed: $($Arguments -join ' '); $detail"}
    $result.Output
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
function New-MusifyOwnedRehearsalLease {
    [Threading.Mutex]::new($false,'Local\MusifyRehearsalApi35StorageLease')
}
function Invoke-MusifyOwnedRehearsal {
    [CmdletBinding()]
    param(
        [string]$HarnessScript,
        [string]$ApprovedHarnessSha256,
        [switch]$CheckOnly,
        [ValidateSet('original','saved','isolated')][string]$Target='original',
        [switch]$BootstrapSaved,
        [switch]$ColdBootSaved
    )
    $ErrorActionPreference='Stop'
    if (($BootstrapSaved -and $Target -ne 'saved') -or ($ColdBootSaved -and $Target -eq 'original')) {throw 'Saved-only launch option refused for original AVD'}
    if ($Target -eq 'isolated' -and -not $ColdBootSaved) {throw 'Isolated target requires explicit cold boot'}
    $profiles=@{
        original=@{Name='musify_rehearsal_api35';Serial='emulator-5556';Home='C:\Users\james\Documents\Codex\2026-10-10\task\musify-source-comparison\emulator-rehearsal\avds';Gpu='swiftshader_indirect'}
        saved=@{Name='musify_saved_acceptance_api35';Serial='emulator-5558';Home='V:\Storage-Recovery-20261013\ProjectWork\musify-saved-acceptance\avds';Gpu='swiftshader_indirect'}
        isolated=@{Name='musify_isolated_acceptance_api35';Serial='emulator-5560';Home='V:\Storage-Recovery-20261013\ProjectWork\musify-isolated-acceptance\avds';Gpu='swiftshader'}
    }
    $profile=$profiles[$Target];$avdName=$profile.Name;$serial=$profile.Serial;$avdHome=$profile.Home
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
    $lease=New-MusifyOwnedRehearsalLease
    $held=$false
    $priorAvd=$env:ANDROID_AVD_HOME
    try {
        try {$held=$lease.WaitOne(0)} catch [Threading.AbandonedMutexException] {$held=$true}
        if (-not $held) {throw 'Owned rehearsal lease busy'}
        if (@(Get-MusifyOwnedEmulator -AvdName $avdName).Count) {throw 'Pre-existing owned emulator; no adoption or shutdown'}
        $started=[datetime]::UtcNow
        $env:ANDROID_AVD_HOME=$avdHome
        try {
            $launchArgs=@('-avd',$avdName,'-port',($serial -replace 'emulator-',''),'-no-window','-no-audio','-gpu',$profile.Gpu)
            if($Target -ne 'original'){$launchArgs+=@('-data',(Join-Path $avdHome ($avdName+'.avd\userdata-qemu.img')))}
            if($ColdBootSaved){$launchArgs+='-no-snapshot-load'}
            Start-Process -FilePath 'C:\devtools\android-sdk\emulator\emulator.exe' -ArgumentList $launchArgs -WindowStyle Hidden | Out-Null
            $end=[datetime]::UtcNow.AddSeconds(150)
            $booted=$false
            $lastBootStatus='No boot response yet'
            do {
                Start-Sleep -Seconds 2
                try {
                    $status=(Invoke-MusifyOwnedAdb -Serial $serial -TimeoutSeconds (Get-MusifyOwnedAdbTimeout $end) -Arguments @('shell','getprop','sys.boot_completed')|Out-String).Trim()
                    $lastBootStatus='sys.boot_completed='+$status
                    $booted=$status -eq '1'
                    if ($booted) {
                        $packageName=if($BootstrapSaved){'android'}else{'com.topcat432.musifypersonalized.preview.debug'}
                        $package=Invoke-MusifyOwnedAdb -Serial $serial -TimeoutSeconds (Get-MusifyOwnedAdbTimeout $end) -Arguments @('shell','pm','path',$packageName)|Out-String
                        $lastBootStatus='package readiness='+$package.Trim()
                        $booted=if($BootstrapSaved){$package -match '(?m)^package:/system/.+\.apk\s*$'}else{$package -match '(?m)^package:/data/app/.+/base\.apk\s*$'}
                    }
                } catch {$booted=$false;$lastBootStatus=Get-MusifyOwnedBootStatus $lastBootStatus $_.Exception.Message}
            } while (-not $booted -and [datetime]::UtcNow -lt $end)
            if (-not $booted) {
                if($lastBootStatus.Length -gt 512){$lastBootStatus=$lastBootStatus.Substring(0,512)}
                throw "Owned emulator boot deadline; last bounded status: $lastBootStatus"
            }
            $owned=@(Get-MusifyOwnedEmulator -AvdName $avdName)
            if (-not $owned.Count -or @($owned|Where-Object {$_.CreationDate.ToUniversalTime() -lt $started}).Count) {throw 'Unexpected emulator process ownership'}
            $identity=Invoke-MusifyOwnedAdb -Serial $serial -Arguments @('emu','avd','name')|Out-String
            if ($identity -notmatch ('(?m)^'+[regex]::Escape($avdName)+'\s*$')) {throw 'Owned AVD identity mismatch'}
            $global:LASTEXITCODE=0
            & $harness
            if ($LASTEXITCODE -ne 0) {throw "Owned callback failed: $LASTEXITCODE"}
        } finally {
            $owned=@(Get-MusifyOwnedEmulator -AvdName $avdName)
            if ($owned.Count) {
                $end=[datetime]::UtcNow.AddSeconds(15)
                if (@($owned|Where-Object {$_.CreationDate.ToUniversalTime() -lt $started}).Count) {throw 'Foreign process; shutdown refused'}
                $identity=Invoke-MusifyOwnedAdb -Serial $serial -TimeoutSeconds (Get-MusifyOwnedAdbTimeout $end) -Arguments @('emu','avd','name')|Out-String
                if ($identity -notmatch ('(?m)^'+[regex]::Escape($avdName)+'\s*$')) {throw 'Unverified AVD; shutdown refused'}
                Invoke-MusifyOwnedAdb -Serial $serial -TimeoutSeconds (Get-MusifyOwnedAdbTimeout $end) -Arguments @('emu','kill')|Out-Null
                while (@(Get-MusifyOwnedEmulator -AvdName $avdName).Count -and [datetime]::UtcNow -lt $end) {Start-Sleep -Seconds 1}
                if (@(Get-MusifyOwnedEmulator -AvdName $avdName).Count) {throw 'Graceful shutdown incomplete; no force kill'}
            }
        }
    } finally {
        [Environment]::SetEnvironmentVariable('ANDROID_AVD_HOME',$priorAvd,'Process')
        if ($held) {$lease.ReleaseMutex()}
        $lease.Dispose()
    }
}
