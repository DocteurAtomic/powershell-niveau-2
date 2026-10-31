# Exercise of module 2: the tests of Get-ErrorLogSummary, in Pester 6.2.0.
# Run them:      Invoke-Pester -Path exercises/module_02/Get-ErrorLogSummary.Tests.ps1 -Output Detailed
# Check them:    ./exercises/module_02/check.ps1
# Keep the param block: check.ps1 passes here the path of another copy of the function.
param(
    [string] $ModulePath = "$PSScriptRoot/../../src/PachaOps/PachaOps.psd1",
    [string] $ErrorLogPath = "$PSScriptRoot/../../data/errorlog"
)

BeforeAll {
    Import-Module -Name $ModulePath -Force
}

Describe 'Get-ErrorLogSummary' {
    It 'returns one object per file of data/errorlog' {
        # Write the test.
    }

    It 'counts the lines and the matching lines of each file' {
        # Write the test.
    }

    It 'returns Lines 0 and Matches 0 for an empty file' {
        # Write the test.
    }

    It 'throws when the folder does not exist' {
        # Write the test.
    }
}
