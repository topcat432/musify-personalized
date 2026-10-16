[CmdletBinding()]
param([string]$HarnessScript,[string]$ApprovedHarnessSha256,[switch]$CheckOnly,[ValidateSet('original','saved','isolated')][string]$Target='original',[switch]$BootstrapSaved,[switch]$ColdBootSaved,[string]$ReadinessDiagnosticScript,[string]$ApprovedReadinessDiagnosticSha256)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'owned-rehearsal-lifecycle.ps1')
Invoke-MusifyOwnedRehearsal @PSBoundParameters
