using module ./PachaReport.psm1
# Clip 6.3, the end of the module: the morning report on the lab, one status per instance,
# the most serious first. The four .example instances of the inventory do not answer: the
# report waits for each one, about a minute in all.
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
Import-Module -Name (Join-Path $PSScriptRoot '..' '..' 'src' 'PachaOps' 'PachaOps.psd1')
$credential = Get-Secret -Vault PachaOps -Name sql-lab
Get-MorningReport -InventoryPath (Join-Path $PSScriptRoot '..' '..' 'data' 'instances.csv') -SqlCredential $credential 6> $null |
    Get-InstanceStatus |
    Sort-Object -Property Severity -Descending |
    Format-Table -Property Instance, Severity, Version, Databases, WithoutRecentFull
