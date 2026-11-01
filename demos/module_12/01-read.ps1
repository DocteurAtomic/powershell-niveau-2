# Clip 12.1: the server configuration of sql2 as dbatools reads it. The objects of
# Get-DbaSpConfigure do not convert to JSON, and twelve settings of SQL Server 2025 have no
# Name: what the team saves is DisplayName, ConfiguredValue and RunningValue.
$ErrorActionPreference = 'Stop'
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$configuration = Get-DbaSpConfigure -SqlInstance 'localhost,14534' -SqlCredential $credential -EnableException
"$($configuration.Count) settings on localhost,14534"
$configuration | Where-Object -Property DisplayName -EQ 'max server memory (MB)' |
    Select-Object -Property Name, DisplayName, ConfiguredValue, RunningValue, IsDynamic, IsAdvanced | Format-List | Out-String

try {
    $configuration | ConvertTo-Json -WarningAction SilentlyContinue | Out-Null
}
catch {
    "ConvertTo-Json on the whole objects: $($_.Exception.Message)"
}

$unnamed = @($configuration | Where-Object -FilterScript { -not $_.Name })
"$($unnamed.Count) settings without a Name"
$unnamed | Select-Object -First 3 -Property Name, DisplayName, ConfiguredValue | Format-Table | Out-String

$configuration | Where-Object -Property DisplayName -Like 'm* server memory (MB)' |
    Select-Object -Property DisplayName, ConfiguredValue, RunningValue | ConvertTo-Json
