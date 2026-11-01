<#
.SYNOPSIS
The monthly deployment of the team: the scripts of the scripts folder, on the test instance,
then on the production instance.

.DESCRIPTION
The version a colleague wrote: it deploys everything at once, and has no -WhatIf. To rewrite
(README.md of the exercise).
#>
[CmdletBinding()]
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
. (Join-Path $PSScriptRoot '..' '..' 'demos' 'module_11' 'Deploy-PachaScript.ps1')
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
Deploy-PachaScript -SqlInstance ($TestInstance + $ProductionInstance) -SqlCredential $credential -Path $Path -Database $Database
