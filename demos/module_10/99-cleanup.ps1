# Module 10: removes what 07-backup.ps1 created on sql2, the database m10_audit, its backup
# history in msdb and its backup file.
$ErrorActionPreference = 'Stop'
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$instance = 'localhost,14534'
if (Get-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database m10_audit) {
    Remove-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database m10_audit -Confirm:$false -EnableException | Out-Null
}
Invoke-DbaQuery -SqlInstance $instance -SqlCredential $credential -Database msdb -EnableException `
    -Query "EXEC dbo.sp_delete_database_backuphistory @database_name = N'm10_audit';"
Invoke-DbaQuery -SqlInstance $instance -SqlCredential $credential -Database master -EnableException `
    -Query "EXEC master.sys.xp_delete_files N'/var/opt/mssql/backup/m10_audit.bak';"
'database m10_audit, its backup history and m10_audit.bak removed'
