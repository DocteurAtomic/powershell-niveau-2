# Clip 8.1: the same questions asked on the workstation and on the remote host, to see what
# runs where. The remote side answers through PowerShell remoting over SSH: the key of the
# student (lab/ssh), and the key of the host that setup/install.ps1 wrote into known_hosts.
$ssh = @{
    HostName    = 'localhost'
    Port        = 14535
    UserName    = 'student'
    KeyFilePath = Join-Path $PSScriptRoot '..' '..' 'lab' 'ssh' 'id_ed25519'
}
$question = {
    param([string] $Side)
    [pscustomobject]@{
        Side       = $Side
        Computer   = [Environment]::MachineName
        User       = [Environment]::UserName
        PowerShell = $PSVersionTable.PSVersion.ToString()
        OS         = $PSVersionTable.OS
        TimeZone   = (Get-TimeZone).Id
        Location   = (Get-Location).Path
        dbatools   = [bool] (Get-Module -ListAvailable -Name dbatools)
    }
}
& $question -Side 'Workstation'
Invoke-Command @ssh -ScriptBlock $question -ArgumentList 'Remote' |
    Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName
