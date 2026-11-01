# Clip 7.2: Set-DbatoolsInsecureConnection is a setting of the process. Set in the session, it
# is seen in the runspaces; set again in a runspace, it writes its objects into the output of
# the loop.
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
1..2 | ForEach-Object -Parallel {
    'runspace {0}: sql.connection.trustcert = {1}' -f $_, (Get-DbatoolsConfigValue -FullName sql.connection.trustcert)
}
$output = 1..2 | ForEach-Object -Parallel { Set-DbatoolsInsecureConnection -SessionOnly }
'Without Out-Null, two runspaces return {0} objects of type {1}' -f $output.Count, $output[0].GetType().Name
