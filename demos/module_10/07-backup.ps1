# Clip 10.4: a database of the demo, m10_audit, on sql2, with a full backup taken now, so
# that the rule of the team has one database that passes. 99-cleanup.ps1 removes the
# database, its backup history and the backup file.
$ErrorActionPreference = 'Stop'
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$instance = 'localhost,14534'
if (-not (Get-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database m10_audit)) {
    New-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Name m10_audit -EnableException | Out-Null
}
Backup-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database m10_audit -Type Full `
    -Path /var/opt/mssql/backup -FilePath m10_audit.bak -EnableException |
    Select-Object -Property SqlInstance, Database, Type, Start, BackupComplete |
    Format-Table | Out-String
