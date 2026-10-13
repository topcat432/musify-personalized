[CmdletBinding()]
param([string]$HarnessScript,[string]$ApprovedHarnessSha256,[switch]$CheckOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'owned-rehearsal-lifecycle.ps1')
Invoke-MusifyOwnedRehearsal @PSBoundParameters
