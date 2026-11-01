<#
.SYNOPSIS
Runs a rule that the team writes in Pester 6, by default the backup rule
LastFullBackup.Tests.ps1, in a process of its own, with Pester 6.2.0 (clip 10.4).

.DESCRIPTION
The same shape as 02-dbachecks.ps1, for the tests that the team writes in Pester 6. The
test file takes two parameters, -SqlInstance and -SqlCredential, which this script passes:

    pwsh -NoProfile -File demos/module_10/06-team-tests.ps1

Without -OutputPath, it shows the summary and the tests. With -OutputPath, it writes them to
a JSON file, in the same form as 02-dbachecks.ps1, so that one report can hold both.
#>
[CmdletBinding()]
param(
    [string[]] $SqlInstance = @('localhost,14533', 'localhost,14534'),
    [string] $TestPath = (Join-Path $PSScriptRoot 'LastFullBackup.Tests.ps1'),
    [string] $OutputPath
)
$ErrorActionPreference = 'Stop'
Import-Module -Name Pester -RequiredVersion 6.2.0
Import-Module -Name dbatools
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab

$configuration = New-PesterConfiguration
$configuration.Run.Container = New-PesterContainer -Path $TestPath -Data @{
    SqlInstance   = $SqlInstance
    SqlCredential = $credential
}
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'None'
$result = Invoke-Pester -Configuration $configuration
if ($result.FailedContainersCount -gt 0) {
    throw "The test file failed before its tests ran: $($result.Containers[0].ErrorRecord[0].Exception.Message)"
}

$tests = foreach ($test in $result.Tests | Where-Object -Property Result -NE 'NotRun') {
    [pscustomobject]@{
        Source  = 'team'
        Check   = $test.Path[0]
        Test    = $test.ExpandedName
        Result  = "$($test.Result)"
        Message = if ($test.ErrorRecord) { $test.ErrorRecord[0].Exception.Message -replace '\s+', ' ' }
    }
}
$summary = [pscustomobject]@{
    Source   = 'team'
    Pester   = "$((Get-Module -Name Pester).Version)"
    Total    = $result.TotalCount
    Executed = $result.PassedCount + $result.FailedCount
    Passed   = $result.PassedCount
    Failed   = $result.FailedCount
    Skipped  = $result.SkippedCount
    NotRun   = $result.NotRunCount
}

if ($OutputPath) {
    [pscustomobject]@{ Summary = $summary; Tests = @($tests) } |
        ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath
}
else {
    $summary | Format-Table | Out-String -Width 120
    $tests | Format-Table -Property Result, Test | Out-String -Width 120
    $tests | Where-Object -Property Result -EQ 'Failed' | Group-Object -Property Message -NoElement |
        Format-Table -Property Count, Name -Wrap | Out-String -Width 120
}
