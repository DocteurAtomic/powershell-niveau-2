# Clip 10.1: dbachecks in the session where the tests of the team run, with Pester 6.2.0.
# The default mode asks for Pester 4.10.1, which the course does not install; the Pester 5
# mode fails at discovery under Pester 6; and Pester 5.9.1 cannot be loaded next to 6.2.0.
# Nothing here throws: the failures are read from what the commands return.
Import-Module -Name Pester -RequiredVersion 6.2.0
Import-Module -Name dbachecks
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab

Get-Module -Name Pester, dbachecks | Select-Object -Property Name, Version | Format-Table | Out-String

# The Pester 5 mode, run by Pester 6: the test file fails at discovery, no test runs.
$result = Invoke-DbcCheck -SqlInstance 'localhost,14533' -SqlCredential $credential `
    -Check RecoveryModel -Legacy:$false -PassThru -Show None
$result | Select-Object -Property Result, TotalCount, PassedCount, FailedCount, FailedContainersCount |
    Format-List | Out-String
$result.Containers[0].ErrorRecord[0].Exception.Message

# Loading Pester 5.9.1 in the same session fails: one Pester.dll is already loaded.
try {
    Import-Module -Name Pester -RequiredVersion 5.9.1 -Force -ErrorAction Stop
}
catch {
    "Import-Module failed: $($_.Exception.Message)"
}
Get-Module -Name Pester | Select-Object -Property Name, Version | Format-Table | Out-String
