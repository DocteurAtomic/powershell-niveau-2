<#
.SYNOPSIS
Builds PachaOps into out/PachaOps, the only folder the team publishes, and publishes it.

.DESCRIPTION
Copies from src/PachaOps the manifest, the root module, the functions of Public and
CHANGELOG.md, and nothing else: tests, settings and work files that sit next to the module
stay out of the package. FileList in the manifest would not keep them out: it is an
inventory, and Publish-PSResource packs the whole folder.

Then validates the manifest of the copy with Test-ModuleManifest. With -Repository, publishes
the copy without the dependency check (dbatools comes from the PowerShell Gallery, not from
the team's repository), and refuses a version that the repository already has: a file
repository replaces it without a word.

Returns the module that was built, with its version and, with -Repository, where it went.

.EXAMPLE
./build.ps1

.EXAMPLE
./build.ps1 -Repository PachaTeam
#>
[CmdletBinding()]
param(
    # The repository to publish to, registered by Register-PSResourceRepository.
    [string] $Repository,
    # The module to build.
    [string] $SourcePath = (Join-Path $PSScriptRoot 'src' 'PachaOps'),
    # The folder that receives PachaOps.
    [string] $OutputPath = (Join-Path $PSScriptRoot 'out')
)
$ErrorActionPreference = 'Stop'
$destination = Join-Path $OutputPath 'PachaOps'
if (Test-Path -Path $destination) {
    Remove-Item -Path $destination -Recurse -Force
}
New-Item -ItemType Directory -Path (Join-Path $destination 'Public') | Out-Null

Copy-Item -Path (Join-Path $SourcePath 'PachaOps.psd1'), (Join-Path $SourcePath 'PachaOps.psm1'),
    (Join-Path $SourcePath 'CHANGELOG.md') -Destination $destination
Get-ChildItem -Path (Join-Path $SourcePath 'Public') -Filter *.ps1 -File |
    Where-Object -Property Name -NotLike '*.Tests.ps1' |
    Copy-Item -Destination (Join-Path $destination 'Public')

$manifest = Test-ModuleManifest -Path (Join-Path $destination 'PachaOps.psd1')

if ($Repository) {
    $published = Find-PSResource -Name PachaOps -Version "$($manifest.Version)" -Repository $Repository -ErrorAction SilentlyContinue
    if ($published) {
        throw "PachaOps $($manifest.Version) is already in the repository $Repository. A published version does not change: raise ModuleVersion in the manifest."
    }
    Publish-PSResource -Path $destination -Repository $Repository -SkipDependenciesCheck
}

[pscustomobject]@{
    Name       = $manifest.Name
    Version    = $manifest.Version
    Path       = $destination
    Repository = if ($Repository) { $Repository }
}
