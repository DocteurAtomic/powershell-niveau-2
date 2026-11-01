function Get-BackupCheckParallel {
    <#
    .SYNOPSIS
    The backup check of the team, three instances at a time. It must return the same objects
    as Get-BackupCheck, in any order. For now it is a copy of Get-BackupCheck: make it run in
    parallel.

    .EXAMPLE
    . ./exercises/module_07/Get-BackupCheckParallel.ps1
    Get-BackupCheckParallel -InventoryPath data/instances.csv -SqlCredential (Get-Secret -Vault PachaOps -Name sql-lab)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $InventoryPath,
        [Parameter(Mandatory)]
        [pscredential] $SqlCredential,
        # A full backup older than this is Late.
        [int] $MaxFullAgeDays = 7,
        # How many instances are checked at the same time.
        [int] $ThrottleLimit = 3
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
