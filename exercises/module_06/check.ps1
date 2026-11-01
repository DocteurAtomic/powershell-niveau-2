<#
.SYNOPSIS
Checks the exercise of module 6.

.DESCRIPTION
Loads your BackupFile.psm1 by using module in a separate pwsh process, so that a class left
in your session by an earlier version does not count, and checks the objects it builds:
the enumeration BackupType and its three names, the typed properties of BackupFile, the type
read from the name of a file, the error on a file that is not a backup, and IsOlderThan around
seven days, with a reference date in UTC and in local time. On Linux and macOS, the checks of
the age run twice, in Paris and in New York (TZ), so that a mix of UTC and local time shows on
any machine. Exits with 0 when everything is right, 1 otherwise, and says what is missing.
With -Solution, checks the solution folder.

.EXAMPLE
./exercises/module_06/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your file.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$modulePath = Join-Path $folder 'BackupFile.psm1'
$problems = [System.Collections.Generic.List[string]]::new()

# The checks, run in the child process after the using module line. They write the list of
# problems as JSON; their text output is discarded.
$body = @'
param($ResultPath, $WorkPath)
$ErrorActionPreference = 'Stop'
$found = [System.Collections.Generic.List[string]]::new()
function Get-Type ([string] $Name) { $Name -as [type] }

$enum = Get-Type 'BackupType'
$class = Get-Type 'BackupFile'
if (-not $enum -or -not $enum.IsEnum) {
    $found.Add('BackupType is not an enumeration of the module (enum BackupType { ... }).')
}
else {
    $names = @($enum.GetEnumNames() | Sort-Object)
    if (($names -join ',') -ne 'Differential,Full,Log') {
        $found.Add("BackupType has the names $($names -join ', '); the team expects Full, Differential and Log.")
    }
}
if (-not $class) {
    $found.Add('BackupFile is not a class of the module (class BackupFile { ... }).')
}
if ($found.Count -eq 0) {
    $expected = [ordered]@{
        FullName         = ([string])
        Database         = ([string])
        Type             = $enum
        Length           = ([long])
        LastWriteTimeUtc = ([datetime])
    }
    foreach ($name in $expected.Keys) {
        $property = $class.GetProperty($name)
        if (-not $property) { $found.Add("BackupFile has no property $name.") }
        elseif ($property.PropertyType -ne $expected[$name]) {
            $found.Add("The property $name of BackupFile is a [$($property.PropertyType.Name)], not a [$($expected[$name].Name)].")
        }
    }
}
if ($found.Count -eq 0) {
    $cases = @(
        @{ Name = 'sql1_Finance_FULL_20261101_010000.bak'; Database = 'Finance'; Type = 'Full'; Length = 2048 }
        @{ Name = 'sql1_Planning_DIFF_20261030_010000.bak'; Database = 'Planning'; Type = 'Differential'; Length = 512 }
        @{ Name = 'sql1_PachadataTraining_LOG_20261102_060000.trn'; Database = 'PachadataTraining'; Type = 'Log'; Length = 0 }
    )
    foreach ($case in $cases) {
        $path = Join-Path $WorkPath $case.Name
        $stream = [System.IO.File]::Create($path)
        $stream.SetLength($case.Length)
        $stream.Dispose()
        try { $backup = $class::new((Get-Item -LiteralPath $path)) }
        catch { $found.Add("[BackupFile]::new() fails on $($case.Name): $($_.Exception.Message)"); continue }
        if ($backup.Type -ne $case.Type) { $found.Add("$($case.Name) gives the type '$($backup.Type)'; expected $($case.Type).") }
        if ($backup.Database -ne $case.Database) { $found.Add("$($case.Name) gives the database '$($backup.Database)'; expected $($case.Database).") }
        if ($backup.Length -ne $case.Length) { $found.Add("$($case.Name) gives the length $($backup.Length); expected $($case.Length).") }
        if ($backup.FullName -ne (Get-Item -LiteralPath $path).FullName) { $found.Add("$($case.Name) gives the FullName '$($backup.FullName)'; expected the path of the file.") }
    }
    $note = Join-Path $WorkPath 'README-restore.txt'
    Set-Content -Path $note -Value 'Restore the Finance backups on sql2 only.'
    $made = $null
    try { $made = $class::new((Get-Item -LiteralPath $note)) } catch { $made = $null }
    if ($made) { $found.Add('[BackupFile]::new() accepts README-restore.txt, which is not a backup: it must throw.') }
    $one = $class::new((Get-Item -LiteralPath (Join-Path $WorkPath $cases[0].Name)))
    $refused = $false
    try { $one.Type = 'Incremental' } catch { $refused = $true }
    if (-not $refused) { $found.Add("The property Type accepts 'Incremental': it must be a [BackupType].") }
}
if ($found.Count -eq 0) {
    # IsOlderThan(7, reference date), around seven days. The reference is 2 November 2026,
    # 08:00 UTC, given in UTC and in local time.
    $file = Get-Item -LiteralPath (Join-Path $WorkPath 'sql1_Finance_FULL_20261101_010000.bak')
    $reference = [datetime]::new(2026, 11, 2, 8, 0, 0, [System.DateTimeKind]::Utc)
    $ages = [ordered]@{ '8 days' = 8.0; '6 days' = 6.0; '7 days minus 30 minutes' = 7.0 - 1 / 48; '7 days plus 30 minutes' = 7.0 + 1 / 48 }
    foreach ($label in $ages.Keys) {
        $file.LastWriteTimeUtc = $reference.AddDays(-$ages[$label])
        $backup = $class::new($file)
        foreach ($given in @($reference, $reference.ToLocalTime())) {
            $kind = if ($given.Kind -eq 'Utc') { 'in UTC' } else { "in local time ($([System.TimeZoneInfo]::Local.Id))" }
            try { $answer = $backup.IsOlderThan(7, $given) }
            catch { $found.Add("IsOlderThan(7, date) fails: $($_.Exception.Message)"); break }
            $wanted = $ages[$label] -gt 7
            if ($answer -isnot [bool]) { $found.Add("IsOlderThan returns a [$($answer.GetType().Name)], not a [bool]."); break }
            if ($answer -ne $wanted) {
                $found.Add("A file written $label before the reference date, given $kind`: IsOlderThan(7, date) returns $answer, expected $wanted.")
            }
        }
    }
}
ConvertTo-Json -InputObject @($found) | Set-Content -Path $ResultPath
'@

