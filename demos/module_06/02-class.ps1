using module ./PachaReport.psm1
# Clip 6.2: the class InstanceStatus of PachaReport.psm1: an object, its typed properties, its
# constructor, ToString, the static method that reads the lines of the report. The using
# statement resolves its path from the folder of this script; typed at the prompt from the
# root of the clone, it is: using module ./demos/module_06/PachaReport.psm1
$status = [InstanceStatus]::new('sql1', 'Warning')
$status
try { $status.Severity = 'Urgent' } catch { $_.Exception.Message }
"$status"
[InstanceStatus]::new
$rows = & (Join-Path $PSScriptRoot 'sample-report.ps1')
[InstanceStatus]::FromReport(@($rows | Where-Object -Property Instance -EQ -Value 'sql2'), [datetime] '2026-11-02')
$rows | Get-InstanceStatus -ReferenceDate 2026-11-02 | Sort-Object -Property Severity -Descending |
    Format-Table -Property Instance, Severity, Databases, WithoutRecentFull
