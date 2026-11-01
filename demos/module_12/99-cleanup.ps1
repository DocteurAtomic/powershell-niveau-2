# Module 12: removes what the demos wrote in lab (the exports of 06-export.ps1 and the journal of
# 07-fix.ps1), and checks that max degree of parallelism is back to 0 on both instances. The
# reference files of demos/module_12/reference stay: they are in Git.
$ErrorActionPreference = 'Stop'
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$lab = Join-Path $PSScriptRoot '..' '..' 'lab'
foreach ($path in (Join-Path $lab 'export'), (Join-Path $lab 'reports' 'configuration.jsonl')) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}
'lab/export and lab/reports/configuration.jsonl removed'
foreach ($instance in 'localhost,14533', 'localhost,14534') {
    $value = (Get-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -EnableException).ConfiguredValue
    if ($value -ne 0) {
        Set-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -Value 0 -EnableException | Out-Null
        "max degree of parallelism on ${instance}: $value, set back to 0"
    }
    else {
        "max degree of parallelism on ${instance}: 0"
    }
}
