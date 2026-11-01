# Clip 13.2: a night after a commit that raises the version to 0.2.1 and breaks a test. The
# evening task runs in a temporary copy of the clone where the manifest says 0.2.1 and the
# tests of Get-BackupAge expect 11 days instead of 10 (the broken test of clip 5.1): it does
# not publish 0.2.1, still runs the checks, and says so. The clone and its lab/nightly do not
# change.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
$work = Join-Path ([System.IO.Path]::GetTempPath()) "demo-13-broken-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
    Copy-Item -Path (Join-Path $root 'src'), (Join-Path $root 'tests'), (Join-Path $root 'demos'),
        (Join-Path $root 'build.ps1') -Destination $work -Recurse
    $testFile = Join-Path $work 'tests' 'Get-BackupAge.Tests.ps1'
    (Get-Content -Path $testFile -Raw) -replace 'Should-Be 10', 'Should-Be 11' | Set-Content -Path $testFile -NoNewline
    $manifest = Join-Path $work 'src' 'PachaOps' 'PachaOps.psd1'
    (Get-Content -Path $manifest -Raw) -replace "ModuleVersion = '0.2.0'", "ModuleVersion = '0.2.1'" | Set-Content -Path $manifest -NoNewline
    Push-Location -Path $work
    & pwsh -NoProfile -NonInteractive -File demos/module_13/nightly.ps1 | Out-Host
    "exit code: $LASTEXITCODE"
    if ($LASTEXITCODE -ne 1) { throw "The evening task should fail on a broken test, and it returned $LASTEXITCODE." }
    Find-PSResource -Name PachaOps -Repository PachaTeam -Version '*' |
        Select-Object -Property Name, Version, Repository | Format-Table | Out-String
}
finally {
    Pop-Location
    Remove-Item -Path $work -Recurse -Force
}
