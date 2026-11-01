function Get-BackupCheck {
    <#
    .SYNOPSIS
    The backup check of the team, one instance after the other: for every database of the
    inventory, its last full and log backups and a status, and the instances that could not
    be reached. This is the reference of the exercise: do not change it.

    .EXAMPLE
    . ./exercises/module_07/Get-BackupCheck.ps1
    Get-BackupCheck -InventoryPath data/instances.csv -SqlCredential (Get-Secret -Vault PachaOps -Name sql-lab)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $InventoryPath,
        [Parameter(Mandatory)]
        [pscredential] $SqlCredential,
        # A full backup older than this is Late.
        [int] $MaxFullAgeDays = 7
    )
    $limit = (Get-Date).AddDays(-$MaxFullAgeDays)
    foreach ($instance in Import-Csv -Path $InventoryPath) {
        try {
            $server = Connect-DbaInstance -SqlInstance $instance.SqlInstance -SqlCredential $SqlCredential
        }
        catch {
            [pscustomobject]@{
                Instance = $instance.Name; Database = $null
                LastFullBackup = $null; LastLogBackup = $null; Status = 'Unreachable'
            }
            continue
        }
        foreach ($backup in Get-DbaLastBackup -SqlInstance $server -ExcludeDatabase tempdb) {
            $full = if ($backup.LastFullBackup) { [datetime] $backup.LastFullBackup }
            $log = if ($backup.LastLogBackup) { [datetime] $backup.LastLogBackup }
            [pscustomobject]@{
                Instance       = $instance.Name
                Database       = $backup.Database
                LastFullBackup = $full
                LastLogBackup  = $log
                Status         = if (-not $full) { 'Missing' } elseif ($full -lt $limit) { 'Late' } else { 'Ok' }
            }
        }
    }
}
