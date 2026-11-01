# Module 11: brings the database DBA of both instances back to its state after setup/install.ps1,
# empty: it removes the community tools of 01-community.ps1 and the deployment journal of the
# team (04-deploy.ps1 and 06-rings.ps1). Then it removes the address of the webhook that
# 08-monthly.ps1 writes again when it is missing, as the cleanup of module 9 does.
$ErrorActionPreference = 'Stop'
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$procedures = 'CommandExecute', 'DatabaseBackup', 'DatabaseIntegrityCheck', 'IndexOptimize', 'sp_WhoIsActive',
    'sp_Blitz', 'sp_BlitzAnalysis', 'sp_BlitzBackups', 'sp_BlitzCache', 'sp_BlitzFirst', 'sp_BlitzIndex',
    'sp_BlitzLock', 'sp_BlitzWho', 'sp_DatabaseRestore', 'sp_ineachdb', 'sp_kill'
$views = 'DeploymentSummary'
$tables = 'CommandLog', 'Queue', 'QueueDatabase', 'SqlServerVersions', 'DeploymentJournal'
$query = @(
    $procedures | ForEach-Object { "DROP PROCEDURE IF EXISTS dbo.[$_];" }
    $views | ForEach-Object { "DROP VIEW IF EXISTS dbo.[$_];" }
    $tables | ForEach-Object { "DROP TABLE IF EXISTS dbo.[$_];" }
) -join "`n"
foreach ($instance in 'localhost,14533', 'localhost,14534') {
    Invoke-DbaQuery -SqlInstance $instance -SqlCredential $credential -Database DBA -Query $query -EnableException
    $left = Invoke-DbaQuery -SqlInstance $instance -SqlCredential $credential -Database DBA -EnableException -As SingleValue `
        -Query 'SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped = 0;'
    "DBA on ${instance}: $left object(s) left"
}
& (Join-Path $PSScriptRoot '..' 'module_09' '99-cleanup.ps1')
