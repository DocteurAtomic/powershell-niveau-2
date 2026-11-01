# The script of a colleague: does every database of sql2 follow the rules of the team? It reads
# one option only, writes text that nothing else can read, and looks at the system databases
# too. The rules of the team are in pachadata-database.json, next to it.
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
foreach ($database in Get-DbaDatabase -SqlInstance 'localhost,14534' -SqlCredential $credential) {
    if ($database.AutoShrink) {
        Write-Host "$($database.Name): AUTO_SHRINK is ON!"
    }
}
