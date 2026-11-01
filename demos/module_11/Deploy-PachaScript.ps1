function Deploy-PachaScript {
    <#
    .SYNOPSIS
    Applies the versioned SQL scripts of the team to SQL Server instances, each script once
    per instance.

    .DESCRIPTION
    The scripts of the folder are applied in the order of their names (0001-..., 0002-...).
    Each database keeps the list of the scripts applied to it in the table
    dbo.DeploymentJournal, which the first script of the team creates. A script already in the
    journal is not applied again. A script whose content changed since it was applied is
    refused: a script that has been applied is never edited, the change goes into a new one.

    Each script runs in a transaction, with its line in the journal: both are written, or
    neither. The transaction is held on a connection of its own, by SMO, which also splits the
    script on its GO lines. A script that moves to another database (USE) is rolled back. On an
    instance, the first script that fails stops the others.

    -WhatIf says which scripts would be applied, and applies none. One object per script and
    per instance: SqlInstance, Database, Script, Status (Applied, AlreadyApplied, Changed,
    Failed, Unreachable) and Message.

    .EXAMPLE
    . ./demos/module_11/Deploy-PachaScript.ps1
    Deploy-PachaScript -SqlInstance 'localhost,14534' -SqlCredential (Get-Secret -Vault PachaOps -Name sql-lab) -Path demos/module_11/scripts -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string[]] $SqlInstance,
        [Parameter(Mandatory)]
        [pscredential] $SqlCredential,
        # The folder of the scripts.
        [Parameter(Mandatory)]
        [string] $Path,
        # The database that receives the scripts and keeps their journal.
        [string] $Database = 'DBA'
    )
    $scripts = foreach ($file in Get-ChildItem -Path $Path -Filter *.sql | Sort-Object -Property Name) {
        # The checksum is that of the text with Unix line endings: a clone made on Windows has
        # CRLF, and the same script must not look changed there.
        $text = [System.IO.File]::ReadAllText($file.FullName) -replace "`r`n", "`n"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        [pscustomobject]@{
            Name     = $file.Name
            Text     = $text
            Checksum = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
        }
    }
    # Who and from where: every member of the team connects as the same SQL login.
    $operator = [System.Environment]::UserName -replace "'", "''"
    $computer = [System.Environment]::MachineName -replace "'", "''"

    # The object of one script on one instance; it reads $instance from the loop.
    $report = {
        param($Script, $Status, $Message)
        [pscustomobject]@{ SqlInstance = $instance; Database = $Database; Script = $Script; Status = $Status; Message = $Message }
    }

    foreach ($instance in $SqlInstance) {
        try {
            $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential -Database $Database `
                -NonPooledConnection -WarningAction SilentlyContinue
        }
        catch {
            & $report $null 'Unreachable' $_.Exception.Message
            continue
        }
        try {
            $journal = @{}
            $rows = Invoke-DbaQuery -SqlInstance $server -Database $Database -EnableException -Query @'
IF OBJECT_ID(N'dbo.DeploymentJournal', N'U') IS NOT NULL
    SELECT ScriptName, Checksum FROM dbo.DeploymentJournal;
'@
            foreach ($row in $rows) { $journal[$row.ScriptName] = $row.Checksum }

            foreach ($script in $scripts) {
                if ($journal.ContainsKey($script.Name)) {
                    if ($journal[$script.Name] -eq $script.Checksum) {
                        & $report $script.Name 'AlreadyApplied'
                        continue
                    }
                    & $report $script.Name 'Changed' 'The script changed after it was applied: write a new script instead.'
                    break
                }
                if (-not $PSCmdlet.ShouldProcess("$instance, database $Database", "Apply $($script.Name)")) { continue }
                $insert = "INSERT INTO dbo.DeploymentJournal (ScriptName, Checksum, AppliedBy, AppliedFrom) " +
                    "VALUES (N'$($script.Name -replace "'", "''")', '$($script.Checksum)', N'$operator', N'$computer');"
                $connection = $server.ConnectionContext
                $connection.BeginTransaction()
                try {
                    $null = $connection.ExecuteNonQuery($script.Text)
                    # A USE in the script would send the rest, and the line of the journal, elsewhere.
                    $current = $connection.ExecuteScalar('SELECT DB_NAME();')
                    if ($current -ne $Database) { throw "The script moved to the database $current (USE): a script of the team does not name its database." }
                    $null = $connection.ExecuteNonQuery($insert)
                    $connection.CommitTransaction()
                }
                catch {
                    if ($connection.TransactionDepth -gt 0) { $connection.RollBackTransaction() }
                    # The message of SQL Server is the innermost exception.
                    $exception = $_.Exception
                    while ($exception.InnerException) { $exception = $exception.InnerException }
                    & $report $script.Name 'Failed' $exception.Message
                    break
                }
                & $report $script.Name 'Applied'
            }
        }
        finally {
            $null = $server | Disconnect-DbaInstance -WhatIf:$false -Confirm:$false
        }
    }
}
