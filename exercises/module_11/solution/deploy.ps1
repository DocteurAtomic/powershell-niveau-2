<#
.SYNOPSIS
The monthly deployment of the team: the scripts of the scripts folder, on the test instance,
then on the production instance.

.DESCRIPTION
The test instances first. When one of them returns anything but Applied or AlreadyApplied,
the production instances are not deployed, and the script throws an error that names the
instance and the status. -WhatIf says what would be applied, everywhere, and applies nothing:
the preference reaches Deploy-PachaScript, defined in this script.

.EXAMPLE
./exercises/module_11/solution/deploy.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # The instances deployed first.
    [string[]] $TestInstance = @('localhost,14534'),
    # The instances deployed when every test instance succeeded.
    [string[]] $ProductionInstance = @('localhost,14533'),
    # The database that receives the scripts.
    [string] $Database = 'DBA',
    # The folder of the scripts.
    [string] $Path = (Join-Path $PSScriptRoot 'scripts')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..' '..' '..' 'demos' 'module_11' 'Deploy-PachaScript.ps1')
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$deployment = @{ SqlCredential = $credential; Path = $Path; Database = $Database }

$test = @(Deploy-PachaScript @deployment -SqlInstance $TestInstance)
$test
$failed = @($test | Where-Object -Property Status -NotIn 'Applied', 'AlreadyApplied')
if ($failed) {
    $what = @($failed | ForEach-Object { "$($_.SqlInstance) $($_.Status) $($_.Script)".TrimEnd() }) -join '; '
    throw "The test instances failed ($what): the production instances are not deployed."
}
Deploy-PachaScript @deployment -SqlInstance $ProductionInstance
