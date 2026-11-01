# Clip 12.4: the setting changed by hand is found, and set back to its reference, first with
# -WhatIf, then for real, with the reason in the journal of the team (lab/reports/configuration.jsonl).
# The change by hand is made again at the start, as in 05-by-hand.ps1; the finally block makes
# sure that the value is set back even when the script fails.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PachaConfiguration.ps1')
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$instance = 'localhost,14534'
$reference = Join-Path $PSScriptRoot 'reference' 'sql2.json'
$before = (Get-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -EnableException).ConfiguredValue
try {
    Set-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -Value 1 -EnableException | Out-Null
    $drift = Compare-PachaConfiguration -Path $reference -SqlCredential $credential
    $drift | Format-Table | Out-String
    # The demo sets back the setting it changed, and nothing else.
    if (@($drift).Count -ne 1 -or $drift.Setting -ne 'max degree of parallelism') {
        throw "sql2 differs from $reference on more than the setting changed here: take the reference of your lab first (02-snapshot.ps1)."
    }
    $reason = 'Set by hand on sql2, not in the reference of the team'
    $drift | Repair-PachaConfiguration -SqlCredential $credential -Reason $reason -WhatIf
    $drift | Repair-PachaConfiguration -SqlCredential $credential -Reason $reason |
        Format-List -Property SqlInstance, Setting, PreviousValue, NewValue, Operator, Computer, Reason | Out-String
}
finally {
    # With -EnableException, Set-DbaSpConfigure fails when the value is already the one asked.
    $now = (Get-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -EnableException).ConfiguredValue
    if ($now -ne $before) {
        Set-DbaSpConfigure -SqlInstance $instance -SqlCredential $credential -Name MaxDegreeOfParallelism -Value $before -EnableException | Out-Null
    }
}
