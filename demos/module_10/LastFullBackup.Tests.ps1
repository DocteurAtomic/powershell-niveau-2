# ci: skip. The rule of the team that dbachecks does not run under Pester 5 (clip 10.4): a
# full backup of less than seven days for every database but tempdb. Run by
# 06-team-tests.ps1, with Pester 6.2.0, which passes the instances and the credential.
param(
    [Parameter(Mandatory)]
    [string[]] $SqlInstance,
    [Parameter(Mandatory)]
    [pscredential] $SqlCredential,
    [int] $MaxAgeDays = 7
)

BeforeDiscovery {
    # One case per database, read at discovery. Connect-DbaInstance throws on an instance it
    # cannot reach, which fails the file instead of leaving the instance out in silence.
    $databases = foreach ($instance in $SqlInstance) {
        $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential
        foreach ($backup in Get-DbaLastBackup -SqlInstance $server -ExcludeDatabase tempdb) {
            @{
                Instance       = $instance
                Database       = $backup.Database
                LastFullBackup = if ($backup.LastFullBackup) { [datetime] $backup.LastFullBackup }
                MaxAgeDays     = $MaxAgeDays
            }
        }
    }
}

Describe 'Last full backup' -Tag LastFullBackup {
    It 'Database <Database> has a full backup of less than <MaxAgeDays> days on <Instance>' -ForEach $databases {
        $LastFullBackup | Should-NotBeNull -Because 'every database but tempdb has a full backup'
        $LastFullBackup | Should-BeAfter -Time "$($MaxAgeDays)days" -Ago
    }
}
