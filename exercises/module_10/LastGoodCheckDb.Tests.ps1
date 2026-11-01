# The CHECKDB rule of the team, in Pester 6.2.0: every database but tempdb has a good
# DBCC CHECKDB of less than seven days. run-audit.ps1 runs this file in a process of its own
# and passes the instances and the credential. Write the tests (README.md).
param(
    [Parameter(Mandatory)]
    [string[]] $SqlInstance,
    [Parameter(Mandatory)]
    [pscredential] $SqlCredential,
    [int] $MaxAgeDays = 7
)

Describe 'Last good CHECKDB' -Tag LastGoodCheckDb {
}
