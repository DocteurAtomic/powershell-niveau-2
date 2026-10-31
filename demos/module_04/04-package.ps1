# Clip 4.4: what goes into the package, the folder out/PachaOps built by build.ps1, and a
# version published twice.
# Run it from the root of the clone, after 02-repository.ps1, or type the lines one after the other.
$ErrorActionPreference = 'Stop'
function Get-PackageContent {
    # The files of a .nupkg, which is a zip archive.
    param([string] $Path)
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try { $archive.Entries.FullName | Sort-Object } finally { $archive.Dispose() }
}
$package = Join-Path ([System.IO.Path]::GetTempPath()) "pachaops-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path (Join-Path $package 'src'), (Join-Path $package 'filelist') | Out-Null
try {
    # A colleague's notes and a test file, next to the module.
    Set-Content -Path src/PachaOps/notes.md -Value 'To do: remove -Password from Get-MorningReport.'
    Copy-Item -Path tests/Get-MorningReport.Tests.ps1 -Destination src/PachaOps
    try {
        Compress-PSResource -Path src/PachaOps -DestinationPath (Join-Path $package 'src')
        Get-PackageContent -Path (Join-Path $package 'src' 'PachaOps.0.2.0.nupkg')

        # FileList names the files of the module, in a copy of the folder: the package does not change.
        $copy = Join-Path $package 'copy' 'PachaOps'
        Copy-Item -Path src/PachaOps -Destination $copy -Recurse
        Update-PSModuleManifest -Path (Join-Path $copy 'PachaOps.psd1') -FileList 'PachaOps.psd1', 'PachaOps.psm1', 'CHANGELOG.md'
        Compress-PSResource -Path $copy -DestinationPath (Join-Path $package 'filelist')
        ''
        Get-PackageContent -Path (Join-Path $package 'filelist' 'PachaOps.0.2.0.nupkg')
    }
    finally {
        Remove-Item -Path src/PachaOps/notes.md, src/PachaOps/Get-MorningReport.Tests.ps1
    }

    # The team publishes out/PachaOps, which build.ps1 rebuilds from what the module needs.
    ./build.ps1 | Out-Host
    Get-ChildItem -Path out/PachaOps -Recurse -File -Name | Out-Host

    # The same version published again: the file repository replaces it, without a word.
    $before = (Get-Item -Path lab/repository/PachaOps.0.2.0.nupkg).LastWriteTime
    Publish-PSResource -Path out/PachaOps -Repository PachaTeam -SkipDependenciesCheck
    $after = (Get-Item -Path lab/repository/PachaOps.0.2.0.nupkg).LastWriteTime
    "PachaOps.0.2.0.nupkg: $($before.ToString('HH:mm:ss.fff')), then $($after.ToString('HH:mm:ss.fff'))"

    # build.ps1 -Repository refuses it.
    try {
        ./build.ps1 -Repository PachaTeam
    }
    catch {
        "Caught: $($_.Exception.Message)"
    }
}
finally {
    Remove-Item -Path $package -Recurse -Force
}
