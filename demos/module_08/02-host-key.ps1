# Clip 8.1: what a scheduled script sees when ssh does not know the key of the host. The
# options of ssh are passed by -Options: an empty known_hosts file, and BatchMode, which
# forbids every question, as a script without a console has nobody to answer them.
# The same connection then runs with the known_hosts that setup/install.ps1 filled.
$ssh = @{
    HostName    = 'localhost'
    Port        = 14535
    UserName    = 'student'
    KeyFilePath = Join-Path $PSScriptRoot '..' '..' 'lab' 'ssh' 'id_ed25519'
}
try {
    Invoke-Command @ssh -Options @{ UserKnownHostsFile = '/dev/null'; BatchMode = 'yes' } -ScriptBlock { 'connected' } -ErrorAction Stop
}
catch {
    "Unknown host key: $($_.Exception.Message)"
}
"Known host key: $(Invoke-Command @ssh -Options @{ BatchMode = 'yes' } -ScriptBlock { 'connected' })"
