# Clip 6.1: the severity of an instance as text, then as an enumeration; a flags enumeration;
# an enumeration against ValidateSet. Run it from the root of the clone, or type the lines one
# after the other. The errors the clip shows are caught here, so that the script runs to the end.
$rows = & (Join-Path $PSScriptRoot 'sample-report.ps1')
# A typo in a string finds nothing, and says nothing.
@($rows | Where-Object -Property Status -EQ -Value 'Unreacheable').Count
# Text sorts in alphabetical order.
'Ok', 'Critical', 'Warning' | Sort-Object -Descending

enum Severity {
    Ok
    Warning
    Critical
}
[Severity]::Warning
[int] [Severity]::Critical
[Severity[]] ('Ok', 'Critical', 'Warning') | Sort-Object -Descending
[Severity]::Critical -gt 'Warning'
[Severity] 'critical'
try { [Severity] 'Critcal' } catch { $_.Exception.Message }
[Severity].GetEnumNames()

# Flags: one value made of several names, each name a bit.
[Flags()] enum ReportSection {
    Databases = 1
    Backups = 2
    ErrorLog = 4
}
$sections = [ReportSection] 'Databases, ErrorLog'
$sections
[int] $sections
$sections.HasFlag([ReportSection]::Backups)
[ReportSection] 6

# The same parameter, as a ValidateSet of strings and as an enumeration.
function Select-SeverityText {
    param([ValidateSet('Ok', 'Warning', 'Critical')] [string] $Minimum)
    'Ok', 'Warning', 'Critical' | Where-Object { $_ -ge $Minimum }
}
function Select-Severity {
    param([Severity] $Minimum)
    [Severity[]] ('Ok', 'Warning', 'Critical') | Where-Object { $_ -ge $Minimum }
}
Select-SeverityText -Minimum Warning
Select-Severity -Minimum Warning
try { Select-SeverityText -Minimum Urgent } catch { $_.Exception.Message }
try { Select-Severity -Minimum Urgent } catch { $_.Exception.Message }
