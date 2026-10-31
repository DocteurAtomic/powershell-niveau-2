# Clip 2.3: preparing and cleaning up, TestDrive and data-driven tests.
#   Invoke-Pester -Path demos/module_02/03-setup.Tests.ps1 -Output Detailed
# The cases are built in BeforeDiscovery: -ForEach is read during the discovery, before any
# BeforeAll runs. 03-discovery.Tests.ps1 shows what happens when they are built in BeforeAll.
BeforeDiscovery {
    $cases = @(
        @{ Days = 1 }
        @{ Days = 7 }
        @{ Days = 30 }
    )
}

BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../src/PachaOps/PachaOps.psd1" -Force
    $reference = [datetime]::new(2026, 11, 2, 8, 0, 0, [System.DateTimeKind]::Utc)
}

Describe 'Get-BackupAge' {
    BeforeEach {
        # A new file for each test: TestDrive keeps the files of a Describe until its end.
        $file = New-Item -ItemType File -Path TestDrive:/full.bak -Force
    }

    It 'gives <Days> day(s) for a file written <Days> day(s) before the reference date' -ForEach $cases {
        $file.LastWriteTimeUtc = $reference.AddDays(-$Days)
        (Get-BackupAge -File $file -ReferenceDate $reference).AgeDays | Should-Be $Days
    }
}

AfterAll {
    Remove-Module -Name PachaOps
}
