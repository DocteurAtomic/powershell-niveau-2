function Get-BackupShareUsage {
    <#
    .SYNOPSIS
    Reads how much room the backups take, and how much is left on their volume.

    .DESCRIPTION
    Counts the backup files under a folder, adds up their size, and reads the size and the free
    space of the volume that holds the folder. Today it reads the folder of the workstation it
    runs on: lab/backups of the clone, by default.

    .EXAMPLE
    Get-BackupShareUsage -Path lab/backups
    #>
    [CmdletBinding()]
    param(
        # The folder of the backups.
        [string] $Path = 'lab/backups'
    )
    $files = Get-ChildItem -Path $Path -Recurse -File | Measure-Object -Property Length -Sum
    $volume = [System.IO.DriveInfo]::new((Resolve-Path -Path $Path).Path)
    [pscustomobject]@{
        ComputerName    = [Environment]::MachineName
        Path            = $Path
        FileCount       = $files.Count
        BackupBytes     = [long] $files.Sum
        VolumeSizeBytes = $volume.TotalSize
        VolumeFreeBytes = $volume.AvailableFreeSpace
    }
}
