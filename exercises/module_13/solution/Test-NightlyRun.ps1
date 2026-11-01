<#
.SYNOPSIS
Says in the morning whether the evening task proved what it should (exercise of module 13).

.DESCRIPTION
Reads what demos/module_13/nightly.ps1 left: the last line of nightly.jsonl, then the
summary.json of its folder, and the team's repository. Returns one object, with the time of
the last run, its folder, the version of PachaOps, the verdict (OK or FAILED) and the reasons
of a FAILED, and exits with 1 when the verdict is FAILED, so that a scheduler or a monitoring
tool can read it without parsing text.

The night proves nothing when: there is no run of less than -MaxAgeHours; the run exited with
a code other than 0; the tests ran no test or one of them failed; there is no check, or a
check ran no test; the version of the summary is not in the repository.

.EXAMPLE
./exercises/module_13/solution/Test-NightlyRun.ps1
#>
[CmdletBinding()]
param(
    # The folder where the evening task writes its runs and its trace.
    [string] $ResultPath = (Join-Path $PSScriptRoot '..' '..' '..' 'lab' 'nightly'),
    # The team's repository, where the version of the summary should be.
    [string] $Repository = 'PachaTeam',
    # A run older than this is not last night's.
    [double] $MaxAgeHours = 26
)
$ErrorActionPreference = 'Stop'
$problems = [System.Collections.Generic.List[string]]::new()
$result = [ordered]@{ Time = $null; Folder = $null; Version = $null; Verdict = $null; Problems = $problems }

$tracePath = Join-Path $ResultPath 'nightly.jsonl'
$last = if (Test-Path -Path $tracePath) {
    Get-Content -Path $tracePath | Where-Object { $_.Trim() } | Select-Object -Last 1 | ConvertFrom-Json
}
if (-not $last) {
    $problems.Add("no run of the evening task in $tracePath")
}
else {
    # ConvertFrom-Json reads the ISO 8601 time as a DateTime of kind Utc.
    $result.Time = $last.Time.ToUniversalTime()
    $result.Folder = $last.Folder
    $result.Version = $last.Version
    $age = ([datetime]::UtcNow - $result.Time).TotalHours
    if ($age -gt $MaxAgeHours) { $problems.Add("the last run is $([math]::Round($age)) hours old") }
    if ($last.ExitCode -ne 0) { $problems.Add("the last run exited with code $($last.ExitCode)") }

    $summaryPath = Join-Path $ResultPath $last.Folder 'summary.json'
    if (-not (Test-Path -Path $summaryPath)) {
        $problems.Add("no summary.json in $($last.Folder)")
    }
    else {
        $summary = Get-Content -Path $summaryPath -Raw | ConvertFrom-Json
        if (-not $summary.Tests -or $summary.Tests.Executed -eq 0) { $problems.Add('the tests ran no test') }
        elseif ($summary.Tests.Failed -gt 0) { $problems.Add("$($summary.Tests.Failed) test(s) failed") }
        if (-not $summary.Checks) { $problems.Add('no compliance check ran') }
        foreach ($check in $summary.Checks | Where-Object -Property Executed -EQ 0) {
            $problems.Add("the check $($check.Source) ran no test")
        }
        $published = Find-PSResource -Name PachaOps -Version $summary.Version -Repository $Repository -ErrorAction SilentlyContinue
        if (-not $published) { $problems.Add("PachaOps $($summary.Version) is not in the repository $Repository") }
    }
}

$result.Verdict = if ($problems.Count) { 'FAILED' } else { 'OK' }
[pscustomobject] $result
if ($problems.Count) { exit 1 }
