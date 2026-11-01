<#
.SYNOPSIS
Checks the exercise of module 7.

.DESCRIPTION
Runs Get-BackupCheck, the sequential reference, and your Get-BackupCheckParallel on the
inventory of the lab, each in a new pwsh process, so that nothing the first run loaded or
remembered shortens the second one. Then it checks that your function returns the same
objects, sorted by instance and database (the order of a parallel loop is not the order of
its input), and that it runs three instances at a time.

The duration is not compared with a number of seconds, which depends on the machine. The four
.example instances of the inventory do not answer, and each attempt waits for its timeout:
one after the other, that is four waits; three at a time, two waves of waits; four or more at
a time, one wave. The check compares the duration of your function with the duration of the
reference measured in the same run: under 40 % of it means more than three at a time, over
80 % means not in parallel. Takes about a minute and a half. Exits with 0 when everything is
right, 1 otherwise, and says what is missing. With -Solution, checks the solution folder.

.EXAMPLE
./exercises/module_07/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your file.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$candidate = Join-Path $folder 'Get-BackupCheckParallel.ps1'
$reference = Join-Path $PSScriptRoot 'Get-BackupCheck.ps1'
$inventory = Join-Path $PSScriptRoot '..' '..' 'data' 'instances.csv'
$problems = [System.Collections.Generic.List[string]]::new()

# Run in a child process: loads one file, prepares the session as a script of the team does,
# times the function alone, and writes what it found as JSON.
$runner = @'
param($ScriptPath, $FunctionName, $InventoryPath, $ResultPath)
$ErrorActionPreference = 'Stop'
$result = [ordered]@{ Error = $null; Seconds = $null; HasThrottleLimit = $false; Rows = @() }
try {
    . $ScriptPath
    $command = Get-Command -Name $FunctionName -CommandType Function -ErrorAction SilentlyContinue
    if (-not $command) { throw "$ScriptPath does not define the function $FunctionName." }
    $result.HasThrottleLimit = $command.Parameters.ContainsKey('ThrottleLimit') -and
        $command.Parameters['ThrottleLimit'].ParameterType -eq [int]
    Import-Module -Name dbatools
    Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
    $credential = Get-Secret -Vault PachaOps -Name sql-lab
    $rows = $null
    $elapsed = Measure-Command {
        $rows = & $FunctionName -InventoryPath $InventoryPath -SqlCredential $credential 3> $null
    }
    $result.Seconds = [math]::Round($elapsed.TotalSeconds, 1)
    $result.Rows = @($rows | ForEach-Object {
        [ordered]@{
            Instance       = [string] $_.Instance
            Database       = [string] $_.Database
            LastFullBackup = if ($_.LastFullBackup) { ([datetime] $_.LastFullBackup).ToString('o') } else { '' }
            LastLogBackup  = if ($_.LastLogBackup) { ([datetime] $_.LastLogBackup).ToString('o') } else { '' }
            Status         = [string] $_.Status
        }
    })
}
catch {
    $result.Error = $_.Exception.Message
}
$result | ConvertTo-Json -Depth 4 | Set-Content -Path $ResultPath
'@
$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module07-$PID"
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    $runnerPath = Join-Path $work 'runner.ps1'
    Set-Content -Path $runnerPath -Value $runner
    function Invoke-Run ([string] $ScriptPath, [string] $FunctionName) {
        $resultPath = Join-Path $work "$FunctionName.json"
        & pwsh -NoProfile -File $runnerPath -ScriptPath $ScriptPath -FunctionName $FunctionName -InventoryPath $inventory -ResultPath $resultPath *> $null
        if (-not (Test-Path -Path $resultPath)) { return [pscustomobject]@{ Error = "the run of $FunctionName wrote no result (exit $LASTEXITCODE)."; Rows = @() } }
        Get-Content -Path $resultPath -Raw | ConvertFrom-Json
    }

    "Running Get-BackupCheck, the reference, one instance after the other..."
    $expected = Invoke-Run -ScriptPath $reference -FunctionName Get-BackupCheck
    if ($expected.Error) {
        "FAIL  The reference does not run: $($expected.Error)"
        exit 1
    }
    if (-not ($expected.Rows | Where-Object -Property Status -NE 'Unreachable')) {
        "FAIL  The reference reached no instance of the lab: start it, then run setup/test-lab.ps1."
        exit 1
    }
    "Running Get-BackupCheckParallel..."
    $actual = Invoke-Run -ScriptPath $candidate -FunctionName Get-BackupCheckParallel
    if ($actual.Error) {
        "FAIL  Get-BackupCheckParallel does not run: $($actual.Error)"
        exit 1
    }
    if (-not $actual.HasThrottleLimit) {
        $problems.Add('Get-BackupCheckParallel has no [int] parameter ThrottleLimit.')
    }

    # The same objects, in any order.
    $key = { '{0} | {1} | full {2} | log {3} | {4}' -f $_.Instance, $_.Database, $_.LastFullBackup, $_.LastLogBackup, $_.Status }
    $want = @($expected.Rows | ForEach-Object $key | Sort-Object)
    $got = @($actual.Rows | ForEach-Object $key | Sort-Object)
    foreach ($difference in Compare-Object -ReferenceObject $want -DifferenceObject $got) {
        if ($difference.SideIndicator -eq '<=') { $problems.Add("Missing object: $($difference.InputObject)") }
        else { $problems.Add("Object that Get-BackupCheck does not return: $($difference.InputObject)") }
    }
    if ($got.Count -ne $want.Count) {
        $problems.Add("Get-BackupCheckParallel returns $($got.Count) objects; Get-BackupCheck returns $($want.Count).")
    }

    # Three at a time, measured against the reference of this run.
    $ratio = $actual.Seconds / $expected.Seconds
    $times = "{0} s against {1} s for the reference, {2:P0}" -f $actual.Seconds, $expected.Seconds, $ratio
    if ($ratio -gt 0.8) {
        $problems.Add("Get-BackupCheckParallel does not run in parallel: $times.")
    }
    elseif ($ratio -lt 0.4) {
        $problems.Add("Get-BackupCheckParallel runs more than three instances at a time: $times. The team wants three.")
    }
    else {
        "Durations: $times."
    }
}
finally {
    Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
}

if ($problems.Count) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
"OK    Get-BackupCheckParallel returns the $($want.Count) objects of Get-BackupCheck, three instances at a time."
exit 0
