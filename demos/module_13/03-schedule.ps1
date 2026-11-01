# ci: skip, because it changes the crontab of the user, which a runner of the continuous
# integration should not do. Clip 13.1: the evening task planned by cron, on Linux.
# Every evening at -At, cron runs pwsh by its full path, from the root of the clone, without a
# profile and without a prompt, and keeps its output in lab/nightly/cron.log. cron starts the
# task with an almost empty environment (PATH is /usr/bin:/bin:/usr/sbin:/sbin, where pwsh may
# be another version): the entry sets HOME and PSModulePath as they are in this session, so
# that the task finds the same modules and the same vault. The lines of the entry sit between
# two marks; 99-cleanup.ps1 removes them.
param(
    # The time of the task, every day.
    [timespan] $At = '22:30'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
$pwsh = [System.Environment]::ProcessPath
$entry = @(
    '# m13_nightly begin: the evening task of the team (module 13)'
    "HOME=$HOME"
    "PSModulePath=$env:PSModulePath"
    "$($At.Minutes) $($At.Hours) * * * cd '$root' && '$pwsh' -NoProfile -NonInteractive -File demos/module_13/nightly.ps1 >> lab/nightly/cron.log 2>&1"
    '# m13_nightly end'
)
# crontab -l writes "no crontab for <user>" and exits with 1 when the user has none yet.
$current = @(& crontab -l 2>$null | Where-Object { $_ -notmatch '^# m13_nightly' })
if ($current -match 'm13_nightly') { throw 'An entry m13_nightly is already there: run 99-cleanup.ps1 first.' }
New-Item -ItemType Directory -Path (Join-Path $root 'lab' 'nightly') -Force | Out-Null
$current + $entry | & crontab -
if ($LASTEXITCODE -ne 0) { throw "crontab refused the entry (exit code $LASTEXITCODE)." }
& crontab -l
