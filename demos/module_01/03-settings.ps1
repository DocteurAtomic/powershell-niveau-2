# Clip 1.3: the settings of the team, for the analyzer and for the formatter.
# Run it from the root of the clone, or type the lines one after the other.
Get-Content -Path ./PSScriptAnalyzerSettings.psd1 | Out-Host
Invoke-ScriptAnalyzer -Path src/PachaOps -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 |
    Format-Table -Property RuleName, Severity, ScriptName, Line | Out-Host

# The layout rules of the same file, checked by the analyzer and applied by the formatter.
Invoke-ScriptAnalyzer -Path demos/module_01/03-layout.ps1 -Settings ./PSScriptAnalyzerSettings.psd1 |
    Format-Table -Property RuleName, Line, Message | Out-Host
Invoke-Formatter -ScriptDefinition (Get-Content -Path demos/module_01/03-layout.ps1 -Raw) -Settings ./PSScriptAnalyzerSettings.psd1

# The formatter changes nothing in PachaOps: the module already follows the layout.
Get-ChildItem -Path src/PachaOps/Public -Filter *.ps1 | ForEach-Object {
    $code = Get-Content -Path $_.FullName -Raw
    [pscustomobject]@{
        File      = $_.Name
        Unchanged = $code -ceq (Invoke-Formatter -ScriptDefinition $code -Settings ./PSScriptAnalyzerSettings.psd1)
    }
} | Out-Host

# The answer to the team: the state of the module, file by file.
Invoke-ScriptAnalyzer -Path src/PachaOps -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 |
    Group-Object -Property ScriptName -NoElement | Out-Host