$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-06-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
    if (-not (Test-Path -Path $modulePath)) {
        $problems.Add("$modulePath does not exist.")
    }
    else {
        $literal = (Resolve-Path -Path $modulePath).Path -replace "'", "''"
        $childPath = Join-Path $work 'child.ps1'
        Set-Content -Path $childPath -Value "using module '$literal'`n$body"
        # On Linux and macOS, TZ sets the time zone of the child process: the age checks run in
        # two zones, one east of UTC and one west. Windows ignores TZ: the zone of the machine.
        $zones = if ($IsWindows) { @($null) } else { @('Europe/Paris', 'America/New_York') }
        $saved = $env:TZ
        try {
            foreach ($zone in $zones) {
                $env:TZ = $zone
                $resultPath = Join-Path $work "result-$([guid]::NewGuid()).json"
                $data = Join-Path $work "files-$([guid]::NewGuid())"
                New-Item -ItemType Directory -Path $data | Out-Null
                $output = & pwsh -NoProfile -File $childPath -ResultPath $resultPath -WorkPath $data 2>&1
                if (-not (Test-Path -Path $resultPath)) {
                    $problems.Add("BackupFile.psm1 does not load or the checks stopped (pwsh exit code $LASTEXITCODE): $((($output | Select-Object -First 3) -join ' ') -replace '\e\[[0-9;]*m')")
                    break
                }
                foreach ($problem in @(Get-Content -Path $resultPath -Raw | ConvertFrom-Json)) {
                    if (-not $problems.Contains($problem)) { $problems.Add($problem) }
                }
            }
        }
        finally {
            $env:TZ = $saved
        }
        if ($IsWindows -and [System.TimeZoneInfo]::Local.BaseUtcOffset -eq [timespan]::Zero) {
            'NOTE  This machine is in UTC: a mix of UTC and local time in IsOlderThan does not show here.'
        }
    }
}
finally {
    Remove-Item -Path $work -Recurse -Force
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
'OK    module 6: BackupType and BackupFile build the objects the team expects.'
exit 0
