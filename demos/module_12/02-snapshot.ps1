<#
.SYNOPSIS
Saves the server configuration of each instance of the lab in its reference file (clip 12.1).

.DESCRIPTION
One file per instance in demos/module_12/reference: the address of the instance and its
settings, reduced by Get-PachaConfiguration. The team takes the snapshot when the instance is
right, reads the difference in Git (git diff), and commits it: the file in Git is the reference
that Compare-PachaConfiguration reads.
#>
param(
    [string] $Path = (Join-Path $PSScriptRoot 'reference')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PachaConfiguration.ps1')
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
New-Item -ItemType Directory -Path $Path -Force | Out-Null
$instances = [ordered]@{ sql1 = 'localhost,14533'; sql2 = 'localhost,14534' }
foreach ($name in $instances.Keys) {
    $settings = @(Get-PachaConfiguration -SqlInstance $instances[$name] -SqlCredential $credential)
    $file = Join-Path $Path "$name.json"
    [ordered]@{ SqlInstance = $instances[$name]; Settings = $settings } |
        ConvertTo-Json -Depth 3 | Set-Content -Path $file
    "$($settings.Count) settings of $($instances[$name]) written to $(Resolve-Path -Path $file -Relative)"
}
