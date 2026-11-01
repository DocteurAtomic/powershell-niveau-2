# Clip 11.2: the script of the team played as a colleague plays it, by Invoke-DbaQuery -File on
# both instances, twice. The second run fails, and nothing on the instance says that the
# script was already played. Invoke-DbaQuery has no -WhatIf. The table is removed at the end,
# so that Deploy-PachaScript (04-deploy.ps1) finds the instances as they were.
$ErrorActionPreference = 'Stop'
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$instances = 'localhost,14533', 'localhost,14534'
$file = Join-Path $PSScriptRoot 'scripts' '0001-deployment-journal.sql'

Invoke-DbaQuery -SqlInstance $instances -SqlCredential $credential -Database DBA -File $file -EnableException
'First run: done'
foreach ($instance in $instances) {
    try {
        Invoke-DbaQuery -SqlInstance $instance -SqlCredential $credential -Database DBA -File $file -EnableException
    }
    catch {
        "Second run on ${instance}: $($_.Exception.Message)"
    }
}
try {
    Invoke-DbaQuery -SqlInstance $instances -SqlCredential $credential -Database DBA -File $file -WhatIf
}
catch {
    "-WhatIf: $($_.Exception.Message)"
}
Invoke-DbaQuery -SqlInstance $instances -SqlCredential $credential -Database DBA -EnableException `
    -Query 'DROP TABLE dbo.DeploymentJournal;'
