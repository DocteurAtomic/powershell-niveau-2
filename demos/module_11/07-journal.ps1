# Clip 11.4: the journal of each instance, read back: which script, when (UTC, the time of the
# server), by whom and from which computer, and the SQL login, the same for the whole team.
param(
    [string[]] $SqlInstance = @('localhost,14533', 'localhost,14534')
)
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $credential -Database DBA -AppendServerInstance -EnableException `
    -Query 'SELECT ScriptName, AppliedAt, AppliedBy, AppliedFrom, LoginName FROM dbo.DeploymentJournal;' |
    Select-Object -Property ServerInstance, ScriptName, AppliedAt, AppliedBy, AppliedFrom, LoginName |
    Format-Table | Out-String
