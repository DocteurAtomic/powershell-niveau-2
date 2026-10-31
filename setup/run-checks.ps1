<#
.SYNOPSIS
Runs every demo script and checks every exercise solution, in module order.

.DESCRIPTION
For each exercises/module_XX folder that has a check.ps1 and a solution, runs the check
against the solution. A demo script whose first five lines contain "ci: skip" is not run.
Exits with code 1 at the first failure. The continuous integration runs it on every push.
#>
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$failed = 0
foreach ($script in Get-ChildItem demos -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue | Sort-Object FullName) {
    if ((Get-Content $script -TotalCount 5) -match 'ci: skip') { "skip  $($script.FullName)"; continue }
    & pwsh -NoProfile -File $script.FullName *> $null
    if ($LASTEXITCODE -ne 0) { "FAIL  $($script.FullName) (exit $LASTEXITCODE)"; $failed++ } else { "ok    $($script.FullName)" }
}
foreach ($check in Get-ChildItem exercises -Recurse -Filter check.ps1 -ErrorAction SilentlyContinue | Sort-Object FullName) {
    & pwsh -NoProfile -File $check.FullName -Solution
    if ($LASTEXITCODE -ne 0) { "FAIL  $($check.FullName) (exit $LASTEXITCODE)"; $failed++ } else { "ok    $($check.FullName)" }
}
if ($failed) { "$failed failure(s)"; exit 1 }
'all checks passed'
