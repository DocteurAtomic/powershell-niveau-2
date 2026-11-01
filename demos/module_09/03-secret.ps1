# Clip 9.3: the address of the webhook of the team goes into the vault PachaOps, as any
# secret: whoever has it can post in the channel. In the lab, it is the test server.
# 99-cleanup.ps1 removes it.
param(
    # The address of the webhook.
    [string] $Uri = 'http://localhost:14580/hook'
)
Set-Secret -Vault PachaOps -Name m09_team_webhook -Secret $Uri
Get-SecretInfo -Vault PachaOps -Name m09_team_webhook | Select-Object -Property Name, Type, VaultName
