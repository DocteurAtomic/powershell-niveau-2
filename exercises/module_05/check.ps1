<#
.SYNOPSIS
Checks the exercise of module 5.

.DESCRIPTION
Checks the local part of the exercise; the run on GitHub is the proof that remains.

- .github/workflows/test.yml runs ./analyze.ps1, installs PSScriptAnalyzer at version 1.25.0,
  still runs the Pester tests, and lets no step or job fail without failing the run
  (continue-on-error: true). PowerShell has no YAML reader: the workflow is searched as text,
  with Select-String.
- analyze.ps1, at the root of the clone, gives the expected result on made-up modules, each
  laid out in a temporary folder next to a copy of PSScriptAnalyzerSettings.psd1, and run in a
  child pwsh from that folder, as the workflow runs it from the root of the clone:
  - a clean function: exit code 0;
  - a function that calls Write-Host: an exit code other than 0, and the name of the rule in
    the output;
  - a function whose opening brace is on its own line, which only the settings of the team
    report: an exit code other than 0;
  - a clean function, next to a Pester test whose variables are set in BeforeAll and read in
    It: exit code 0 (the analyzer reports them as never used).
- Then it runs analyze.ps1 on the src of the clone and says what it found, without failing:
  src of the course, in 0.2.0, has four findings in Get-MorningReport, which the exercise of
  module 4 corrects.

Exits with 0 when everything is right, 1 otherwise, and says what is missing.

With -Solution, checks solution/test.yml and solution/analyze.ps1 instead.

.EXAMPLE
./exercises/module_05/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your clone.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
if ($Solution) {
    $workflow = Join-Path $PSScriptRoot 'solution' 'test.yml'
    $script = Join-Path $PSScriptRoot 'solution' 'analyze.ps1'
}
else {
    $workflow = Join-Path $root '.github' 'workflows' 'test.yml'
    $script = Join-Path $root 'analyze.ps1'
}
$problems = [System.Collections.Generic.List[string]]::new()

# 1. The workflow, read as text.
if (-not (Test-Path -Path $workflow)) {
    $problems.Add("$workflow is missing.")
}
else {
    if (-not (Select-String -Path $workflow -Pattern '^\s*[^#\s].*analyze\.ps1' -Quiet)) {
        $problems.Add("No step of $workflow runs analyze.ps1 (run: ./analyze.ps1).")
    }
    if (-not (Select-String -Path $workflow -Pattern 'PSScriptAnalyzer.*1\.25\.0' -Quiet)) {
        $problems.Add("$workflow does not install PSScriptAnalyzer at the version of the team, 1.25.0 (Install-PSResource -Name PSScriptAnalyzer -Version 1.25.0).")
    }
    if (-not (Select-String -Path $workflow -Pattern 'Invoke-Pester' -Quiet)) {
        $problems.Add("$workflow no longer runs the tests (Invoke-Pester): the analysis comes in addition to them.")
    }
    if (Select-String -Path $workflow -Pattern '^\s*continue-on-error:\s*true' -Quiet) {
        $problems.Add("$workflow has continue-on-error: true. A finding must fail the run.")
    }
}

# 2. analyze.ps1, on made-up modules.
$clean = @'
function Get-Sample {
    [CmdletBinding()]
    param(
        [string] $Name
    )
    Write-Verbose "Sample $Name"
    $Name
}
'@
$cases = @(
    @{ Name = 'a clean function'; Code = $clean; Fails = $false }
    @{ Name = 'a function that calls Write-Host'; Code = $clean -replace 'Write-Verbose', 'Write-Host'; Fails = $true; Rule = 'PSAvoidUsingWriteHost' }
    @{ Name = 'an opening brace on its own line (a rule of the team settings)'; Code = $clean -replace 'function Get-Sample \{', "function Get-Sample`n{"; Fails = $true; Rule = 'PSPlaceOpenBrace' }
    @{ Name = 'a clean function, next to a Pester test'; Code = $clean; Fails = $false; WithTest = $true }
)
$test = @'
BeforeAll {
    $name = 'sql1'
}
Describe 'Get-Sample' {
    It 'returns the name' {
        Get-Sample -Name $name | Should-Be 'sql1'
    }
}
'@
# Lays out a temporary root (analyze.ps1, a copy of the settings of the team, a src folder),
# runs analyze.ps1 from it in a child pwsh, and returns its exit code and its output.
function Invoke-Analysis {
    param(
        # The code of a made-up function, or the path of a src folder to copy.
        [string] $Code,
        [string] $SourcePath,
        [switch] $WithTest
    )
    $work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-05-$([guid]::NewGuid())"
    try {
        New-Item -ItemType Directory -Path $work | Out-Null
        Copy-Item -Path $script -Destination (Join-Path $work 'analyze.ps1')
        Copy-Item -Path (Join-Path $root 'PSScriptAnalyzerSettings.psd1') -Destination $work
        if ($SourcePath) {
            Copy-Item -Path $SourcePath -Destination (Join-Path $work 'src') -Recurse
        }
        else {
            $public = New-Item -ItemType Directory -Path (Join-Path $work 'src' 'PachaOps' 'Public')
            Set-Content -Path (Join-Path $public 'Get-Sample.ps1') -Value $Code
        }
        if ($WithTest) {
            $tests = New-Item -ItemType Directory -Path (Join-Path $work 'tests')
            Set-Content -Path (Join-Path $tests 'Get-Sample.Tests.ps1') -Value $test
        }
        Push-Location -Path $work
        try {
            $output = & pwsh -NoProfile -File ./analyze.ps1 *>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output.Trim() }
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path -Path $script)) {
    $problems.Add("$script is missing.")
}
else {
    foreach ($case in $cases) {
        $run = Invoke-Analysis -Code $case.Code -WithTest:([bool]$case.WithTest)
        if (($run.ExitCode -ne 0) -ne $case.Fails) {
            $expected = if ($case.Fails) { 'an exit code other than 0' } else { 'exit code 0' }
            $problems.Add("analyze.ps1 on $($case.Name): exit code $($run.ExitCode), expected $expected. Its output: $($run.Output -replace '\s+', ' ')")
        }
        elseif ($case.Rule -and $run.Output -notmatch $case.Rule) {
            $problems.Add("analyze.ps1 on $($case.Name): exit code $($run.ExitCode), but its output does not name the rule $($case.Rule): the log of the run must say what to correct.")
        }
    }
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
'OK    module 5: the workflow runs analyze.ps1, which fails on a finding and only on a finding.'

# 3. What the same control finds in the src of the clone. Not a failure: the run on GitHub
#    shows it in red.
$run = Invoke-Analysis -SourcePath (Join-Path $root 'src')
if ($run.ExitCode -eq 0) {
    'NOTE  src: no finding, the job analyze passes on GitHub'
}
else {
    "NOTE  src: analyze.ps1 exits with $($run.ExitCode) on the src of the clone. The job analyze fails on GitHub until the findings are corrected; in 0.2.0, they are in Get-MorningReport (exercise of module 4)."
}
exit 0
