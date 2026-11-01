<#
.SYNOPSIS
Runs the audit of the instances: dbachecks with the configuration of the team, and the
CHECKDB rule of the team, each in a process of its own, then writes one report.

.DESCRIPTION
The runners of module 10 do the work: demos/module_10/02-dbachecks.ps1 (Pester 5.9.1) runs
the checks InstanceConnection and DAC with your configuration file, and
demos/module_10/06-team-tests.ps1 (Pester 6.2.0) runs your test file. This script loads no
Pester itself.

Both runners check the two instances of the lab, localhost,14533 and localhost,14534.
It writes the tests of both runs to -ResultPath (JSON, read by check.ps1) and to an HTML
report, then fails when one of the runs ran no test.

.EXAMPLE
./exercises/module_10/run-audit.ps1
#>
[CmdletBinding()]
param(
    [string] $ConfigFile = (Join-Path $PSScriptRoot 'pachadata-instance.dbachecks.json'),
    [string] $TestPath = (Join-Path $PSScriptRoot 'LastGoodCheckDb.Tests.ps1'),
    [string] $ResultPath = (Join-Path $PSScriptRoot '..' '..' 'lab' 'reports' 'audit-instances.json'),
    [string] $ReportPath = (Join-Path $PSScriptRoot '..' '..' 'lab' 'reports' "audit-instances-$(Get-Date -Format 'yyyy-MM-dd').html")
)
$ErrorActionPreference = 'Stop'
$demos = Join-Path $PSScriptRoot '..' '..' 'demos' 'module_10'
$work = Join-Path ([System.IO.Path]::GetTempPath()) "m10-run-audit-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
$runs = [ordered]@{}
try {
    $runners = [ordered]@{
        dbachecks = @{ Script = '02-dbachecks.ps1'; Arguments = @('-Check', 'InstanceConnection,DAC', '-ConfigFile', $ConfigFile) }
        team      = @{ Script = '06-team-tests.ps1'; Arguments = @('-TestPath', $TestPath) }
    }
    foreach ($name in $runners.Keys) {
        $output = Join-Path $work "$name.json"
        $runner = $runners[$name]
        & pwsh -NoProfile -File (Join-Path $demos $runner.Script) -OutputPath $output @($runner.Arguments)
        $runs[$name] = if ($LASTEXITCODE -eq 0 -and (Test-Path -Path $output)) {
            Get-Content -Path $output -Raw | ConvertFrom-Json
        }
        else {
            [pscustomobject]@{ Summary = [pscustomobject]@{ Executed = 0; Error = "$($runner.Script) failed (exit code $LASTEXITCODE)" }; Tests = @() }
        }
    }
}
finally {
    Remove-Item -Path $work -Recurse -Force
}

foreach ($path in $ResultPath, $ReportPath) {
    New-Item -ItemType Directory -Path (Split-Path -Path $path) -Force | Out-Null
}
$runs | ConvertTo-Json -Depth 5 | Set-Content -Path $ResultPath
$tests = @($runs.Values.Tests)
$tests | Sort-Object -Property @{ Expression = { $_.Result -eq 'Passed' } }, Source, Check, Test |
    Select-Object -Property Result, Source, Check, Test, Message |
    ConvertTo-Html -Title 'Audit of the instances' `
        -PreContent "<h1>Audit of the instances, $(Get-Date -Format 'yyyy-MM-dd HH:mm')</h1>" |
    Set-Content -Path $ReportPath
foreach ($name in $runs.Keys) {
    $summary = $runs[$name].Summary
    "{0,-10} {1} executed, {2} passed, {3} failed, {4} skipped" -f $name, $summary.Executed, $summary.Passed, $summary.Failed, $summary.Skipped
}
"Report: $ReportPath"
$empty = @($runs.Keys | Where-Object { $runs[$_].Summary.Executed -eq 0 })
if ($empty) { throw "No test ran in: $($empty -join ', '). A check that counts nothing proves nothing." }
