# A broken copy of Remove-OldBackup, used by check.ps1: also removes the files that are not backups.
function Remove-OldBackup {
    <#
    .SYNOPSIS
    Removes the backup files older than the retention, and returns what it removed.

    .EXAMPLE
    Remove-OldBackup -Path lab/backups -RetentionDays 14 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        # The folder of the backups, searched recursively.
        [Parameter(Mandatory)]
        [string] $Path,
        # Files older than this number of days are removed.
        [Parameter(Mandatory)]
        [ValidateRange(1, 3650)]
        [int] $RetentionDays,
        [datetime] $ReferenceDate = (Get-Date)
    )
    $old = Get-ChildItem -Path $Path -Recurse -File |
        Get-BackupAge -ReferenceDate $ReferenceDate |
        Where-Object AgeDays -gt $RetentionDays
    foreach ($file in $old) {
        if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove backup file')) {
            Remove-Item -LiteralPath $file.FullName -Confirm:$false
            $file
        }
    }
}
