function Send-BackupAlert {
    <#
    .SYNOPSIS
    Posts the problems of a backup check (Late, Missing, Unreachable) to the webhook of the team.

    .DESCRIPTION
    The message is a JSON body with one property, text: a first line with the number of
    problems, then one line per problem. The rows come from the backup check of module 7
    (Instance, Database, LastFullBackup, LastLogBackup, Status).

    .EXAMPLE
    Send-BackupAlert -Uri (Get-Secret -Vault PachaOps -Name m09_team_webhook -AsPlainText) -BackupCheck $rows
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Uri,
        [Parameter(Mandatory)]
        [object[]] $BackupCheck,
        # How many requests at most, the first one included.
        [ValidateRange(1, 10)]
        [int] $MaximumAttempt = 3,
        # How long to wait between two requests.
        [ValidateRange(0, 300)]
        [int] $RetryIntervalSec = 1
    )
    $problems = @($BackupCheck | Where-Object -Property Status -NE 'Ok')
    $lines = @("Backup check: $($problems.Count) problem(s)")
    foreach ($row in $problems) {
        $lines += if ($row.Database) { "$($row.Instance)/$($row.Database): $($row.Status)" } else { "$($row.Instance): $($row.Status)" }
    }
    $body = @{ text = $lines -join "`n" } | ConvertTo-Json

    # Retries are left to Invoke-RestMethod.
    Invoke-RestMethod -Uri $Uri -Method Post -Body $body -ContentType 'application/json' `
        -MaximumRetryCount ($MaximumAttempt - 1) -RetryIntervalSec ([math]::Max(1, $RetryIntervalSec)) | Out-Null
}
