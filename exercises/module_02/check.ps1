<#
.SYNOPSIS
Checks the exercise of module 2.

.DESCRIPTION
Runs your tests of Get-ErrorLogSummary five times, each time in a separate pwsh process with
Pester 6.2.0, and reads their result object (-PassThru), not their text output. The first run
uses the version of the function from PachaOps 0.1.0 (versions/correct.ps1): every test must
pass, and there must be at least one. The four other runs use broken copies
(versions/broken-*.ps1): for each, at least one test must fail. Exits with 0 when all five
runs give what is expected, 1 otherwise, and says what is missing. With -Solution, checks the
tests of the solution folder.

.EXAMPLE
./exercises/module_02/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your tests.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$testFile = Join-Path $folder 'Get-ErrorLogSummary.Tests.ps1'
$errorLogPath = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'data' 'errorlog')).Path
$problems = [System.Collections.Generic.List[string]]::new()

$versions = [ordered]@{
    'correct'        = 'the version of PachaOps 0.1.0'
    'per-file'       = 'returns one object for the whole folder instead of one per file'
    'count'          = 'counts at most one matching line per file'
    'empty-file'     = 'throws on an empty file instead of returning Lines 0 and Matches 0'
    'missing-folder' = 'returns nothing, with a warning, when the folder does not exist'
}

# The child process: Pester 6.2.0, the tests run against one version of the function, and the
# result object written as JSON. Its text output is discarded.
$runner = {
    param($TestFile, $ModulePath, $ErrorLogPath, $ResultPath)
    $WarningPreference = 'SilentlyContinue'
    Import-Module -Name Pester -RequiredVersion 6.2.0
    $configuration = New-PesterConfiguration
    $configuration.Run.Container = New-PesterContainer -Path $TestFile -Data @{
        ModulePath = $ModulePath; ErrorLogPath = $ErrorLogPath
    }
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'None'
    $result = Invoke-Pester -Configuration $configuration
    [pscustomobject]@{
        Result          = "$($result.Result)"
        TotalCount      = $result.TotalCount
        PassedCount     = $result.PassedCount
        FailedCount     = $result.FailedCount
        FailedBlocks    = $result.FailedBlocksCount
        FailedContainers = $result.FailedContainersCount
        Failed          = @($result.Failed.ExpandedName)
    } | ConvertTo-Json | Set-Content -Path $ResultPath
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-02-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
    if (-not (Test-Path -Path $testFile)) {
        $problems.Add("$testFile does not exist.")
    }
    else {
        foreach ($name in $versions.Keys) {
            # A module named PachaOps that contains only this version of Get-ErrorLogSummary.
            $modulePath = Join-Path $work $name 'PachaOps.psm1'
            New-Item -ItemType Directory -Path (Split-Path $modulePath) | Out-Null
            $source = if ($name -eq 'correct') { 'correct.ps1' } else { "broken-$name.ps1" }
            Copy-Item -Path (Join-Path $PSScriptRoot 'versions' $source) -Destination $modulePath
            $resultPath = Join-Path $work "$name.json"
            & pwsh -NoProfile -Command $runner -args $testFile, $modulePath, $errorLogPath, $resultPath *> $null
            if (-not (Test-Path -Path $resultPath)) {
                $problems.Add("The tests did not run against the $name version (pwsh exit code $LASTEXITCODE).")
                continue
            }
            $run = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
            if ($run.FailedContainers -gt 0 -or $run.FailedBlocks -gt 0) {
                $problems.Add("Against the $name version, the test file itself fails (discovery or a BeforeAll): run it with Invoke-Pester -Output Detailed to see the error.")
            }
            elseif ($name -eq 'correct') {
                if ($run.TotalCount -eq 0) { $problems.Add('The test file has no test.') }
                elseif ($run.FailedCount -gt 0) {
                    $problems.Add("Against $($versions[$name]), $($run.FailedCount) test(s) fail: $($run.Failed -join '; '). A test must pass on a function that works.")
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
'OK    module 2: the tests pass on the working version and catch the four broken ones.'
exit 0
