# Clip 1.3: a script written without the layout of the team, left as it is on purpose.
# Invoke-ScriptAnalyzer -Path demos/module_01/03-layout.ps1 -Settings ./PSScriptAnalyzerSettings.psd1
# Invoke-Formatter -ScriptDefinition (Get-Content -Path demos/module_01/03-layout.ps1 -Raw) -Settings ./PSScriptAnalyzerSettings.psd1
foreach ($instance in Import-Csv -Path data/instances.csv)
{
    if($instance.Environment -eq 'Production'){
        $instance|Select-Object -Property Name,SqlInstance
    }
}
