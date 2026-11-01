<#
.SYNOPSIS
Compares each instance of the lab with its reference in Git, and says which settings drifted
(clips 12.2 and 12.4).

.DESCRIPTION
The command of the request: one line per instance, then one object per difference returned by
Compare-PachaConfiguration. Nothing to fix when every instance is like its reference.
#>
param(
    [string] $Path = (Join-Path $PSScriptRoot 'reference')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PachaConfiguration.ps1')
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$drift = foreach ($file in Get-ChildItem -Path $Path -Filter *.json | Sort-Object -Property Name) {
    $differences = @(Compare-PachaConfiguration -Path $file.FullName -SqlCredential $credential)
    "$($file.BaseName): $($differences.Count) difference(s) with $(Resolve-Path -Path $file.FullName -Relative)" | Write-Host
    $differences
}
$drift | Format-Table | Out-String
