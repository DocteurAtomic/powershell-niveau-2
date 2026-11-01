<#
.SYNOPSIS
Checks the exercise of module 8.

.DESCRIPTION
Runs your Get-BackupShareUsage against pwshcourse-host, the backup server of the lab, in a new
pwsh process, then reads the same numbers on the server by its own remote command, and compares.
The object must say the name of the server, not the name of the workstation: the work is done
there. It must have exactly the properties ComputerName, Path, FileCount, BackupBytes,
VolumeSizeBytes and VolumeFreeBytes, without the properties that remoting adds, and the function
must leave no session open behind it.

The free space moves while the check runs (other programs write on the disk): it is compared
within 2 % of the size of the volume. Everything else must be equal. In the lab, the volume of
the server is the disk of your workstation, which the container shares: the folder size is the
number that tells the server from the workstation. Takes a few seconds. Exits with 0 when
everything is right, 1 otherwise, and says what is missing. With -Solution, checks the solution
folder.

.EXAMPLE
./exercises/module_08/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your file.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$candidate = Join-Path $folder 'Get-BackupShareUsage.ps1'
$key = Join-Path $PSScriptRoot '..' '..' 'lab' 'ssh' 'id_ed25519'
$ssh = @{ HostName = 'localhost'; Port = 14535; UserName = 'student'; KeyFilePath = $key }
$expectedProperties = 'ComputerName', 'Path', 'FileCount', 'BackupBytes', 'VolumeSizeBytes', 'VolumeFreeBytes'
$problems = [System.Collections.Generic.List[string]]::new()

# What the server says, read by the check itself.
try {
    $server = Invoke-Command @ssh -ErrorAction Stop -ScriptBlock {
        $files = Get-ChildItem -Path /srv/backups -Recurse -File | Measure-Object -Property Length -Sum
        $volume = [System.IO.DriveInfo]::new('/srv/backups')
        [pscustomobject]@{
            ComputerName    = [Environment]::MachineName
            FileCount       = $files.Count
            BackupBytes     = [long] $files.Sum
            VolumeSizeBytes = $volume.TotalSize
            VolumeFreeBytes = $volume.AvailableFreeSpace
        }
    }
}
catch {
    "FAIL  The check cannot reach pwshcourse-host: $($_.Exception.Message) Start the lab, then run setup/test-host.ps1."
    exit 1
}
if ($server.FileCount -lt 1) {
    "FAIL  pwshcourse-host sees no backup file in /srv/backups: run setup/new-backupfiles.ps1."
    exit 1
}

# Your function, in a child process: it dot-sources the file, calls the function on the server
# of the lab, and writes the object and the sessions left open as JSON.
$runner = @'
param($ScriptPath, $KeyFilePath, $ResultPath)
$ErrorActionPreference = 'Stop'
$result = [ordered]@{ Error = $null; Missing = @(); Properties = @(); Object = $null; OpenSessions = 0 }
try {
    . $ScriptPath
    $command = Get-Command -Name Get-BackupShareUsage -CommandType Function -ErrorAction SilentlyContinue
    if (-not $command) { throw "$ScriptPath does not define the function Get-BackupShareUsage." }
    $result.Missing = @('HostName', 'Port', 'UserName', 'KeyFilePath' | Where-Object { -not $command.Parameters.ContainsKey($_) })
    if (-not $result.Missing) {
        $usage = Get-BackupShareUsage -HostName localhost -Port 14535 -UserName student -KeyFilePath $KeyFilePath
        $result.Properties = @($usage | ForEach-Object { $_.PSObject.Properties.Name })
        $first = @($usage)[0]
        $result.Object = [ordered]@{
            Count           = @($usage).Count
            ComputerName    = [string] $first.ComputerName
            Path            = [string] $first.Path
            FileCount       = $first.FileCount
            BackupBytes     = $first.BackupBytes
            VolumeSizeBytes = $first.VolumeSizeBytes
            VolumeFreeBytes = $first.VolumeFreeBytes
        }
        $result.OpenSessions = @(Get-PSSession | Where-Object -Property State -EQ 'Opened').Count
    }
}
catch {
    $result.Error = $_.Exception.Message
}
$result | ConvertTo-Json -Depth 4 | Set-Content -Path $ResultPath
'@
$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module08-$PID"
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    $runnerPath = Join-Path $work 'runner.ps1'
    $resultPath = Join-Path $work 'result.json'
    Set-Content -Path $runnerPath -Value $runner
    & pwsh -NoProfile -File $runnerPath -ScriptPath $candidate -KeyFilePath $key -ResultPath $resultPath *> $null
    if (-not (Test-Path -Path $resultPath)) {
        "FAIL  The run of Get-BackupShareUsage wrote no result (exit $LASTEXITCODE)."
        exit 1
    }
    $actual = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
}
finally {
    Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
}

if ($actual.Error) {
    "FAIL  Get-BackupShareUsage does not run: $($actual.Error)"
    exit 1
}
if ($actual.Missing) {
    "FAIL  Get-BackupShareUsage has no parameter $($actual.Missing -join ', '): it cannot reach the server yet."
    exit 1
}
$object = $actual.Object
if ($object.Count -ne 1) { $problems.Add("Get-BackupShareUsage returns $($object.Count) objects; one is expected.") }
if ($object.ComputerName -ne $server.ComputerName) {
    $problems.Add("ComputerName is '$($object.ComputerName)'; the server is '$($server.ComputerName)'. The work is not done on the server.")
}
$extra = @($actual.Properties | Where-Object { $_ -notin $expectedProperties } | Select-Object -Unique)
$absent = @($expectedProperties | Where-Object { $_ -notin $actual.Properties })
if ($extra) { $problems.Add("Properties that do not belong to the object: $($extra -join ', ').") }
if ($absent) { $problems.Add("Missing properties: $($absent -join ', ').") }
if ($object.Path -ne '/srv/backups') { $problems.Add("Path is '$($object.Path)'; the backups of the server are in /srv/backups.") }
foreach ($name in 'FileCount', 'BackupBytes', 'VolumeSizeBytes') {
    if ([long] $object.$name -ne [long] $server.$name) {
        $problems.Add("$name is $($object.$name); the server says $($server.$name).")
    }
}
$tolerance = 0.02 * $server.VolumeSizeBytes
if ([math]::Abs([double] $object.VolumeFreeBytes - [double] $server.VolumeFreeBytes) -gt $tolerance) {
    $problems.Add("VolumeFreeBytes is $($object.VolumeFreeBytes); the server says about $($server.VolumeFreeBytes).")
}
if ($actual.OpenSessions -gt 0) {
    $problems.Add("Get-BackupShareUsage leaves $($actual.OpenSessions) session(s) open: close it with Remove-PSSession, in a finally block.")
}

if ($problems.Count) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
"OK    Get-BackupShareUsage reads $($server.FileCount) files, $($server.BackupBytes) bytes, on $($server.ComputerName)."
exit 0
