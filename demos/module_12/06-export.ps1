# Clip 12.3: Export-DbaInstance on sql2, into lab/export. With its default values, it opens a
# dedicated admin connection for the passwords of the credentials and of the linked servers,
# which the lab refuses: it writes nothing, and only a warning says so. Without these two parts,
# it writes one script per part. Takes about 40 seconds.
$ErrorActionPreference = 'Stop'
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$path = Join-Path $PSScriptRoot '..' '..' 'lab' 'export'
New-Item -ItemType Directory -Path $path -Force | Out-Null

$files = Export-DbaInstance -SqlInstance 'localhost,14534' -SqlCredential $credential -Path $path -WarningVariable exportWarning -WarningAction SilentlyContinue
"Default values: $(@($files).Count) file(s)"
$exportWarning | ForEach-Object { "WARNING: $_" }

$files = Export-DbaInstance -SqlInstance 'localhost,14534' -SqlCredential $credential -Path $path -Exclude Credentials, LinkedServers `
    -WarningVariable exportWarning -WarningAction SilentlyContinue
"Without Credentials and LinkedServers: $(@($files).Count) file(s), $(@($exportWarning).Count) warning(s)"
$files | Select-Object -Property Name, Length | Format-Table | Out-String
Get-ChildItem -Path $path | Select-Object -Property Name, Length | Format-Table | Out-String
