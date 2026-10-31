<#
.SYNOPSIS
Creates the fake backup files of the course under lab/backups.

.DESCRIPTION
Builds, for the instance sql1, a folder per database and per backup type (FULL, DIFF, LOG),
in the layout of Ola Hallengren's Maintenance Solution, with files dated over the six weeks
before the reference date. The files contain zeros: only their names, sizes and dates matter.
The same reference date always gives the same files. Run it again to start over: it empties
the content of lab/backups first.

.EXAMPLE
./setup/new-backupfiles.ps1

.EXAMPLE
./setup/new-backupfiles.ps1 -ReferenceDate 2026-11-02
#>
[CmdletBinding()]
param(
    # The day the files are generated for; today by default.
    [datetime] $ReferenceDate = (Get-Date).Date
)
$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..' 'lab' 'backups'
# The folder itself stays: the container pwshcourse-host mounts it (module 8).
New-Item -ItemType Directory -Force -Path $root | Out-Null
Get-ChildItem $root -Force | Remove-Item -Recurse -Force

$random = [System.Random]::new(20261102)
$databases = [ordered]@{
    # name = size of a full backup in KB, and whether it gets differential and log backups
    PachadataTraining = @{ FullKB = 4800; Diff = $true;  Log = $true }
    Planning          = @{ FullKB = 1900; Diff = $true;  Log = $false }
    Finance           = @{ FullKB = 2600; Diff = $false; Log = $false }
    DBA               = @{ FullKB = 150;  Diff = $false; Log = $false }
}

function New-FakeBackup ([string] $Database, [string] $Type, [datetime] $Date, [int] $SizeKB) {
    $ext = if ($Type -eq 'LOG') { 'trn' } else { 'bak' }
    $folder = Join-Path $root 'sql1' $Database $Type
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $name = 'sql1_{0}_{1}_{2:yyyyMMdd_HHmmss}.{3}' -f $Database, $Type, $Date, $ext
    $path = Join-Path $folder $name
    $stream = [System.IO.File]::Create($path)
    $stream.SetLength([int64]$SizeKB * 1024)
    $stream.Dispose()
    $item = Get-Item $path
    $item.CreationTime = $Date
    $item.LastWriteTime = $Date
    $item
}

$files = foreach ($day in 0..41) {
    $date = $ReferenceDate.AddDays(-$day).AddHours(1)
    foreach ($db in $databases.Keys) {
        $spec = $databases[$db]
        $jitter = 0.9 + $random.NextDouble() * 0.2
        if ($date.DayOfWeek -eq [System.DayOfWeek]::Sunday) {
            New-FakeBackup $db 'FULL' $date ([int]($spec.FullKB * $jitter))
        }
        elseif ($spec.Diff) {
            New-FakeBackup $db 'DIFF' $date ([int]($spec.FullKB * 0.04 * ($date.DayOfWeek.value__ + 1) * $jitter))
        }
    }
}
# Log backups of PachadataTraining every four hours over the last three days.
$logs = foreach ($hour in (0..17 | ForEach-Object { $_ * 4 })) {
    $date = $ReferenceDate.AddHours(-$hour - 2)
    New-FakeBackup 'PachadataTraining' 'LOG' $date (60 + $random.Next(0, 240))
}
# Two anomalies the course finds: a failed backup left empty, and a file that is not a backup.
$failed = New-FakeBackup 'Planning' 'DIFF' $ReferenceDate.AddDays(-3).AddHours(13) 0
$note = Join-Path $root 'sql1' 'Finance' 'FULL' 'README-restore.txt'
Set-Content -Path $note -Value 'Restore the Finance backups on sql2 only.'

$all = Get-ChildItem $root -Recurse -File
'{0} files, {1:N1} MB, under {2}' -f $all.Count, (($all | Measure-Object Length -Sum).Sum / 1MB), (Resolve-Path $root)
