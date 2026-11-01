# Clip 8.2: ten commands sent with Invoke-Command -HostName, each one opening and closing its
# own SSH connection, then the same ten commands in one session opened by New-PSSession. The
# second measure includes opening and closing the session.
param(
    # How many commands are sent each way.
    [int] $Count = 10
)
$ssh = @{
    HostName    = 'localhost'
    Port        = 14535
    UserName    = 'student'
    KeyFilePath = Join-Path $PSScriptRoot '..' '..' 'lab' 'ssh' 'id_ed25519'
}
$connections = Measure-Command {
    foreach ($i in 1..$Count) { $null = Invoke-Command @ssh -ScriptBlock { Get-Date } }
}
$reused = Measure-Command {
    $session = New-PSSession @ssh
    try {
        foreach ($i in 1..$Count) { $null = Invoke-Command -Session $session -ScriptBlock { Get-Date } }
    }
    finally {
        Remove-PSSession -Session $session
    }
}
[pscustomobject]@{ Way = "Invoke-Command -HostName, $Count times"; Seconds = [math]::Round($connections.TotalSeconds, 2) }
[pscustomobject]@{ Way = "New-PSSession, then -Session $Count times"; Seconds = [math]::Round($reused.TotalSeconds, 2) }
