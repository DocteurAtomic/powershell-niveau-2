# Solution of the exercise of module 3: the tests of Remove-OldBackup, in Pester 6.2.0.
#   ./exercises/module_03/check.ps1 -Solution
param(
    [string] $ModulePath = "$PSScriptRoot/../../../src/PachaOps/PachaOps.psd1"
)

BeforeAll {
    Import-Module -Name $ModulePath -Force
    $reference = [datetime]::new(2026, 11, 2, 8, 0, 0, [System.DateTimeKind]::Utc)
    $folder = Join-Path $TestDrive 'backups'
}

Describe 'Remove-OldBackup' {
    BeforeAll {
        # Four files in TestDrive, dated from the reference: two old backups, a recent one,
        # and an old file that is not a backup.
        $files = @{
            'sql1/FULL/old-full.bak'       = 20
            'sql1/FULL/recent-full.bak'    = 3
            'sql1/LOG/old-log.trn'         = 20
            'sql1/FULL/README-restore.txt' = 30
        }
        foreach ($name in $files.Keys) {
            $file = New-Item -ItemType File -Path (Join-Path $folder $name) -Force
            $file.LastWriteTimeUtc = $reference.AddDays(-$files[$name])
        }
        # The mock is injected in PachaOps, where Remove-OldBackup calls Remove-Item.
        Mock Remove-Item -ModuleName PachaOps
    }

    It 'removes the backup files older than the retention' {
        Remove-OldBackup -Path $folder -RetentionDays 14 -ReferenceDate $reference
        Should-Invoke Remove-Item -ModuleName PachaOps -Times 1 -Exactly -ParameterFilter { $LiteralPath -like '*old-full.bak' }
        Should-Invoke Remove-Item -ModuleName PachaOps -Times 1 -Exactly -ParameterFilter { $LiteralPath -like '*old-log.trn' }
    }

    It 'keeps the recent backups and the files that are not backups' {
        Remove-OldBackup -Path $folder -RetentionDays 14 -ReferenceDate $reference
        Should-Invoke Remove-Item -ModuleName PachaOps -Times 2 -Exactly
        Should-Invoke Remove-Item -ModuleName PachaOps -Times 0 -ParameterFilter {
            $LiteralPath -like '*recent-full.bak' -or $LiteralPath -like '*README-restore.txt'
        }
    }

    It 'returns the files it removed' {
        $removed = Remove-OldBackup -Path $folder -RetentionDays 14 -ReferenceDate $reference
        $removed.Name | Should-BeCollection @('old-full.bak', 'old-log.trn')
    }

    It 'removes nothing with -WhatIf' {
        $removed = Remove-OldBackup -Path $folder -RetentionDays 14 -ReferenceDate $reference -WhatIf
        Should-Invoke Remove-Item -ModuleName PachaOps -Times 0
        $removed | Should-BeNull
    }
}
