# Clip 10.3: the result object of Pester 5, the names of its tests, a check that depends on
# the system that runs dbachecks, and a report in HTML. Run in a new process:
#     pwsh -NoProfile -File demos/module_10/05-result.ps1
param(
    # Where the HTML report goes; lab/ is not tracked by Git.
    [string] $ReportPath = (Join-Path $PSScriptRoot '..' '..' 'lab' 'reports' 'dbachecks.html')
)
$ErrorActionPreference = 'Stop'
Import-Module -Name Pester -RequiredVersion 5.9.1
Import-Module -Name dbachecks -RequiredVersion 3.0.2
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab

$result = Invoke-DbcCheck -SqlInstance 'localhost,14533', 'localhost,14534' -SqlCredential $credential `
    -Check RecoveryModel, ValidDatabaseOwner, InstanceConnection `
    -ConfigFile (Join-Path $PSScriptRoot 'pachadata.dbachecks.json') -Legacy:$false -PassThru -Show None
$result.GetType().FullName
$result | Select-Object -Property Result, TotalCount, PassedCount, FailedCount, SkippedCount, NotRunCount |
    Format-Table | Out-String

# Name is the template of the It block; ExpandedName is filled in for the tests that ran.
$result.Tests | Where-Object -Property Result -EQ 'Failed' | Select-Object -First 1 |
    Format-List -Property Name, ExpandedName, Result | Out-String -Width 120
$result.Tests | Where-Object -Property Result -EQ 'NotRun' | Select-Object -First 1 |
    Format-List -Property Name, ExpandedName, Result | Out-String -Width 120

# Instance Connection, run from Linux: dbachecks only pings from Windows, and tests the
# remoting with WinRM.
$result.Tests | Where-Object { $_.Path[0] -eq 'Instance Connection' -and $_.Result -ne 'NotRun' } |
    Select-Object -Property Result, ExpandedName | Format-Table | Out-String -Width 120

# The report: the tests that ran, one line each, written by ConvertTo-Html.
New-Item -ItemType Directory -Path (Split-Path -Path $ReportPath) -Force | Out-Null
$result.Tests | Where-Object -Property Result -NE 'NotRun' |
    Select-Object -Property Result, @{ Name = 'Check'; Expression = { $_.Path[0] } },
        @{ Name = 'Test'; Expression = { $_.ExpandedName } } |
    ConvertTo-Html -Title 'dbachecks' -PreContent "<h1>dbachecks, $(Get-Date -Format 'yyyy-MM-dd HH:mm')</h1>" |
    Set-Content -Path $ReportPath
Get-Item -Path $ReportPath | Select-Object -Property Name, Length | Format-Table | Out-String
