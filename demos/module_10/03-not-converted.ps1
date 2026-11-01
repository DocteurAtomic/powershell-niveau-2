# Clip 10.1: the checks that the Pester 5 mode of dbachecks 3.0.2 leaves out, listed in its
# configuration dbachecks.checks.notv5ready, the backups among them. Run in a new process:
#     pwsh -NoProfile -File demos/module_10/03-not-converted.ps1
$ErrorActionPreference = 'Stop'
Import-Module -Name Pester -RequiredVersion 5.9.1
Import-Module -Name dbachecks -RequiredVersion 3.0.2
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab

$notConverted = Get-DbcConfigValue -Name checks.notv5ready
[pscustomobject]@{
    Checks       = @(Get-DbcCheck).Count
    NotConverted = $notConverted.Count
} | Format-Table | Out-String
"Backups and CHECKDB among them: $(($notConverted | Where-Object { $_ -match 'Backup|CheckDb' }) -join ', ')"

# One check that is not converted: dbachecks warns and returns nothing.
$result = Invoke-DbcCheck -SqlInstance 'localhost,14533' -SqlCredential $credential `
    -Check LastFullBackup -Legacy:$false -PassThru -Show None
"LastFullBackup returns: $(if ($result) { $result.Result } else { 'nothing' })"

# The tag Backup: discovery finds tests, none of them runs, and the run passes.
$result = Invoke-DbcCheck -SqlInstance 'localhost,14533' -SqlCredential $credential `
    -Check Backup -Legacy:$false -PassThru -Show None
$result | Select-Object -Property Result, TotalCount, PassedCount, FailedCount, NotRunCount |
    Format-Table | Out-String
