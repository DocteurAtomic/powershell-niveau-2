# Clip 1.2: PSScriptAnalyzer on PachaOps, with its default rules.
# Run it from the root of the clone, or type the lines one after the other.
Get-Module -ListAvailable -Name PSScriptAnalyzer | Select-Object -Property Name, Version | Out-Host

# The whole module, every severity.
Invoke-ScriptAnalyzer -Path src/PachaOps -Recurse | Out-Host

# The rules, by severity, and the findings that count: errors and warnings.
Get-ScriptAnalyzerRule | Group-Object -Property Severity -NoElement | Out-Host
Invoke-ScriptAnalyzer -Path src/PachaOps -Recurse -Severity Error, Warning | Out-Host

# The two functions of the demonstration.
Invoke-ScriptAnalyzer -Path src/PachaOps/Public/Get-BackupAge.ps1 | Out-Host
Invoke-ScriptAnalyzer -Path src/PachaOps/Public/Remove-OldBackup.ps1 | Out-Host

# What the rule on ShouldProcess says of a function that removes without it.
$definition = 'function Remove-TempFile { param([string] $Path) Remove-Item -LiteralPath $Path }'
Invoke-ScriptAnalyzer -ScriptDefinition $definition | Select-Object -Property RuleName, Message | Format-List | Out-Host
