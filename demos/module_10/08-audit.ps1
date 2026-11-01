<#
.SYNOPSIS
The request of the audit (clip 10.4): the rules of the team checked on both instances, one
report.

.DESCRIPTION
Runs dbachecks with Pester 5.9.1 (02-dbachecks.ps1) and the backup rule with Pester 6.2.0
(06-team-tests.ps1), each in a pwsh process of its own, reads the two JSON files they
write, and writes one HTML report. Fails when one of them ran no test: a check that counts
nothing proves nothing. This script loads no Pester itself, so it can run anywhere.
#>
param(
    [string] $ReportPath = (Join-Path $PSScriptRoot '..' '..' 'lab' 'reports' "audit-$(Get-Date -Format 'yyyy-MM-dd').html")
)
$ErrorActionPreference = 'Stop'
$work = Join-Path ([System.IO.Path]::GetTempPath()) "m10-audit-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $runs = foreach ($script in '02-dbachecks.ps1', '06-team-tests.ps1') {
        $output = Join-Path $work "$script.json"
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot $script) -OutputPath $output
        if ($LASTEXITCODE -ne 0) { throw "$script failed (exit code $LASTEXITCODE)." }
        $run = Get-Content -Path $output -Raw | ConvertFrom-Json
        if ($run.Summary.Executed -eq 0) { throw "$script ran no test: the audit proves nothing." }
        $run
    }
}
finally {
    Remove-Item -Path $work -Recurse -Force
}

$tests = $runs.Tests
$runs.Summary | Format-Table -Property Source, Pester, Total, Executed, Passed, Failed, Skipped | Out-String
$tests | Group-Object -Property Source, Result -NoElement | Format-Table -Property Count, Name | Out-String

New-Item -ItemType Directory -Path (Split-Path -Path $ReportPath) -Force | Out-Null
$tests | Sort-Object -Property @{ Expression = { $_.Result -eq 'Passed' } }, Source, Check, Test |
    Select-Object -Property Result, Source, Check, Test, Message |
    ConvertTo-Html -Title 'Audit PachaData' `
        -PreContent "<h1>Audit PachaData, $(Get-Date -Format 'yyyy-MM-dd HH:mm')</h1><p>$(@($tests).Count) tests, $(@($tests | Where-Object -Property Result -EQ 'Failed').Count) failed</p>" |
    Set-Content -Path $ReportPath
"Report: $((Resolve-Path -Path $ReportPath -Relative))"
