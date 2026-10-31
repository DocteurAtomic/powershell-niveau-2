# Clip 4.1: the manifest of PachaOps, what Test-ModuleManifest checks and what a package asks for.
# Run it from the root of the clone, or type the lines one after the other.
# At module-04-start the manifest is 0.1.0, without a description, and Compress-PSResource
# fails. The clip then runs, once:
#   Update-PSModuleManifest -Path src/PachaOps/PachaOps.psd1 -ModuleVersion 0.2.0 `
#       -Description 'The scripts of the PachaData operations team: ...' -ReleaseNotes '0.2.0: ...'
# and writes src/PachaOps/CHANGELOG.md. From module-04-end on, the manifest is already 0.2.0.
$ErrorActionPreference = 'Stop'
Test-ModuleManifest -Path src/PachaOps/PachaOps.psd1 |
    Select-Object -Property Name, Version, Author, Description, ReleaseNotes | Format-List | Out-Host

# A package built without publishing it, in a temporary folder: Compress-PSResource validates
# the manifest as Publish-PSResource does.
$package = Join-Path ([System.IO.Path]::GetTempPath()) "pachaops-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $package | Out-Null
try {
    Compress-PSResource -Path src/PachaOps -DestinationPath $package
    Get-ChildItem -Path $package | Select-Object -Property Name, Length | Out-Host
}
finally {
    Remove-Item -Path $package -Recurse -Force
}
