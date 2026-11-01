# Clip 11.2: the deployment function of the team, on the test instance first (sql2): what it
# would apply (-WhatIf), then the deployment, then the same command again, which applies
# nothing. 99-cleanup.ps1 removes the journal.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Deploy-PachaScript.ps1')
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$deployment = @{
    SqlInstance   = 'localhost,14534'
    SqlCredential = $credential
    Path          = Join-Path $PSScriptRoot 'scripts'
}
Deploy-PachaScript @deployment -WhatIf
Deploy-PachaScript @deployment | Format-Table -Property SqlInstance, Database, Script, Status | Out-String
Deploy-PachaScript @deployment | Format-Table -Property SqlInstance, Database, Script, Status | Out-String
