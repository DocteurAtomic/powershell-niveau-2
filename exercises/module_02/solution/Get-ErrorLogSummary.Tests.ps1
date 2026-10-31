# Solution of the exercise of module 2: the tests of Get-ErrorLogSummary, in Pester 6.2.0.
#   ./exercises/module_02/check.ps1 -Solution
param(
    [string] $ModulePath = "$PSScriptRoot/../../../src/PachaOps/PachaOps.psd1",
    [string] $ErrorLogPath = "$PSScriptRoot/../../../data/errorlog"
)

BeforeAll {
    Import-Module -Name $ModulePath -Force
}

Describe 'Get-ErrorLogSummary' {
    BeforeAll {
        $summary = Get-ErrorLogSummary -Path $ErrorLogPath -Pattern 'Login failed'
    }

    It 'returns one object per file of data/errorlog' {
        $summary.File | Should-BeCollection @('errorlog.1', 'errorlog.2', 'errorlog.3')
    }

    It 'counts the lines and the matching lines of each file' {
        $summary | Sort-Object -Property File | Select-Object -Property File, Lines, Matches |
            Should-BeEquivalent @(
                [pscustomobject]@{ File = 'errorlog.1'; Lines = 25; Matches = 7 }
                [pscustomobject]@{ File = 'errorlog.2'; Lines = 27; Matches = 8 }
                [pscustomobject]@{ File = 'errorlog.3'; Lines = 19; Matches = 4 }
            )
    }

    It 'returns Lines 0 and Matches 0 for an empty file' {
        $folder = New-Item -ItemType Directory -Path TestDrive:/empty
        New-Item -ItemType File -Path (Join-Path $folder 'errorlog') | Out-Null
        $result = Get-ErrorLogSummary -Path $folder
        $result | Select-Object -Property File, Lines, Matches |
            Should-BeEquivalent ([pscustomobject]@{ File = 'errorlog'; Lines = 0; Matches = 0 })
    }

    It 'throws when the folder does not exist' {
        { Get-ErrorLogSummary -Path (Join-Path $TestDrive 'missing') } |
            Should-Throw -ExceptionMessage 'Error log folder not found*'
    }
}
