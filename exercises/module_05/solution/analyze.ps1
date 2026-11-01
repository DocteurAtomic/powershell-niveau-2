<#
.SYNOPSIS
Analyzes the module of the team with PSScriptAnalyzer, and fails on any finding.

.DESCRIPTION
Solution of the exercise of module 5, copied to the root of the clone, next to
PSScriptAnalyzerSettings.psd1. Runs Invoke-ScriptAnalyzer 1.25.0 on src, recursively, with
the settings of the team, writes what it finds, and exits with 1 when there is a finding, 0
otherwise. The workflow test.yml runs it on every push; a workstation runs it the same way.

The tests of tests/ are not analyzed: on them, PSUseDeclaredVarsMoreThanAssignments reports
the variables that a Pester BeforeAll sets and an It reads as never used (four findings,
measured), and the settings of the team exclude no rule for the whole repository.

.EXAMPLE
./analyze.ps1
#>
[CmdletBinding()]
param(
    # The folder to analyze.
    [string] $Path = (Join-Path $PSScriptRoot 'src')
)
$ErrorActionPreference = 'Stop'
Import-Module -Name PSScriptAnalyzer -RequiredVersion 1.25.0
$settings = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'
$findings = @(Invoke-ScriptAnalyzer -Path $Path -Recurse -Settings $settings)
if ($findings.Count -gt 0) {
    $findings | Format-Table -Property RuleName, Severity, ScriptName, Line -AutoSize | Out-String -Width 200
    "$($findings.Count) finding(s) in $Path"
    exit 1
}
"No finding in $Path"
