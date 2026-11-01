<#
.SYNOPSIS
Runs dbachecks in a process of its own, with Pester 5.9.1 (clips 10.1 to 10.4).

.DESCRIPTION
Pester 5.9.1 and 6.2.0 cannot be loaded in the same session, and dbachecks 3.0.2 only works
with Pester 5. This script imports Pester 5.9.1 first, then dbachecks, so it must run in a
new process:

    pwsh -NoProfile -File demos/module_10/02-dbachecks.ps1

It reads the credential from the vault PachaOps, passes the instances and the credential as
parameters (a configuration alone finds no test, clip 10.2), and loads the configuration of
the team from a file with -ConfigFile, which dbachecks imports for this run only.

-Check takes several checks separated by commas, also through pwsh -File. Without
-OutputPath, it shows the summary and the tests that ran. With -OutputPath, it writes
the tests that ran to a JSON file, for a process that cannot load Pester 5 (clip 10.4).
#>
[CmdletBinding()]
param(
    [string[]] $SqlInstance = @('localhost,14533', 'localhost,14534'),
    [string[]] $Check = @('RecoveryModel', 'ValidDatabaseOwner'),
    # The configuration of the team, a JSON file of Name and Value pairs.
    [string] $ConfigFile = (Join-Path $PSScriptRoot 'pachadata.dbachecks.json'),
    # Where to write the tests that ran, as JSON.
    [string] $OutputPath
)
$ErrorActionPreference = 'Stop'
# pwsh -File passes each argument as one string: -Check RecoveryModel,DAC arrives as one value.
$Check = $Check -split ','
Import-Module -Name Pester -RequiredVersion 5.9.1
Import-Module -Name dbachecks -RequiredVersion 3.0.2
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab

$parameters = @{
    SqlInstance   = $SqlInstance
    SqlCredential = $credential
    Check         = $Check
    Legacy        = $false
    PassThru      = $true
    Show          = 'None'
}
if ($ConfigFile) { $parameters.ConfigFile = $ConfigFile }
$result = Invoke-DbcCheck @parameters
if (-not $result) { throw "dbachecks returned nothing for the checks $($Check -join ', ')." }

# The tests that ran or were skipped. NotRun counts the tests that discovery found and the
# filter left out.
$tests = foreach ($test in $result.Tests | Where-Object -Property Result -NE 'NotRun') {
    [pscustomobject]@{
        Source  = 'dbachecks'
        Check   = $test.Path[0]
        Test    = $test.ExpandedName
        Result  = "$($test.Result)"
        Message = if ($test.ErrorRecord) { $test.ErrorRecord[0].Exception.Message -replace '\s+', ' ' }
    }
}
$summary = [pscustomobject]@{
    Source   = 'dbachecks'
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
    $tests | Format-Table -Property Result, Check, Test | Out-String -Width 120
}
