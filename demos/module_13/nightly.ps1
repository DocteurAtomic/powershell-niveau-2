# ci: skip, because setup/run-checks.ps1 runs it through 02-run.ps1, after 01-setup.ps1.
<#
.SYNOPSIS
The evening task of the team (clip 13.1): the tests, the publication of what passed, the
compliance checks in their own processes, the report, the message to the team.

.DESCRIPTION
Runs, from the root of the clone, without a prompt, so that cron or the Task Scheduler can
start it:

1. the Pester 6.2.0 tests of tests/, in a pwsh process of their own;
2. when every test passed, build.ps1, which publishes the version of src/PachaOps to the
   team's repository, unless the repository already has that version;
3. dbachecks with Pester 5.9.1 (demos/module_10/02-dbachecks.ps1) and the backup rule of the
   team with Pester 6.2.0 (demos/module_10/06-team-tests.ps1), each in a pwsh process of its
   own, then the drift of each instance from its reference (demos/module_12);
4. an HTML report and a summary.json in lab/nightly/<date-time>, one line in
   lab/nightly/nightly.jsonl, and a message to the webhook of the team.

Exits with 1 when the run proves nothing: a test failed, a check ran no test, or a step threw.
A compliance check that fails is a finding of the report, not a failure of the task.

.EXAMPLE
pwsh -NoProfile -NonInteractive -File demos/module_13/nightly.ps1
#>
[CmdletBinding()]
param(
    # The team's repository, registered by Register-PSResourceRepository (module 4).
    [string] $Repository = 'PachaTeam',
    # The secret of the vault PachaOps that holds the address of the webhook (module 9).
    [string] $WebhookSecret = 'm13_team_webhook',
    # Where each run writes its folder, and the trace of every run.
    [string] $ResultPath = (Join-Path $PSScriptRoot '..' '..' 'lab' 'nightly')
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
# The child processes run the pwsh of this one: under cron, PATH is /usr/bin:/bin:/usr/sbin:/sbin,
# and pwsh alone could start another version, or none.
$pwsh = [System.Environment]::ProcessPath
$started = [datetime]::UtcNow
$run = Join-Path $ResultPath (Get-Date -Format 'yyyy-MM-dd-HHmmss')
New-Item -ItemType Directory -Path $run -Force | Out-Null
$problems = [System.Collections.Generic.List[string]]::new()
$summary = [ordered]@{
    Started   = $started.ToString('o')
    Computer  = [System.Environment]::MachineName
    Tests     = $null
    Version   = $null
    Publication = 'NotPublished'
    Checks    = @()
    Drift     = $null
    Problems  = $problems
}

# 1. The tests of the team, in a process of their own: Pester 6.2.0 is loaded there, not here.
try {
    $summary.Tests = & $pwsh -NoProfile -NonInteractive -Command {
        param($Path, $ResultFile)
        Import-Module -Name Pester -RequiredVersion 6.2.0
        $configuration = New-PesterConfiguration
        $configuration.Run.Path = $Path
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'None'
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputPath = $ResultFile
        $result = Invoke-Pester -Configuration $configuration
        [ordered]@{
            Executed = $result.PassedCount + $result.FailedCount
            Passed   = $result.PassedCount
            Failed   = $result.FailedCount
        }
    } -args (Join-Path $root 'tests'), (Join-Path $run 'testResults.xml')
    if ($summary.Tests.Executed -eq 0) { $problems.Add('the tests ran no test') }
    if ($summary.Tests.Failed -gt 0) { $problems.Add("$($summary.Tests.Failed) test(s) failed") }
}
catch {
    $problems.Add("the tests did not run: $($_.Exception.Message)")
}

# 2. The publication of what passed: the version of src/, built into out/ by build.ps1.
$summary.Version = "$((Import-PowerShellDataFile -Path (Join-Path $root 'src' 'PachaOps' 'PachaOps.psd1')).ModuleVersion)"
if ($problems.Count -eq 0) {
    try {
        if (Find-PSResource -Name PachaOps -Version $summary.Version -Repository $Repository -ErrorAction SilentlyContinue) {
            $summary.Publication = 'AlreadyPublished'
            "PachaOps $($summary.Version) is already in $Repository, nothing to publish"
        }
        else {
            & (Join-Path $root 'build.ps1') -Repository $Repository | Out-Null
            $summary.Publication = 'Published'
            "PachaOps $($summary.Version) published to $Repository"
        }
    }
    catch {
        $problems.Add("the publication failed: $($_.Exception.Message)")
    }
}
else {
    "PachaOps $($summary.Version) not published: $($problems -join '; ')"
}

# 3. The compliance checks, each in a pwsh process of its own, which writes its tests to JSON.
$tests = foreach ($script in '02-dbachecks.ps1', '06-team-tests.ps1') {
    $output = Join-Path $run "$script.json"
    & $pwsh -NoProfile -NonInteractive -File (Join-Path $root 'demos' 'module_10' $script) -OutputPath $output
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -Path $output)) {
        $problems.Add("$script failed (exit code $LASTEXITCODE)")
        continue
    }
    $check = Get-Content -Path $output -Raw | ConvertFrom-Json
    $summary.Checks += $check.Summary
    if ($check.Summary.Executed -eq 0) { $problems.Add("$script ran no test") }
    $check.Tests
}

