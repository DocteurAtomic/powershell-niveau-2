# Clip 8.3, the request of the team: the age of the last full backup of each database, read on
# the server that holds the backups and not on a copy. PachaOps is not installed on the
# server: Invoke-Command -FilePath sends the file of Get-BackupAge, which stays defined in the
# session. The reference date is read on the server, in its own time zone.
param(
    # The moment the age is computed for.
    [datetime] $ReferenceDate = (Get-Date)
)
$ssh = @{
    HostName    = 'localhost'
    Port        = 14535
    UserName    = 'student'
    KeyFilePath = Join-Path $PSScriptRoot '..' '..' 'lab' 'ssh' 'id_ed25519'
}
$getBackupAgeFile = Join-Path $PSScriptRoot '..' '..' 'src' 'PachaOps' 'Public' 'Get-BackupAge.ps1'
$session = New-PSSession @ssh
try {
    Invoke-Command -Session $session -FilePath $getBackupAgeFile
    Invoke-Command -Session $session -ScriptBlock {
        Get-ChildItem -Path /srv/backups -Recurse -Filter '*_FULL_*.bak' |
            Group-Object -Property { $_.Directory.Parent.Name } |
            ForEach-Object { $_.Group | Sort-Object -Property LastWriteTimeUtc | Select-Object -Last 1 } |
            Get-BackupAge -ReferenceDate $using:ReferenceDate |
            Select-Object -Property @{ Name = 'Database'; Expression = { $_.Directory.Parent.Name } },
                @{ Name = 'LastFull'; Expression = { $_.Name } }, AgeDays
    } | Select-Object -Property Database, LastFull, AgeDays, PSComputerName
}
finally {
    Remove-PSSession -Session $session
}
