# The tests of Get-BackupAge, in Pester 6.2.0. From the root of the clone:
#   Invoke-Pester -Path tests -Output Detailed
# The dates are instants given in UTC and turned into local time where the function expects
# it: the tests give the same result on a machine in Paris, in UTC or anywhere else.
BeforeDiscovery {
    $cases = @(
        @{ Days = 1 }
        @{ Days = 7 }
        @{ Days = 30 }
    )
}

BeforeAll {
    Import-Module -Name "$PSScriptRoot/../src/PachaOps/PachaOps.psd1" -Force
    $reference = [datetime]::new(2026, 11, 2, 8, 0, 0, [System.DateTimeKind]::Utc)
}

Describe 'Get-BackupAge' {
    BeforeEach {
        $file = New-Item -ItemType File -Path TestDrive:/full.bak -Force
    }

    It 'returns the file it received, with AgeDays' {
        $result = Get-BackupAge -File $file -ReferenceDate $reference
        $result | Should-HaveType ([System.IO.FileInfo])
        $result.Name | Should-Be 'full.bak'
    }

    It 'gives <Days> day(s) for a file written <Days> day(s) before the reference date' -ForEach $cases {
        $file.LastWriteTimeUtc = $reference.AddDays(-$Days)
        (Get-BackupAge -File $file -ReferenceDate $reference).AgeDays | Should-Be $Days
    }

    It 'gives 10 days when the reference date is in local time' {
        # Called without -ReferenceDate, the function takes Get-Date: 9:00 in Paris here.
        $file.LastWriteTimeUtc = [datetime]::new(2026, 10, 23, 8, 0, 0, [System.DateTimeKind]::Utc)
        $local = $reference.ToLocalTime()
        (Get-BackupAge -File $file -ReferenceDate $local).AgeDays | Should-Be 10
    }
}

AfterAll {
    Remove-Module -Name PachaOps
}
