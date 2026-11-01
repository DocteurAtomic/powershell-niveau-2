# The CHECKDB rule of the team, in Pester 6.2.0: every database but tempdb has a good
# DBCC CHECKDB of less than seven days. run-audit.ps1 runs this file in a process of its own
# and passes the instances and the credential.
param(
    [Parameter(Mandatory)]
    [string[]] $SqlInstance,
    [Parameter(Mandatory)]
    [pscredential] $SqlCredential,
    [int] $MaxAgeDays = 7
)

BeforeDiscovery {
    # One case per database, read at discovery. Connect-DbaInstance throws on an instance it
    # cannot reach: the file fails instead of leaving the instance out.
    $databases = foreach ($instance in $SqlInstance) {
        $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential
        foreach ($check in Get-DbaLastGoodCheckDb -SqlInstance $server -ExcludeDatabase tempdb) {
            @{
                Instance        = $instance
                Database        = $check.Database
                LastGoodCheckDb = $check.LastGoodCheckDb
                MaxAgeDays      = $MaxAgeDays
            }
        }
    }
}

Describe 'Last good CHECKDB' -Tag LastGoodCheckDb {
    It 'Database <Database> has a good CHECKDB of less than <MaxAgeDays> days on <Instance>' -ForEach $databases {
        $LastGoodCheckDb | Should-NotBeNull -Because 'DBCC CHECKDB has never succeeded on this database'
        $LastGoodCheckDb | Should-BeAfter -Time "$($MaxAgeDays)days" -Ago
    }
}
