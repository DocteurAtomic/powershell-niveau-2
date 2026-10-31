<#
.SYNOPSIS
Checks that the lab works: both instances answer, PachadataTraining is restored, and a
backup taken on sql1 restores on sql2 through the shared volume.

.DESCRIPTION
Creates a small database labcheck on sql1, backs it up to /var/opt/mssql/backup, restores
and checks it on sql2 with Test-DbaLastBackup, then removes the database, the copy and the
backup file. Exits with code 0 when everything works, 1 otherwise.

.EXAMPLE
./setup/test-lab.ps1
#>
[CmdletBinding()]
param(
    [string] $SaPassword = 'Course-2026!lab'
)
$ErrorActionPreference = 'Stop'
Import-Module dbatools
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$cred = [pscredential]::new('sa', (ConvertTo-SecureString $SaPassword -AsPlainText -Force))
$sql1 = 'localhost,14533'
$sql2 = 'localhost,14534'
$failures = 0

foreach ($instance in $sql1, $sql2) {
    $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $cred
    "ok    $instance answers: SQL Server $($server.VersionString)"
}
if (Get-DbaDatabase -SqlInstance $sql1 -SqlCredential $cred -Database PachadataTraining) {
    'ok    PachadataTraining is restored on sql1'
} else {
    'FAIL  PachadataTraining is missing on sql1: run ./setup/install.ps1'; $failures++
}

$file = '/var/opt/mssql/backup/labcheck.bak'
try {
    New-DbaDatabase -SqlInstance $sql1 -SqlCredential $cred -Name labcheck | Out-Null
    $backup = Backup-DbaDatabase -SqlInstance $sql1 -SqlCredential $cred -Database labcheck `
        -FilePath $file -Type Full -EnableException
    "ok    backup written on the shared volume ($($backup.TotalSize))"
    $test = Test-DbaLastBackup -Path $file -Destination $sql2 -DestinationSqlCredential $cred `
        -EnableException
    if ($test.RestoreResult -eq 'Success' -and $test.DbccResult -eq 'Success') {
        'ok    the backup restores and passes DBCC CHECKDB on sql2'
    } else {
        "FAIL  restore on sql2: RestoreResult=$($test.RestoreResult) DbccResult=$($test.DbccResult)"; $failures++
    }
}
catch {
    "FAIL  $($_.Exception.Message)"; $failures++
}
finally {
    Remove-DbaDatabase -SqlInstance $sql1 -SqlCredential $cred -Database labcheck -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Remove-DbaDbBackupRestoreHistory -SqlInstance $sql1, $sql2 -SqlCredential $cred -Database labcheck -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Invoke-DbaQuery -SqlInstance $sql1 -SqlCredential $cred -Query "EXEC master.sys.xp_delete_files N'$file';" -ErrorAction SilentlyContinue
}
if ($failures) { exit 1 }
'The lab is ready.'
