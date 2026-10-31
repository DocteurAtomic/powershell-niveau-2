# Returns the workstation and the clone to their state before module 4: every version of
# PachaOps uninstalled for the user, the repository PachaTeam unregistered, its packages and
# out/ removed. setup/run-checks.ps1 runs it after the other scripts of the module. Run it
# yourself only once the exercise is checked: it removes what the exercise installed too.
$ErrorActionPreference = 'Stop'
Get-InstalledPSResource -Name PachaOps -Scope CurrentUser -ErrorAction SilentlyContinue |
    ForEach-Object { Uninstall-PSResource -Name PachaOps -Version "$($_.Version)" -Scope CurrentUser }
if (Get-PSResourceRepository -Name PachaTeam -ErrorAction SilentlyContinue) {
    Unregister-PSResourceRepository -Name PachaTeam
}
Remove-Item -Path lab/repository/PachaOps.*.nupkg, out -Recurse -Force -ErrorAction SilentlyContinue
'PachaOps uninstalled, PachaTeam unregistered, lab/repository and out/ emptied.'
