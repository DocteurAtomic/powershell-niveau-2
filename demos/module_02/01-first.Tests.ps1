# Clip 2.1: a first test of Get-BackupAge.
# Run it from the root of the clone:
#   Invoke-Pester -Path demos/module_02/01-first.Tests.ps1 -Output Detailed
# Without the BeforeAll block, the test fails: Pester runs the file in its own scope, where
# PachaOps is not imported.
BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../src/PachaOps/PachaOps.psd1" -Force
}

Describe 'Get-BackupAge' {
    It 'adds the age in days to the file' {
        $file = New-Item -ItemType File -Path TestDrive:/full.bak
        $result = Get-BackupAge -File $file -ReferenceDate $file.LastWriteTimeUtc.AddDays(3)
        $result.AgeDays | Should-Be 3
    }
}
