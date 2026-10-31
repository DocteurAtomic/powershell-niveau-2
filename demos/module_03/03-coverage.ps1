# Clip 3.3: the tests of the team, run with code coverage on the module PachaOps.
# Run it from the root of the clone:
#   ./demos/module_03/03-coverage.ps1
#   ./demos/module_03/03-coverage.ps1 -UseBreakpoints
# The default collector of Pester 6 does not count the default value of a parameter, such as
# (Get-Date) in Get-BackupAge, even when it runs; the breakpoint collector of Pester 5 does.
param(
    # Collect the coverage with breakpoints, as Pester 5 did: slower.
    [switch] $UseBreakpoints
)
$configuration = New-PesterConfiguration
$configuration.Run.Path = 'tests'
$configuration.Run.PassThru = $true
$configuration.CodeCoverage.Enabled = $true
$configuration.CodeCoverage.Path = 'src/PachaOps'
$configuration.CodeCoverage.OutputFormat = 'Cobertura'
$configuration.CodeCoverage.OutputPath = 'coverage.xml'
$configuration.CodeCoverage.UseBreakpoints = $UseBreakpoints.IsPresent
$result = Invoke-Pester -Configuration $configuration

# The commands that no test ran, by file, with their line numbers.
$result.CodeCoverage.CommandsMissed |
    Group-Object -Property { Split-Path -Path $_.File -Leaf } |
    Select-Object -Property Name, Count, @{ Name = 'Lines'; Expression = { ($_.Group.Line | Sort-Object -Unique) -join ', ' } } |
    Format-Table -AutoSize | Out-Host