# The drift of each instance from its reference in Git (module 12).
try {
    . (Join-Path $root 'demos' 'module_12' 'PachaConfiguration.ps1')
    Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
    $credential = Get-Secret -Vault PachaOps -Name sql-lab
    $references = Get-ChildItem -Path (Join-Path $root 'demos' 'module_12' 'reference') -Filter *.json
    $drift = @(Compare-PachaConfiguration -Path $references.FullName -SqlCredential $credential)
    $summary.Drift = $drift.Count
    ConvertTo-Json -InputObject $drift -Depth 3 | Set-Content -Path (Join-Path $run 'drift.json')
}
catch {
    $problems.Add("the drift was not read: $($_.Exception.Message)")
}

# 4. The report, the summary, the trace and the message to the team.
$failed = @($tests | Where-Object -Property Result -EQ 'Failed')
$verdict = if ($problems.Count) { 'FAILED' } else { 'OK' }
$tests | Sort-Object -Property @{ Expression = { $_.Result -eq 'Passed' } }, Source, Check, Test |
    Select-Object -Property Result, Source, Check, Test, Message |
    ConvertTo-Html -Title 'Nightly PachaData' -PreContent (
        "<h1>Nightly PachaData, $(Get-Date -Format 'yyyy-MM-dd HH:mm'): $verdict</h1>" +
        "<p>PachaOps $($summary.Version), tests $($summary.Tests.Passed) passed, $($summary.Tests.Failed) failed; " +
        "checks $(@($tests).Count), $($failed.Count) failed; drift $($summary.Drift)</p>" +
        "<p>$($problems -join '<br>')</p>") |
    Set-Content -Path (Join-Path $run 'report.html')

$lines = @(
    "Nightly PachaData, $(Get-Date -Format 'yyyy-MM-dd HH:mm'): $verdict"
    "Tests: $($summary.Tests.Passed) passed, $($summary.Tests.Failed) failed"
    "PachaOps $($summary.Version): $($summary.Publication)"
    "Checks: $(@($tests).Count) run, $($failed.Count) failed"
    "Drift: $($summary.Drift) difference(s)"
) + $problems
try {
    $uri = Get-Secret -Vault PachaOps -Name $WebhookSecret -AsPlainText
    $null = Invoke-RestMethod -Uri $uri -Method Post -ContentType 'application/json' `
        -Body (@{ text = $lines -join "`n" } | ConvertTo-Json) -MaximumRetryCount 2 -RetryIntervalSec 5
}
catch {
    $problems.Add("the message to the team was not sent: $($_.Exception.Message)")
    Write-Warning $problems[-1]
}

$summary.Ended = [datetime]::UtcNow.ToString('o')
$summary.ExitCode = [int] [bool] $problems.Count
$summary | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $run 'summary.json')
[ordered]@{
    Time     = $summary.Ended
    ExitCode = $summary.ExitCode
    Version  = $summary.Version
    Folder   = Split-Path -Path $run -Leaf
} | ConvertTo-Json -Compress | Add-Content -Path (Join-Path $ResultPath 'nightly.jsonl')
$lines
"Results: $(Resolve-Path -Path $run -Relative)"
exit $summary.ExitCode
