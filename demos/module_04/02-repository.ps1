# Clip 4.2: the team's repository, a folder of the clone (lab/repository, ignored by git), and
# the first publication of PachaOps.
# Run it from the root of the clone, or type the lines one after the other.
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path lab/repository -Force | Out-Null
if (-not (Get-PSResourceRepository -Name PachaTeam -ErrorAction SilentlyContinue)) {
    Register-PSResourceRepository -Name PachaTeam -Uri (Resolve-Path -Path lab/repository).Path -Trusted
}
Get-PSResourceRepository | Out-Host

# PachaOps requires dbatools, which is not in the team's repository.
try {
    Publish-PSResource -Path src/PachaOps -Repository PachaTeam -ErrorAction Stop
}
catch {
    "Caught: $($_.Exception.Message)"
}

# A published version does not change: this script publishes 0.2.0 only once.
if (-not (Find-PSResource -Name PachaOps -Version 0.2.0 -Repository PachaTeam -ErrorAction SilentlyContinue)) {
    Publish-PSResource -Path src/PachaOps -Repository PachaTeam -SkipDependenciesCheck
}
Get-ChildItem -Path lab/repository | Select-Object -Property Name, Length | Out-Host
Find-PSResource -Name PachaOps -Repository PachaTeam |
    Select-Object -Property Name, Version, Author, Description, Dependencies, ReleaseNotes | Format-List | Out-Host
Find-PSResource -Name PachaOps -Repository PachaTeam -Version '*' | Out-Host
