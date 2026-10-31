# Exercise of module 3: the tests of Remove-OldBackup, in Pester 6.2.0, with Remove-Item mocked.
# Run them:      Invoke-Pester -Path exercises/module_03/Remove-OldBackup.Tests.ps1 -Output Detailed
# Check them:    ./exercises/module_03/check.ps1
# Keep the param block: check.ps1 passes here the path of another copy of the function.
# Create the backup files in TestDrive only, never in lab/backups.
param(
    [string] $ModulePath = "$PSScriptRoot/../../src/PachaOps/PachaOps.psd1"
)

BeforeAll {
    Import-Module -Name $ModulePath -Force
}

Describe 'Remove-OldBackup' {
    It 'removes the backup files older than the retention' {
        # Write the test.
    }

    It 'keeps the recent backups and the files that are not backups' {
        # Write the test.
    }

    It 'returns the files it removed' {
        # Write the test.
    }

    It 'removes nothing with -WhatIf' {
        # Write the test.
    }
}
