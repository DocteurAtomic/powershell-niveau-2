# Module 9: removes the secret written by 03-secret.ps1.
if (Get-SecretInfo -Vault PachaOps -Name m09_team_webhook) {
    Remove-Secret -Vault PachaOps -Name m09_team_webhook
}
'secret m09_team_webhook removed'
