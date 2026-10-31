# Clip 4.3: PachaOps installed from the team's repository, the dependency on dbatools, and
# versions side by side.
# Run it from the root of the clone, after 02-repository.ps1, or type the lines one after the other.
$ErrorActionPreference = 'Stop'
if (-not (Get-InstalledPSResource -Name PachaOps -Version 0.2.0 -Scope CurrentUser -ErrorAction SilentlyContinue)) {
    Install-PSResource -Name PachaOps -Version 0.2.0 -Repository PachaTeam -SkipDependencyCheck
}
Get-InstalledPSResource -Name PachaOps -Scope CurrentUser |
    Select-Object -Property Name, Version, Repository, InstalledLocation | Format-List | Out-Host

# dbatools, installed by setup/install.ps1 from the PowerShell Gallery at its fixed version.
Get-Module -Name dbatools -ListAvailable | Select-Object -Property Name, Version | Out-Host
Import-Module -Name PachaOps
Get-Module -Name PachaOps, dbatools | Select-Object -Property Name, Version, ModuleBase | Format-List | Out-Host

# A workstation without dbatools: PachaOps saved in a temporary folder, and a pwsh whose
# PSModulePath leads to that folder only.
$workstation = Join-Path ([System.IO.Path]::GetTempPath()) "workstation-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $workstation | Out-Null
try {
    Save-PSResource -Name PachaOps -Version 0.2.0 -Repository PachaTeam -Path $workstation -SkipDependencyCheck
    & pwsh -NoProfile -Command "`$env:PSModulePath = '$workstation'; Import-Module -Name PachaOps" 2>&1 |
        ForEach-Object { "$_" }
}
finally {
    Remove-Item -Path $workstation -Recurse -Force
}

# Nothing newer than 0.2.0 in the repository: Update-PSResource installs nothing.
Update-PSResource -Name PachaOps -Repository PachaTeam -SkipDependencyCheck
Get-InstalledPSResource -Name PachaOps -Scope CurrentUser | Select-Object -Property Name, Version | Out-Host

# Two versions side by side: Pester 6.2.0 and 5.9.1. Import-Module takes the newest, and
# -RequiredVersion the one you name. Each in its own process: they do not load together.
Get-Module -Name Pester -ListAvailable | Select-Object -Property Name, Version | Out-Host
& pwsh -NoProfile -Command { Import-Module -Name Pester; "Import-Module Pester: $((Get-Module -Name Pester).Version)" }
& pwsh -NoProfile -Command { Import-Module -Name Pester -RequiredVersion 5.9.1; "-RequiredVersion 5.9.1: $((Get-Module -Name Pester).Version)" }
