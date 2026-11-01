# Clip 13.2: what the team reads in the morning, from what the evening task left: the trace of
# the last runs, the summary of the last one, the version in the team's repository, the checks
# that failed, the drift, and the message that the webhook received.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
$nightly = Join-Path $root 'lab' 'nightly'

# The trace: one line per run, written last, even when a step failed.
$trace = Get-Content -Path (Join-Path $nightly 'nightly.jsonl') | ConvertFrom-Json
$trace | Select-Object -Last 3 | Format-Table | Out-String
$last = $trace[-1]
"Last run: $(([datetime]::UtcNow - $last.Time.ToUniversalTime()).ToString('hh\:mm')) ago, exit code $($last.ExitCode)"

# The summary of the last run.
$folder = Join-Path $nightly $last.Folder
$summary = Get-Content -Path (Join-Path $folder 'summary.json') -Raw | ConvertFrom-Json
$summary | Select-Object -Property Version, Publication, Drift, ExitCode, Problems | Format-List | Out-String
$summary.Tests | Format-Table | Out-String
$summary.Checks | Format-Table -Property Source, Pester, Total, Executed, Passed, Failed | Out-String

# The version that the team installs.
Find-PSResource -Name PachaOps -Repository PachaTeam -Version '*' |
    Select-Object -Property Name, Version, Repository | Format-Table | Out-String

# The checks that failed, grouped by check, from the files that the report was made from.
$tests = foreach ($file in Get-ChildItem -Path $folder -Filter *.ps1.json) {
    (Get-Content -Path $file.FullName -Raw | ConvertFrom-Json).Tests
}
$tests | Where-Object -Property Result -EQ 'Failed' | Group-Object -Property Source, Check -NoElement |
    Format-Table -Property Count, Name | Out-String

# The drift, nothing when every instance is like its reference.
Get-Content -Path (Join-Path $folder 'drift.json') -Raw | ConvertFrom-Json | Format-Table | Out-String

# The message, as the webhook of the team received it.
$received = Get-Content -Path (Join-Path $root 'lab' 'webhook' 'received.jsonl') |
    Select-String -Pattern 'Nightly PachaData' -SimpleMatch | Select-Object -Last 1
($received.Line | ConvertFrom-Json).body | ConvertFrom-Json | Select-Object -ExpandProperty text
