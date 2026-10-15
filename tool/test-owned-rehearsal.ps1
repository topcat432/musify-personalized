# Pester3 mocks: no native process, provider, install or data mutation.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'owned-rehearsal-lifecycle.ps1')
$fixture='C:\Users\james\Documents\Codex\2026-10-10\task\musify-source-comparison\emulator-rehearsal\lifecycle-contracts'
[void](New-Item -ItemType Directory -Path $fixture -Force)
$callback=Join-Path $fixture 'callback.ps1'
Set-Content -LiteralPath $callback -Value "if (`$global:mockCallbackFailure) {throw 'Synthetic callback failure'}; `$global:mockCallbackRan=`$true"
$hash=(Get-FileHash -LiteralPath $callback).Hash
Describe 'Owned emulator lifecycle' {
    BeforeEach {
        $global:mockAlive=$false;$global:mockPreexisting=$false
        $global:mockCallbackRan=$false;$global:mockCallbackFailure=$false
        $global:mockBootFailure=$false;$global:mockAdmissionFailure=$false
        $global:mockPackageWait=$false;$global:mockPackagePolls=0
        $global:mockIdentity='musify_rehearsal_api35'
        Mock Get-MusifyRehearsalAdmission {
            [pscustomobject]@{CFreeBytes=100GB;VFreeBytes=100GB;CommittedBytes=$(if($global:mockAdmissionFailure){79GB}else{10GB});CommitLimit=100GB}
        }
        Mock Start-Process {$global:mockAlive=$true}
        Mock Start-Sleep {if($global:mockBootFailure){throw 'Synthetic boot failure'}}
        Mock Get-MusifyOwnedEmulator {
            if($global:mockPreexisting -or $global:mockAlive){
                ,[pscustomobject]@{CreationDate=$(if($global:mockPreexisting){[datetime]::UtcNow.AddMinutes(-1)}else{[datetime]::UtcNow.AddSeconds(1)})}
            }else{@()}
        }
        Mock Invoke-MusifyOwnedAdb {
            param($Arguments)
            if($Arguments[1] -eq 'getprop'){'1'}
            elseif($Arguments[1] -eq 'pm'){
                $global:mockPackagePolls++
                if($global:mockPackageWait -and $global:mockPackagePolls -eq 1){throw 'Synthetic package manager not ready'}
                if($Arguments[-1] -eq 'android'){'package:/system/framework/framework-res.apk'}else{'package:/data/app/owned/base.apk'}
            }
            elseif($Arguments[1] -eq 'avd'){$global:mockIdentity}
            elseif($Arguments[1] -eq 'kill'){$global:mockAlive=$false}
        }
    }
    It 'launches once and shuts down after successful callback; restores environment' {
        $prior=$env:ANDROID_AVD_HOME
        Invoke-MusifyOwnedRehearsal -HarnessScript $callback -ApprovedHarnessSha256 $hash
        $global:mockCallbackRan | Should Be $true
        $global:mockAlive | Should Be $false
        ([string]$env:ANDROID_AVD_HOME -ceq [string]$prior) | Should Be $true
        Assert-MockCalled Start-Process -Scope It -Times 1 -Exactly -ParameterFilter {$ArgumentList -notcontains '-no-snapshot-load' -and $ArgumentList -notcontains '-no-snapshot-save' -and $WindowStyle -eq 'Hidden'}
        Assert-MockCalled Invoke-MusifyOwnedAdb -Scope It -Times 1 -Exactly -ParameterFilter {$Arguments[1] -eq 'kill'}
    }
    It 'gracefully shuts down when callback throws' {
        $global:mockCallbackFailure=$true
        {Invoke-MusifyOwnedRehearsal -HarnessScript $callback -ApprovedHarnessSha256 $hash} | Should Throw 'Synthetic callback failure'
        $global:mockAlive | Should Be $false
        Assert-MockCalled Invoke-MusifyOwnedAdb -Scope It -Times 1 -Exactly -ParameterFilter {$Arguments[1] -eq 'kill'}
    }
    It 'waits for exact package readiness before callback' {
        $global:mockPackageWait=$true
        Invoke-MusifyOwnedRehearsal -HarnessScript $callback -ApprovedHarnessSha256 $hash
        $global:mockPackagePolls | Should Be 2
        $global:mockCallbackRan | Should Be $true
        $global:mockAlive | Should Be $false
    }
    It 'gracefully shuts down after boot failure without invoking callback' {
        $global:mockBootFailure=$true
        {Invoke-MusifyOwnedRehearsal -HarnessScript $callback -ApprovedHarnessSha256 $hash} | Should Throw 'Synthetic boot failure'
        $global:mockCallbackRan | Should Be $false
        $global:mockAlive | Should Be $false
    }
    It 'refuses a pre-existing process without launch or shutdown' {
        $global:mockPreexisting=$true
        {Invoke-MusifyOwnedRehearsal -HarnessScript $callback -ApprovedHarnessSha256 $hash} | Should Throw 'Pre-existing'
        Assert-MockCalled Start-Process -Scope It -Times 0 -Exactly
        Assert-MockCalled Invoke-MusifyOwnedAdb -Scope It -Times 0 -Exactly
    }
    It 'refuses foreign AVD identity without callback or shutdown' {
        $global:mockIdentity='foreign'
        {Invoke-MusifyOwnedRehearsal -HarnessScript $callback -ApprovedHarnessSha256 $hash} | Should Throw 'Unverified AVD'
        $global:mockCallbackRan | Should Be $false
        Assert-MockCalled Invoke-MusifyOwnedAdb -Scope It -Times 0 -Exactly -ParameterFilter {$Arguments[1] -eq 'kill'}
    }
    It 'refuses mismatched callback hash before launch' {
        {Invoke-MusifyOwnedRehearsal -HarnessScript $callback -ApprovedHarnessSha256 ('0'*64)} | Should Throw 'hash mismatch'
        Assert-MockCalled Start-Process -Scope It -Times 0 -Exactly
    }
    It 'refuses resource admission before launch' {
        $global:mockAdmissionFailure=$true
        {Invoke-MusifyOwnedRehearsal -HarnessScript $callback -ApprovedHarnessSha256 $hash} | Should Throw 'not admitted'
        Assert-MockCalled Start-Process -Scope It -Times 0 -Exactly
    }
    It 'pins isolated bootstrap to serial5558 and persistent V data' {
        $global:mockIdentity='musify_saved_acceptance_api35'
        Invoke-MusifyOwnedRehearsal -Target saved -BootstrapSaved -HarnessScript $callback -ApprovedHarnessSha256 $hash
        $global:mockCallbackRan | Should Be $true
        Assert-MockCalled Start-Process -Scope It -Times 1 -Exactly -ParameterFilter {$ArgumentList -contains '5558' -and $ArgumentList -contains '-data' -and $ArgumentList -contains 'V:\Storage-Recovery-20261013\ProjectWork\musify-saved-acceptance\avds\musify_saved_acceptance_api35.avd\userdata-qemu.img'}
        Assert-MockCalled Invoke-MusifyOwnedAdb -Scope It -Times 1 -Exactly -ParameterFilter {$Serial -eq 'emulator-5558' -and $Arguments[1] -eq 'kill'}
    }
    It 'allows saved-only cold restart without changing original snapshot flags' {
        $global:mockIdentity='musify_saved_acceptance_api35'
        Invoke-MusifyOwnedRehearsal -Target saved -ColdBootSaved -HarnessScript $callback -ApprovedHarnessSha256 $hash
        Assert-MockCalled Start-Process -Scope It -Times 1 -Exactly -ParameterFilter {$ArgumentList -contains '-no-snapshot-load' -and $ArgumentList -notcontains '-no-snapshot-save' -and $ArgumentList -contains '-data'}
    }
    It 'pins isolated clone to serial5560, its own disk and modern software renderer' {
        $global:mockIdentity='musify_isolated_acceptance_api35'
        Invoke-MusifyOwnedRehearsal -Target isolated -ColdBootSaved -HarnessScript $callback -ApprovedHarnessSha256 $hash
        $global:mockCallbackRan | Should Be $true
        $global:mockAlive | Should Be $false
        Assert-MockCalled Start-Process -Scope It -Times 1 -Exactly -ParameterFilter {$ArgumentList -contains '5560' -and $ArgumentList -contains 'swiftshader' -and $ArgumentList -notcontains 'swiftshader_indirect' -and $ArgumentList -contains '-no-snapshot-load' -and $ArgumentList -contains 'V:\Storage-Recovery-20261013\ProjectWork\musify-isolated-acceptance\avds\musify_isolated_acceptance_api35.avd\userdata-qemu.img'}
        Assert-MockCalled Invoke-MusifyOwnedAdb -Scope It -Times 1 -Exactly -ParameterFilter {$Serial -eq 'emulator-5560' -and $Arguments[1] -eq 'kill'}
    }
    It 'refuses isolated snapshot startup without an explicit cold boot' {
        {Invoke-MusifyOwnedRehearsal -Target isolated -HarnessScript $callback -ApprovedHarnessSha256 $hash} | Should Throw 'requires explicit cold boot'
        Assert-MockCalled Start-Process -Scope It -Times 0 -Exactly
    }
    It 'refuses bootstrap for the already-cloned isolated target' {
        {Invoke-MusifyOwnedRehearsal -Target isolated -BootstrapSaved -ColdBootSaved -HarnessScript $callback -ApprovedHarnessSha256 $hash} | Should Throw 'Saved-only'
        Assert-MockCalled Start-Process -Scope It -Times 0 -Exactly
    }
    It 'refuses bootstrap of original target before launch' {
        {Invoke-MusifyOwnedRehearsal -BootstrapSaved -HarnessScript $callback -ApprovedHarnessSha256 $hash} | Should Throw 'Saved-only'
        Assert-MockCalled Start-Process -Scope It -Times 0 -Exactly
    }
    It 'refuses cold override of original target before launch' {
        {Invoke-MusifyOwnedRehearsal -ColdBootSaved -HarnessScript $callback -ApprovedHarnessSha256 $hash} | Should Throw 'Saved-only'
        Assert-MockCalled Start-Process -Scope It -Times 0 -Exactly
    }}
