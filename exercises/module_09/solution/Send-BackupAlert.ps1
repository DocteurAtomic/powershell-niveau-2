function Send-BackupAlert {
    <#
    .SYNOPSIS
    Posts the problems of a backup check (Late, Missing, Unreachable) to the webhook of the team.

    .DESCRIPTION
    The message is a JSON body with one property, text: a first line with the number of
    problems, then one line per problem. The rows come from the backup check of module 7
    (Instance, Database, LastFullBackup, LastLogBackup, Status).

    A request is sent again only when the answer says the server may accept it later: 429 (too
    many requests) or a status of 500 to 599. Any other error status means the message itself
    is refused, and sending it again changes nothing. Returns the status and the number of
    requests sent; throws when the message could not be delivered.

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

    for ($attempt = 1; $attempt -le $MaximumAttempt; $attempt++) {
        # -SkipHttpErrorCheck: an error status does not throw, and -StatusCodeVariable is set.
        $status = $null
        $null = Invoke-RestMethod -Uri $Uri -Method Post -Body $body -ContentType 'application/json' `
            -SkipHttpErrorCheck -StatusCodeVariable status
        if ($status -ge 200 -and $status -le 299) {
            return [pscustomobject]@{ StatusCode = $status; Attempts = $attempt }
        }
        $transient = $status -eq 429 -or ($status -ge 500 -and $status -le 599)
        if (-not $transient -or $attempt -eq $MaximumAttempt) { break }
        Write-Verbose "Status $status, attempt $attempt of ${MaximumAttempt}: waiting $RetryIntervalSec s."
        Start-Sleep -Seconds $RetryIntervalSec
    }
    throw "The webhook answered $status after $attempt request(s): the message was not delivered."
}
