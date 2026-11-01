function Get-BackupCheckParallel {
    <#
    .SYNOPSIS
    The backup check of the team, three instances at a time: the same objects as
    Get-BackupCheck, in the order the instances answer.

    .EXAMPLE
    . ./exercises/module_07/solution/Get-BackupCheckParallel.ps1
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
    # dbatools is loaded once here: imported in each runspace, it costs seconds and fails at
    # times. The limit is computed once, so that every runspace uses the same one.
    Import-Module -Name dbatools
    $limit = (Get-Date).AddDays(-$MaxFullAgeDays)
    Import-Csv -Path $InventoryPath | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $instance = $_
        $limit = $using:limit
        try {
            $server = Connect-DbaInstance -SqlInstance $instance.SqlInstance -SqlCredential $using:SqlCredential -WarningAction SilentlyContinue
        }
        catch {
            [pscustomobject]@{
                Instance = $instance.Name; Database = $null
                LastFullBackup = $null; LastLogBackup = $null; Status = 'Unreachable'
            }
            # return ends the script block of this instance only.
            return
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
