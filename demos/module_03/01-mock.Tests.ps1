# Clip 3.1: Get-BackupAge called without -ReferenceDate, as the scripts of the team call it.
# The date it reads from Get-Date is replaced by a mock, in the module PachaOps.
#   Invoke-Pester -Path demos/module_03/01-mock.Tests.ps1 -Output Detailed
# 01-without-modulename.Tests.ps1 shows the same mock without -ModuleName.
BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../src/PachaOps/PachaOps.psd1" -Force
}

Describe 'Get-BackupAge' {
    It 'computes the age from Get-Date when no reference date is given' {
        $file = New-Item -ItemType File -Path TestDrive:/full.bak
        $file.LastWriteTimeUtc = [datetime]::new(2026, 10, 23, 8, 0, 0, [System.DateTimeKind]::Utc)
        # Like the real Get-Date, the mock returns a local time.
        Mock Get-Date -ModuleName PachaOps {
            [datetime]::new(2026, 11, 2, 8, 0, 0, [System.DateTimeKind]::Utc).ToLocalTime()
        }

        (Get-BackupAge -File $file).AgeDays | Should-Be 10
        Should-Invoke Get-Date -ModuleName PachaOps -Times 1 -Exactly
    }
}

AfterAll {
    Remove-Module -Name PachaOps
}
