[CmdletBinding()]
param([string]$HarnessScript,[string]$ApprovedHarnessSha256,[switch]$CheckOnly,[ValidateSet('original','saved')][string]$Target='original',[switch]$BootstrapSaved,[switch]$ColdBootSaved)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'owned-rehearsal-lifecycle.ps1')
Invoke-MusifyOwnedRehearsal @PSBoundParameters
