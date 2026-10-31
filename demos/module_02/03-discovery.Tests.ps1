# ci: skip - this file fails on purpose (clip 2.3): the whole file fails at discovery.
# Clip 2.3: the cases are built in BeforeAll, which runs after the discovery.
#   Invoke-Pester -Path demos/module_02/03-discovery.Tests.ps1 -Output Detailed
# At discovery $cases is still $null, and Pester 6 fails the whole file.
BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../src/PachaOps/PachaOps.psd1" -Force
    $reference = [datetime]::new(2026, 11, 2, 8, 0, 0, [System.DateTimeKind]::Utc)
    $cases = @(
        @{ Days = 1 }
        @{ Days = 7 }
        @{ Days = 30 }
    )
}

Describe 'Get-BackupAge' {
    It 'gives <Days> day(s) for a file written <Days> day(s) before the reference date' -ForEach $cases {
        $file = New-Item -ItemType File -Path TestDrive:/full.bak -Force
        $file.LastWriteTimeUtc = $reference.AddDays(-$Days)
        (Get-BackupAge -File $file -ReferenceDate $reference).AgeDays | Should-Be $Days
    }

    It 'returns the file it received' {
        $file = New-Item -ItemType File -Path TestDrive:/diff.bak
        (Get-BackupAge -File $file -ReferenceDate $reference).Name | Should-Be 'diff.bak'
    }
}
