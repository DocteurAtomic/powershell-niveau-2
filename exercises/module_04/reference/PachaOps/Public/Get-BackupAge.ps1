function Get-BackupAge {
    <#
    .SYNOPSIS
    Adds to each backup file its age in days.

    .DESCRIPTION
    The age is the time elapsed between the last write of the file and the reference date,
    both in UTC. A reference date given without a time zone, such as '2026-11-02', is read
    as local time.

    .EXAMPLE
    Get-ChildItem lab/backups -Recurse -File | Get-BackupAge
    #>
    [CmdletBinding()]
    param(
        # The backup files, from Get-ChildItem.
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileInfo] $File,
        # The moment the age is computed for; now by default.
        [datetime] $ReferenceDate = (Get-Date)
    )
    process {
        # LastWriteTimeUtc is in UTC: the reference date goes to UTC before the subtraction.
        $age = ($ReferenceDate.ToUniversalTime() - $File.LastWriteTimeUtc).TotalDays
        Write-Verbose "$($File.Name): $([math]::Round($age, 2)) days"
        $File | Add-Member -NotePropertyName AgeDays -NotePropertyValue ([math]::Round($age, 2)) -Force -PassThru
    }
}
