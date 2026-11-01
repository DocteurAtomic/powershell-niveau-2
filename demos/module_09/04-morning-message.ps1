# Clip 9.3, the request of the team: the morning report, summed up in a few lines, posted to
# the webhook of the team, whose address is read from the vault (03-secret.ps1). Then the
# message as the test server received it.
param(
    # The inventory of the team.
    [string] $InventoryPath = (Join-Path $PSScriptRoot '..' '..' 'data' 'instances.csv')
)
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
Import-Module -Name (Join-Path $PSScriptRoot '..' '..' 'src' 'PachaOps' 'PachaOps.psd1')
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$uri = Get-Secret -Vault PachaOps -Name m09_team_webhook -AsPlainText

$report = Get-MorningReport -InventoryPath $InventoryPath -SqlCredential $credential 6> $null
$online = @($report | Where-Object -Property Status -EQ 'Online')
$unreachable = @($report | Where-Object -Property Status -EQ 'Unreachable')
$noBackup = @($online | Where-Object -Property LastFullBackup -EQ $null)
$lines = @(
    "Morning report, $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    "Online: $(@($online.Instance | Select-Object -Unique).Count) instances, $($online.Count) databases"
    "Unreachable: $($unreachable.Instance -join ', ')"
    "Without a full backup: $($noBackup.Count) databases"
)
$body = @{ text = $lines -join "`n" } | ConvertTo-Json
$null = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' `
    -MaximumRetryCount 2 -RetryIntervalSec 5 -StatusCodeVariable status
"Posted, status $status"

# What the server received: the line of its log that holds this message.
$log = Join-Path $PSScriptRoot '..' '..' 'lab' 'webhook' 'received.jsonl'
$received = Get-Content -Path $log | Select-String -Pattern $lines[0] -SimpleMatch | Select-Object -Last 1
($received.Line | ConvertFrom-Json).body | ConvertFrom-Json | Select-Object -ExpandProperty text
