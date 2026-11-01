# Clip 11.2: a script that fails halfway, and a script edited after it was applied, on sql2.
# Both are written into a temporary folder, next to a copy of the scripts of the team. The
# failed script leaves nothing: neither its table, nor its line in the journal.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Deploy-PachaScript.ps1')
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$instance = 'localhost,14534'
$folder = Join-Path ([System.IO.Path]::GetTempPath()) "m11-scripts-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
try {
    Copy-Item -Path (Join-Path $PSScriptRoot 'scripts' '*.sql') -Destination $folder
    Set-Content -Path (Join-Path $folder '0002-m11-broken.sql') -Value @'
CREATE TABLE dbo.m11_broken (Id int NOT NULL);
GO
INSERT INTO dbo.m11_broken (Id) VALUES (1), (NULL);
'@
    Deploy-PachaScript -SqlInstance $instance -SqlCredential $credential -Path $folder |
        Format-List -Property Script, Status, Message | Out-String -Width 100
    Invoke-DbaQuery -SqlInstance $instance -SqlCredential $credential -Database DBA -EnableException -Query @'
SELECT OBJECT_ID(N'dbo.m11_broken') AS BrokenTable,
       (SELECT COUNT(*) FROM dbo.DeploymentJournal WHERE ScriptName = N'0002-m11-broken.sql') AS JournalRows;
'@ | Format-Table | Out-String

    # The script that was applied, edited afterwards.
    Remove-Item -Path (Join-Path $folder '0002-m11-broken.sql')
    Add-Content -Path (Join-Path $folder '0001-deployment-journal.sql') -Value '-- one more comment'
    Deploy-PachaScript -SqlInstance $instance -SqlCredential $credential -Path $folder |
        Format-List -Property Script, Status, Message | Out-String -Width 100
}
finally {
    Remove-Item -Path $folder -Recurse -Force
}
