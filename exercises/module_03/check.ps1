<#
.SYNOPSIS
Checks the exercise of module 3.

.DESCRIPTION
Runs your tests of Remove-OldBackup four times, each time in a separate pwsh process with
Pester 6.2.0, and reads their result object (-PassThru), not their text output. The first run
uses the function of PachaOps (versions/correct.ps1): every test must pass, and there must be
at least one. The three other runs use broken copies (versions/broken-*.ps1): for each, at
least one test must fail. Exits with 0 when all four runs give what is expected, 1 otherwise,
and says what is missing. With -Solution, checks the tests of the solution folder.

Your test file is copied into a temporary folder and run from there, so that a test that
forgets -ModuleName, or that points at lab/backups, removes nothing in your clone.

.EXAMPLE
./exercises/module_03/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your tests.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$testFile = Join-Path $folder 'Remove-OldBackup.Tests.ps1'
$backupAge = Join-Path $PSScriptRoot '..' '..' 'src' 'PachaOps' 'Public' 'Get-BackupAge.ps1'
$problems = [System.Collections.Generic.List[string]]::new()

$versions = [ordered]@{
    'correct'     = 'the version of PachaOps'
    'recent'      = 'also removes the recent backups'
    'other-files' = 'also removes the files that are not backups'
    'whatif'      = 'removes the files even with -WhatIf'
}

# The child process: Pester 6.2.0, the tests run against one version of the function, from a
# throwaway folder, and the result object written as JSON. Its text output is discarded.
$runner = {
    param($TestFile, $ModulePath, $WorkPath, $ResultPath)
    $WarningPreference = 'SilentlyContinue'
    Set-Location -Path $WorkPath
    Import-Module -Name Pester -RequiredVersion 6.2.0
    $configuration = New-PesterConfiguration
    $configuration.Run.Container = New-PesterContainer -Path $TestFile -Data @{ ModulePath = $ModulePath }
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'None'
    $result = Invoke-Pester -Configuration $configuration
    [pscustomobject]@{
        Result           = "$($result.Result)"
        TotalCount       = $result.TotalCount
        PassedCount      = $result.PassedCount
        FailedCount      = $result.FailedCount
        FailedBlocks     = $result.FailedBlocksCount
        FailedContainers = $result.FailedContainersCount
        Failed           = @($result.Failed.ExpandedName)
    } | ConvertTo-Json | Set-Content -Path $ResultPath
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-03-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
    if (-not (Test-Path -Path $testFile)) {
        $problems.Add("$testFile does not exist.")
    }
    else {
        foreach ($name in $versions.Keys) {
            # A throwaway clone for this run: the test file at its place, nothing else. A path
            # such as lab/backups or $PSScriptRoot/../../lab/backups leads to an empty folder.
            $clone = Join-Path $work $name 'clone'
            $copy = Join-Path $clone 'exercises' 'module_03' 'Remove-OldBackup.Tests.ps1'
            New-Item -ItemType Directory -Path (Split-Path $copy) | Out-Null
            Copy-Item -Path $testFile -Destination $copy
            # A module named PachaOps with Get-BackupAge and this version of Remove-OldBackup.
            $modulePath = Join-Path $work $name 'PachaOps' 'PachaOps.psm1'
            New-Item -ItemType Directory -Path (Split-Path $modulePath) | Out-Null
            $source = if ($name -eq 'correct') { 'correct.ps1' } else { "broken-$name.ps1" }
            Get-Content -Path $backupAge, (Join-Path $PSScriptRoot 'versions' $source) |
                Set-Content -Path $modulePath
            $resultPath = Join-Path $work "$name.json"
            & pwsh -NoProfile -Command $runner -args $copy, $modulePath, $clone, $resultPath *> $null
            if (-not (Test-Path -Path $resultPath)) {
                $problems.Add("The tests did not run against the $name version (pwsh exit code $LASTEXITCODE).")
                continue
            }
            $run = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
            if ($run.FailedContainers -gt 0 -or $run.FailedBlocks -gt 0) {
                $problems.Add("Against the $name version, the test file itself fails (discovery, a BeforeAll or an AfterAll): run it with Invoke-Pester -Output Detailed to see the error.")
            }
            elseif ($name -eq 'correct') {
                if ($run.TotalCount -eq 0) { $problems.Add('The test file has no test.') }
                elseif ($run.FailedCount -gt 0) {
                    $problems.Add("Against $($versions[$name]), $($run.FailedCount) test(s) fail: $($run.Failed -join '; '). A test must pass on a function that works; is the mock injected with -ModuleName PachaOps?")
                }
            }
            elseif ($run.FailedCount -eq 0) {
                $problems.Add("Your $($run.TotalCount) test(s) pass against a broken version that $($versions[$name]). Write the test that catches it.")
            }
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
'OK    module 3: the tests pass on the working version and catch the three broken ones.'
exit 0
