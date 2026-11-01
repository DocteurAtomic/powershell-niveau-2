# Clip 13.1: what the evening task needs on the computer that runs it, set once: the team's
# repository registered (module 4) and the address of the webhook in the vault (module 9).
# 99-cleanup.ps1 removes both.
param(
    # The address of the webhook of the team; in the lab, the test server.
    [string] $Uri = 'http://localhost:14580/hook'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
$repository = Join-Path $root 'lab' 'repository'
New-Item -ItemType Directory -Path $repository -Force | Out-Null
if (-not (Get-PSResourceRepository -Name PachaTeam -ErrorAction SilentlyContinue)) {
    Register-PSResourceRepository -Name PachaTeam -Uri $repository -Trusted
}
Set-Secret -Vault PachaOps -Name m13_team_webhook -Secret $Uri
Get-PSResourceRepository -Name PachaTeam | Select-Object -Property Name, Uri, Trusted | Format-Table | Out-String
Get-SecretInfo -Vault PachaOps -Name m13_team_webhook | Select-Object -Property Name, Type, VaultName | Format-Table | Out-String
