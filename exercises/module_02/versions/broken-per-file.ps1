# A broken copy of Get-ErrorLogSummary, used by check.ps1: one object for the whole folder instead of one per file.
function Get-ErrorLogSummary {
    <#
    .SYNOPSIS
    Counts, in each SQL Server error log of a folder, the lines that match a pattern.

    .DESCRIPTION
    Returns one object per file. Throws when the folder does not exist or when a file is not
    a SQL Server error log, naming the file: an empty report must never pass for "nothing to
    report".

    .EXAMPLE
    Get-ErrorLogSummary -Path data/errorlog -Pattern 'Login failed'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,
        [string] $Pattern = 'Login failed'
    )
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "Error log folder not found: $Path"
    }
    # Reads the whole folder at once.
    foreach ($file in Get-Item -Path $Path) {
        $file = [pscustomobject]@{ Name = $file.Name; FullName = Join-Path $file.FullName '*' }
        $lines = Get-Content -Path $file.FullName
        if ($lines.Count -gt 0 -and $lines[0] -notmatch '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{2} ') {
            throw "Not a SQL Server error log: $($file.FullName)"
        }
        $found = $lines | Select-String -Pattern $Pattern
        [pscustomobject]@{
            File    = $file.Name
            Lines   = $lines.Count
            Matches = @($found).Count
            First   = if ($found) { $found[0].Line.Substring(0, 22) }
            Last    = if ($found) { $found[-1].Line.Substring(0, 22) }
        }
    }
}
