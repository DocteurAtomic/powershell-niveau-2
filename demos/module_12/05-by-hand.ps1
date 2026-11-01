# Clip 12.2: a setting changed by hand on sql2, max degree of parallelism set to 1, then the
# command of the request, which finds it. The finally block sets the value it read first back,
# so that the lab is left as it was, even when the comparison fails.
$ErrorActionPreference = 'Stop'
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$instance = 'localhost,14534'
$before = (Get-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -EnableException).ConfiguredValue
try {
    Set-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -Value 1 -EnableException |
        Format-Table -Property SqlInstance, ConfigName, PreviousValue, NewValue | Out-String
    & (Join-Path $PSScriptRoot '04-drift.ps1')
}
finally {
    # With -EnableException, Set-DbaSpConfigure fails when the value is already the one asked.
    $now = (Get-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -EnableException).ConfiguredValue
    if ($now -ne $before) {
        Set-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -Value $before -EnableException | Out-Null
    }
    $value = (Get-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism).ConfiguredValue
    "max degree of parallelism on ${instance}: $value"
}
