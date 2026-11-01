# Clip 7.2: the credential read from the vault in each runspace, then once in the session.
# SecretManagement runs the vault in one pipeline at a time: the runspaces that ask while
# another one reads fail.
$inRunspaces = 1..6 | ForEach-Object -ThrottleLimit 6 -Parallel {
    $runspace = $_
    try {
        $null = Get-Secret -Vault PachaOps -Name sql-lab -ErrorAction Stop
        [pscustomobject]@{ Runspace = $runspace; Read = 'ok'; Error = $null }
    }
    catch {
        # In the catch block, $_ is the error, not the input object.
        [pscustomobject]@{ Runspace = $runspace; Read = 'failed'; Error = $_.Exception.Message }
    }
}
$inRunspaces | Sort-Object -Property Runspace
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$once = 1..6 | ForEach-Object -ThrottleLimit 6 -Parallel {
    ($using:credential).UserName
}
'Read once in the session, passed by $using: {0} runspaces got {1}' -f $once.Count, ($once | Sort-Object -Unique)
