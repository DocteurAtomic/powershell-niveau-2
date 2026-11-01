<#
.SYNOPSIS
Checks the exercise of module 13.

.DESCRIPTION
Builds, in a temporary folder, the results of six nights of the evening task, in the form
that demos/module_13/nightly.ps1 writes them (nightly.jsonl, and summary.json in the folder of
each run), and a repository of its own, m13_check, where build.ps1 publishes PachaOps 0.2.0.
Then it runs your Test-NightlyRun.ps1 once per night, each time in a new pwsh process, with
-ResultPath and -Repository m13_check:

| Night                                      | Expected                 |
|--------------------------------------------|--------------------------|
| a good night, an hour ago                  | OK, exit code 0          |
| the same night, three days ago             | FAILED, exit code 1      |
| two tests failed, nothing published        | FAILED, exit code 1      |
| exit code 0, but dbachecks ran no test     | FAILED, exit code 1      |
| exit code 0, but 0.2.1 is not in the repository | FAILED, exit code 1 |
| no trace at all                            | FAILED, exit code 1      |

Each FAILED must come with at least one reason in Problems. Unregisters m13_check and removes
the temporary folder at the end, in a finally block. Needs no instance; takes about twenty
seconds. Exits with 0 when everything is right, 1 otherwise, and says what is missing. With
-Solution, checks the solution folder.

.EXAMPLE
./exercises/module_13/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your files.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$script = Join-Path $folder 'Test-NightlyRun.ps1'
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
$problems = [System.Collections.Generic.List[string]]::new()
$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-13-$([guid]::NewGuid())"
$repository = 'm13_check'

# Writes the results of one night into its own folder, in the form of nightly.ps1.
function Build-Night ([string] $Name, [datetime] $Time, [int] $ExitCode, [string] $Version = '0.2.0',
    [int] $TestsFailed = 0, [int] $DbachecksExecuted = 6, [string] $Publication = 'Published',
    [switch] $NoTrace) {
    $path = Join-Path $work $Name
    $run = Join-Path $path $Time.ToString('yyyy-MM-dd-HHmmss')
    New-Item -ItemType Directory -Path $run -Force | Out-Null
    if ($NoTrace) { return $path }
    [ordered]@{
        Started     = $Time.AddSeconds(-20).ToString('o')
        Computer    = 'backup01'
        Tests       = [ordered]@{ Executed = 11; Passed = 11 - $TestsFailed; Failed = $TestsFailed }
        Version     = $Version
        Publication = $Publication
        Checks      = @(
            [ordered]@{ Source = 'dbachecks'; Pester = '5.9.1'; Total = 200; Executed = $DbachecksExecuted; Passed = $DbachecksExecuted; Failed = 0; Skipped = 0; NotRun = 200 - $DbachecksExecuted }
            [ordered]@{ Source = 'team'; Pester = '6.2.0'; Total = 9; Executed = 9; Passed = 9; Failed = 0; Skipped = 0; NotRun = 0 }
        )
        Drift       = 0
        Problems    = @(if ($TestsFailed) { "$TestsFailed test(s) failed" })
        Ended       = $Time.ToString('o')
        ExitCode    = $ExitCode
    } | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $run 'summary.json')
    [ordered]@{ Time = $Time.ToString('o'); ExitCode = $ExitCode; Version = $Version; Folder = Split-Path -Path $run -Leaf } |
        ConvertTo-Json -Compress | Set-Content -Path (Join-Path $path 'nightly.jsonl')
    $path
}

