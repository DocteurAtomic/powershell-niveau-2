function Get-BackupAge {
    <#
    .SYNOPSIS
    Adds to each backup file its age in days.

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
        $age = ($ReferenceDate - $File.LastWriteTimeUtc).TotalDays
        Write-Verbose "$($File.Name): $([math]::Round($age, 2)) days"
        $File | Add-Member -NotePropertyName AgeDays -NotePropertyValue ([math]::Round($age, 2)) -Force -PassThru
    }
}
