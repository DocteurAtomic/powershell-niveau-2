function Get-BackupShareUsage {
    <#
    .SYNOPSIS
    Reads how much room the backups take on the backup server, and how much is left on their
    volume.

    .DESCRIPTION
    Opens a PowerShell session over SSH on the server, counts the backup files under a folder of
    the server, adds up their size, and reads the size and the free space of the volume that
    holds the folder. The work is done on the server: only the numbers come back. The session is
    closed in every case. Returns one object of the workstation, without the properties that
    remoting adds.

    .EXAMPLE
    Get-BackupShareUsage -HostName localhost -Port 14535 -UserName student -KeyFilePath lab/ssh/id_ed25519
    #>
    [CmdletBinding()]
    param(
        # The backup server.
        [Parameter(Mandatory)]
        [string] $HostName,
        # The SSH port of the server.
        [int] $Port = 22,
        # The account on the server.
        [Parameter(Mandatory)]
        [string] $UserName,
        # The private key of the account.
        [Parameter(Mandatory)]
        [string] $KeyFilePath,
        # The folder of the backups, on the server.
        [string] $Path = '/srv/backups'
    )
    $session = New-PSSession -HostName $HostName -Port $Port -UserName $UserName -KeyFilePath $KeyFilePath -ErrorAction Stop
    try {
        $remote = Invoke-Command -Session $session -ErrorAction Stop -ScriptBlock {
            $files = Get-ChildItem -Path $using:Path -Recurse -File | Measure-Object -Property Length -Sum
            $volume = [System.IO.DriveInfo]::new($using:Path)
            [pscustomobject]@{
                ComputerName    = [Environment]::MachineName
                FileCount       = $files.Count
                BackupBytes     = [long] $files.Sum
                VolumeSizeBytes = $volume.TotalSize
                VolumeFreeBytes = $volume.AvailableFreeSpace
            }
        }
    }
    finally {
        Remove-PSSession -Session $session
    }
    [pscustomobject]@{
        ComputerName    = $remote.ComputerName
        Path            = $Path
        FileCount       = $remote.FileCount
        BackupBytes     = $remote.BackupBytes
        VolumeSizeBytes = $remote.VolumeSizeBytes
        VolumeFreeBytes = $remote.VolumeFreeBytes
    }
}
