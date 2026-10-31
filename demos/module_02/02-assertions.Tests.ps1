# Clip 2.2: the assertions of Pester 6, one family per test, and the syntax of Pester 5.
#   Invoke-Pester -Path demos/module_02/02-assertions.Tests.ps1 -Output Detailed
BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../src/PachaOps/PachaOps.psd1" -Force
}

Describe 'Get-BackupAge' {
    It 'returns the file it received, as a FileInfo' {
        $file = New-Item -ItemType File -Path TestDrive:/full.bak
        $result = Get-BackupAge -File $file -ReferenceDate $file.LastWriteTimeUtc
        $result | Should-HaveType ([System.IO.FileInfo])
        $result.Name | Should-Be 'full.bak'
    }

    It 'returns one age per file' {
        $now = [datetime]::UtcNow
        $files = foreach ($days in 1, 7, 30) {
            $file = New-Item -ItemType File -Path "TestDrive:/backup-$days.bak"
            $file.LastWriteTimeUtc = $now.AddDays(-$days)
            Get-Item -Path $file.FullName
        }
        $files | Get-BackupAge -ReferenceDate $now |
            Select-Object -ExpandProperty AgeDays |
            Should-BeCollection @(1, 7, 30)
    }

    It 'gives the name and the age' {
        $file = New-Item -ItemType File -Path TestDrive:/diff.bak
        $result = Get-BackupAge -File $file -ReferenceDate $file.LastWriteTimeUtc.AddDays(3)
        $result | Select-Object -Property Name, AgeDays |
            Should-BeEquivalent ([pscustomobject]@{ Name = 'diff.bak'; AgeDays = 3 })
    }
}

Describe 'Remove-OldBackup' {
    It 'refuses a retention of zero day' {
        { Remove-OldBackup -Path TestDrive:/ -RetentionDays 0 } |
            Should-Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
    }

    It 'is read the same way with the syntax of Pester 5' {
        { Remove-OldBackup -Path TestDrive:/ -RetentionDays 0 } |
            Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
    }
}
