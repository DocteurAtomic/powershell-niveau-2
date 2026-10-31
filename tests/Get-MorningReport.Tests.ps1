# The tests of Get-MorningReport, in Pester 6.2.0, without SQL Server. From the root of the
# clone:
#   Invoke-Pester -Path tests -Output Detailed
# The dbatools commands that the report calls are mocked in the module PachaOps, and they
# return objects made here. The tests check the report, not dbatools.
BeforeAll {
    Import-Module -Name "$PSScriptRoot/../src/PachaOps/PachaOps.psd1" -Force
}

Describe 'Get-MorningReport' {
    BeforeAll {
        # An inventory of two instances, written in TestDrive: one answers, one does not.
        Set-Content -Path TestDrive:/instances.csv -Value @(
            'Name,SqlInstance'
            'sql1,"sql1.pachadata.example,1433"'
            'compta01,"compta01.pachadata.example,1433"'
        )
        Mock Write-Host -ModuleName PachaOps
        Mock Connect-DbaInstance -ModuleName PachaOps {
            [pscustomobject]@{ VersionString = '17.0.4065.4' }
        }
        Mock Connect-DbaInstance -ModuleName PachaOps -ParameterFilter { $SqlInstance -like 'compta01*' } {
            throw 'The instance does not answer.'
        }
        # The mock keeps the parameters of Get-DbaDatabase: the made-up server is not a
        # DbaInstanceParameter, so the type of -SqlInstance is removed.
        Mock Get-DbaDatabase -ModuleName PachaOps -RemoveParameterType SqlInstance {
            [pscustomobject]@{ Name = 'master'; RecoveryModel = 'Simple'; LastFullBackup = [datetime]::MinValue }
            [pscustomobject]@{ Name = 'Planning'; RecoveryModel = 'Full'; LastFullBackup = [datetime]::new(2026, 11, 1, 22, 0, 0) }
        }

        $report = Get-MorningReport -InventoryPath TestDrive:/instances.csv
    }

    It 'returns one Online row per database of an instance that answers' {
        $report | Where-Object -Property Instance -EQ 'sql1' |
            Select-Object -Property Instance, Status, Version, Database |
            Should-BeEquivalent @(
                [pscustomobject]@{ Instance = 'sql1'; Status = 'Online'; Version = '17.0.4065.4'; Database = 'master' }
                [pscustomobject]@{ Instance = 'sql1'; Status = 'Online'; Version = '17.0.4065.4'; Database = 'Planning' }
            )
    }

    It 'returns one Unreachable row for an instance that does not answer' {
        $report | Where-Object -Property Instance -EQ 'compta01' |
            Select-Object -Property Instance, Status, Database |
            Should-BeEquivalent ([pscustomobject]@{ Instance = 'compta01'; Status = 'Unreachable'; Database = $null })
    }

    It 'leaves LastFullBackup empty for a database never backed up' {
        ($report | Where-Object -Property Database -EQ 'master').LastFullBackup | Should-BeNull
        ($report | Where-Object -Property Database -EQ 'Planning').LastFullBackup |
            Should-Be ([datetime]::new(2026, 11, 1, 22, 0, 0))
    }

    It 'asks dbatools for the databases without tempdb' {
        Should-Invoke Get-DbaDatabase -ModuleName PachaOps -Times 1 -Exactly -Scope Describe -ParameterFilter {
            $ExcludeDatabase -contains 'tempdb'
        }
    }
}

AfterAll {
    Remove-Module -Name PachaOps
}