# Runs Test-NightlyRun.ps1 in a new pwsh process, and returns its objects (values as text), its
# error and its exit code.
function Invoke-Morning ([string] $ResultPath) {
    $resultFile = Join-Path $work "result-$([guid]::NewGuid()).json"
    $runner = Join-Path $work 'runner.ps1'
    Set-Content -Path $runner -Value @'
param($ScriptPath, $ResultPath, $Repository, $ResultFile)
$result = [ordered]@{ Objects = @(); Error = $null; ExitCode = 0 }
try {
    $result.Objects = @(& $ScriptPath -ResultPath $ResultPath -Repository $Repository |
        Where-Object { $_.PSObject.Properties['Verdict'] } |
        ForEach-Object { [ordered]@{ Verdict = "$($_.Verdict)"; Problems = @($_.Problems | ForEach-Object { "$_" }) } })
    $result.ExitCode = $LASTEXITCODE
}
catch {
    $result.Error = $_.Exception.Message
}
$result | ConvertTo-Json -Depth 4 | Set-Content -Path $ResultFile
'@
    # The exit code of the script: & runs it in this process, where exit sets $LASTEXITCODE.
    & pwsh -NoProfile -NonInteractive -File $runner -ScriptPath $script -ResultPath $ResultPath `
        -Repository $repository -ResultFile $resultFile *> $null
    $result = Get-Content -Path $resultFile -Raw | ConvertFrom-Json
    [pscustomobject]@{ Objects = @($result.Objects); Error = $result.Error; ExitCode = [int] $result.ExitCode }
}

New-Item -ItemType Directory -Path $work | Out-Null
try {
    if (-not (Test-Path -Path $script)) { throw "$script is missing." }
    # The repository of the check, with PachaOps 0.2.0 built and published by build.ps1.
    if (Get-PSResourceRepository -Name $repository -ErrorAction SilentlyContinue) {
        Unregister-PSResourceRepository -Name $repository
    }
    New-Item -ItemType Directory -Path (Join-Path $work 'repository') | Out-Null
    Register-PSResourceRepository -Name $repository -Uri (Join-Path $work 'repository') -Trusted
    & (Join-Path $root 'build.ps1') -Repository $repository -OutputPath (Join-Path $work 'out') | Out-Null

    $now = [datetime]::UtcNow
    $nights = @(
        @{ Label = 'a good night, an hour ago'; Expected = 'OK'; Path = (Build-Night -Name good -Time $now.AddHours(-1) -ExitCode 0) }
        @{ Label = 'the same night, three days ago'; Expected = 'FAILED'; Path = (Build-Night -Name stale -Time $now.AddDays(-3) -ExitCode 0) }
        @{ Label = 'a night where two tests failed'; Expected = 'FAILED'; Path = (Build-Night -Name tests -Time $now.AddHours(-1) -ExitCode 1 -TestsFailed 2 -Publication NotPublished) }
        @{ Label = 'a night where dbachecks ran no test, exit code 0'; Expected = 'FAILED'; Path = (Build-Night -Name zero -Time $now.AddHours(-1) -ExitCode 0 -DbachecksExecuted 0) }
        @{ Label = 'a night that says 0.2.1 published, which the repository does not have'; Expected = 'FAILED'; Path = (Build-Night -Name version -Time $now.AddHours(-1) -ExitCode 0 -Version 0.2.1) }
        @{ Label = 'no trace at all'; Expected = 'FAILED'; Path = (Build-Night -Name none -Time $now -ExitCode 0 -NoTrace) }
    )
    foreach ($night in $nights) {
        $run = Invoke-Morning -ResultPath $night.Path
        $expectedCode = if ($night.Expected -eq 'OK') { 0 } else { 1 }
        if ($run.Error) {
            $problems.Add("For $($night.Label), Test-NightlyRun.ps1 threw an error: $($run.Error) A morning check says FAILED, it does not throw.")
            continue
        }
        if ($run.Objects.Count -ne 1) {
            $problems.Add("For $($night.Label), Test-NightlyRun.ps1 returns $($run.Objects.Count) object(s) with a Verdict, one is expected: Write-Host is text, not an object.")
            continue
        }
        $verdict = $run.Objects[0]
        if ($verdict.Verdict -ne $night.Expected) {
            $problems.Add("For $($night.Label), the verdict is '$($verdict.Verdict)', '$($night.Expected)' is expected.")
        }
        elseif ($night.Expected -eq 'FAILED' -and -not @($verdict.Problems).Count) {
            $problems.Add("For $($night.Label), the verdict FAILED comes without a reason in Problems.")
        }
        if ($run.ExitCode -ne $expectedCode) {
            $problems.Add("For $($night.Label), the exit code is $($run.ExitCode), $expectedCode is expected: a scheduler reads the code, not the text.")
        }
    }
}
finally {
    if (Get-PSResourceRepository -Name $repository -ErrorAction SilentlyContinue) {
        Unregister-PSResourceRepository -Name $repository
    }
    Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
}

if ($problems.Count) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
'OK    module 13: the good night says OK with exit code 0, and the five others say FAILED, with their reasons and exit code 1.'
