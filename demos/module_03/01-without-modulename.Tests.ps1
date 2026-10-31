# ci: skip - this file fails on purpose (clip 3.1): the mocks are written without -ModuleName.
# Clip 3.1: a mock defined in the test file does not reach the calls made inside PachaOps.
#   Invoke-Pester -Path demos/module_03/01-without-modulename.Tests.ps1 -Output Detailed
# The first test reads the real date. The second one deletes a real file, in TestDrive.
BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../src/PachaOps/PachaOps.psd1" -Force
    $reference = [datetime]::new(2026, 11, 2, 8, 0, 0, [System.DateTimeKind]::Utc)
}

Describe 'Get-BackupAge' {
    It 'computes the age from Get-Date when no reference date is given' {
        $file = New-Item -ItemType File -Path TestDrive:/full.bak
        $file.LastWriteTimeUtc = [datetime]::new(2026, 10, 23, 8, 0, 0, [System.DateTimeKind]::Utc)
        Mock Get-Date { $reference.ToLocalTime() }

        (Get-BackupAge -File $file).AgeDays | Should-Be 10
    }
}

Describe 'Remove-OldBackup' {
    It 'keeps the file on disk, since Remove-Item is mocked' {
        $file = New-Item -ItemType File -Path TestDrive:/backups/old.bak -Force
        $file.LastWriteTimeUtc = $reference.AddDays(-20)
        Mock Remove-Item

        Remove-OldBackup -Path TestDrive:/backups -RetentionDays 14 -ReferenceDate $reference
        Test-Path -Path TestDrive:/backups/old.bak | Should-BeTrue
    }
}

AfterAll {
    Remove-Module -Name PachaOps
}
