# Clip 11.4, the request of the team: the monthly deployment. The rings of 06-rings.ps1, then
# the run written into the log of the team (lab/reports/deployments.jsonl, one JSON line per
# instance and script, failures included, which no instance journal keeps), then a summary
# posted to the webhook of the team (module 9), and the message as the test server received it.
param(
    # The log of the deployments of the team.
    [string] $LogPath = (Join-Path $PSScriptRoot '..' '..' 'lab' 'reports' 'deployments.jsonl')
)
$ErrorActionPreference = 'Stop'
$LogPath = [System.IO.Path]::GetFullPath($LogPath)
if (-not (Get-SecretInfo -Vault PachaOps -Name m09_team_webhook)) {
    # 99-cleanup.ps1 of module 9 removes it.
    $null = & (Join-Path $PSScriptRoot '..' 'module_09' '03-secret.ps1')
    'The address of the webhook was missing from the vault: written again by demos/module_09/03-secret.ps1.'
}
$uri = Get-Secret -Vault PachaOps -Name m09_team_webhook -AsPlainText
$results = & (Join-Path $PSScriptRoot '06-rings.ps1') -PassThru
$time = Get-Date
$operator = [System.Environment]::UserName
$computer = [System.Environment]::MachineName

New-Item -ItemType Directory -Force -Path (Split-Path -Path $LogPath) | Out-Null
$results | ForEach-Object {
    [ordered]@{
        Time        = $time.ToUniversalTime().ToString('o')
        Operator    = $operator
        Computer    = $computer
        Ring        = $_.Ring
        SqlInstance = $_.SqlInstance
        Script      = $_.Script
        Status      = $_.Status
    } | ConvertTo-Json -Compress
} | Add-Content -Path $LogPath

$applied = @($results | Where-Object -Property Status -EQ 'Applied')
$already = @($results | Where-Object -Property Status -EQ 'AlreadyApplied')
$problems = @($results | Where-Object -Property Status -NotIn 'Applied', 'AlreadyApplied')
$lines = @(
    "Deployment of $($time.ToString('yyyy-MM-dd HH:mm')) by $operator from $computer"
    "Applied: $($applied.Count)" + $(if ($applied) { ', ' + (@($applied | ForEach-Object { "$($_.Script) on $($_.SqlInstance)" }) -join ', ') })
    "Already applied: $($already.Count)"
    "Not deployed: $($problems.Count)" + $(if ($problems) { ', ' + (@($problems | ForEach-Object { "$($_.SqlInstance) ($($_.Status))" }) -join ', ') })
)
$body = @{ text = $lines -join "`n" } | ConvertTo-Json
$null = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' `
    -MaximumRetryCount 2 -RetryIntervalSec 5 -StatusCodeVariable status
"Logged $($results.Count) line(s) in $LogPath; posted, status $status"

# What the server received: the line of its log that holds this message.
$log = Join-Path $PSScriptRoot '..' '..' 'lab' 'webhook' 'received.jsonl'
$received = Get-Content -Path $log | Select-String -Pattern $lines[0] -SimpleMatch | Select-Object -Last 1
($received.Line | ConvertFrom-Json).body | ConvertFrom-Json | Select-Object -ExpandProperty text
