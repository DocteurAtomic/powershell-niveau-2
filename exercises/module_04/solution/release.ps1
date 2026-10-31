<#
.SYNOPSIS
The commands of the solution of module 4: PachaOps 0.2.1 published and installed next to 0.2.0.

.DESCRIPTION
Run from the root of the clone, once src/PachaOps has the correction of Get-MorningReport,
ModuleVersion 0.2.1, its release notes and its entry in CHANGELOG.md (the files of
solution/PachaOps). The workstation already has 0.2.0, installed from the repository.

check.ps1 -Solution runs this script on a copy of the module, with a temporary repository and
a temporary HOME.

.EXAMPLE
./exercises/module_04/solution/release.ps1
#>
[CmdletBinding()]
param(
    # The team's repository.
    [string] $Repository = 'PachaTeam',
    # The module, corrected.
    [string] $SourcePath = (Join-Path (Resolve-Path -Path "$PSScriptRoot/../../..") 'src' 'PachaOps'),
    # Where build.ps1 writes PachaOps.
    [string] $OutputPath = (Join-Path (Resolve-Path -Path "$PSScriptRoot/../../..") 'out')
)
$ErrorActionPreference = 'Stop'
$build = Join-Path (Resolve-Path -Path "$PSScriptRoot/../../..") 'build.ps1'

# 1. Build out/PachaOps from src and publish it. build.ps1 refuses a version already published.
& $build -SourcePath $SourcePath -OutputPath $OutputPath -Repository $Repository | Out-Host
Find-PSResource -Name PachaOps -Repository $Repository -Version '*' |
    Select-Object -Property Name, Version, ReleaseNotes | Format-List | Out-Host

# 2. The workstation that had 0.2.0: Update-PSResource installs 0.2.1 next to it.
Update-PSResource -Name PachaOps -Repository $Repository -SkipDependencyCheck
Get-InstalledPSResource -Name PachaOps -Scope CurrentUser | Select-Object -Property Name, Version | Out-Host

# 3. Each version loaded by -RequiredVersion, each in its own process.
foreach ($version in '0.2.0', '0.2.1') {
    & pwsh -NoProfile -Command {
        param($Version)
        Import-Module -Name PachaOps -RequiredVersion $Version
        Get-Module -Name PachaOps | Select-Object -Property Name, Version, ReleaseNotes | Format-List
    } -args $version
}
