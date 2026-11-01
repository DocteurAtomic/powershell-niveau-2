# Clip 10.2: the same checks run twice, first with a configuration alone, then with the
# instances and the credential as parameters and the rules of the team from their file.
# Run in a new process:
#     pwsh -NoProfile -File demos/module_10/04-configuration.ps1
# Every Set-DbcConfig here has -Temporary: without it, dbachecks writes the value into the
# profile of the user, and every later session starts with it.
$ErrorActionPreference = 'Stop'
Import-Module -Name Pester -RequiredVersion 5.9.1
Import-Module -Name dbachecks -RequiredVersion 3.0.2
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$instances = 'localhost,14533', 'localhost,14534'

# A configuration alone: the instances and the credential set by Set-DbcConfig. Discovery
# finds no test, and the run passes.
Set-DbcConfig -Name app.sqlinstance -Value $instances -Temporary | Out-Null
Set-DbcConfig -Name app.sqlcredential -Value $credential -Temporary | Out-Null
$result = Invoke-DbcCheck -Check RecoveryModel, ValidDatabaseOwner -Legacy:$false -PassThru -Show None
'Configuration alone:'
$result | Select-Object -Property Result, TotalCount, PassedCount, FailedCount, NotRunCount |
    Format-Table | Out-String

# The same checks, the instances and the credential as parameters, the rules of the team
# from the file.
$result = Invoke-DbcCheck -SqlInstance $instances -SqlCredential $credential `
    -Check RecoveryModel, ValidDatabaseOwner -ConfigFile (Join-Path $PSScriptRoot 'pachadata.dbachecks.json') `
    -Legacy:$false -PassThru -Show None
'Parameters and the file of the team:'
$result | Select-Object -Property Result, TotalCount, PassedCount, FailedCount, NotRunCount |
    Format-Table | Out-String
