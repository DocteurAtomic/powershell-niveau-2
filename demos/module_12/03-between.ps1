# Clip 12.2: the two instances compared with each other. Compare-Object -Property compares the
# three properties and returns what is on one side only: the memory, set per instance by
# setup/install.ps1. A difference between two instances is not a drift.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PachaConfiguration.ps1')
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$sql1 = Get-PachaConfiguration -SqlInstance 'localhost,14533' -SqlCredential $credential
$sql2 = Get-PachaConfiguration -SqlInstance 'localhost,14534' -SqlCredential $credential
Compare-Object -ReferenceObject $sql1 -DifferenceObject $sql2 -Property DisplayName, ConfiguredValue, RunningValue |
    Format-Table | Out-String
