<#
.SYNOPSIS
Checks the two containers of level 2: the remote host answers PowerShell remoting over SSH,
and the webhook test server answers and writes what it receives.

.DESCRIPTION
Runs a command on pwshcourse-host through Invoke-Command -HostName, without a console, as a
scheduled script would, then posts a message to the webhook test server and reads it back
from lab/webhook/received.jsonl. Exits with code 0 when everything works, 1 otherwise.

.EXAMPLE
./setup/test-host.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..'
$failures = 0

try {
    $remote = Invoke-Command -HostName localhost -Port 14535 -UserName student `
        -KeyFilePath (Join-Path $root 'lab' 'ssh' 'id_ed25519') -ScriptBlock {
            [pscustomobject]@{
                Version = $PSVersionTable.PSVersion.ToString()
                Backups = (Get-ChildItem /srv/backups -Recurse -File | Measure-Object).Count
            }
        }
    if ($remote.Version -ne '7.6.9' -or $remote.Backups -lt 1) { throw "unexpected answer: $remote" }
    "ok    remote host: PowerShell $($remote.Version), $($remote.Backups) backup files"
}
catch { "FAIL  remote host: $($_.Exception.Message)"; $failures++ }

try {
    $marker = [guid]::NewGuid().ToString()
    $null = Invoke-RestMethod -Uri 'http://localhost:14580/hook' -Method Post `
        -Body (@{ text = $marker } | ConvertTo-Json) -ContentType 'application/json'
    $log = Join-Path $root 'lab' 'webhook' 'received.jsonl'
    if (-not (Select-String -Path $log -Pattern $marker -SimpleMatch -Quiet)) { throw "message not in $log" }
    'ok    webhook test server: message received and logged'
}
catch { "FAIL  webhook test server: $($_.Exception.Message)"; $failures++ }

if ($failures) { exit 1 }
