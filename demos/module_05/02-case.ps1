# Clip 5.2: the test of a colleague who works on Windows, then its correction. Each runs in a
# copy of the clone, as tests/PachaOps.Tests.ps1, in a child pwsh. On Linux, the folder public
# does not exist: the folder is Public.
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
$work = Join-Path ([System.IO.Path]::GetTempPath()) "demo-05-case-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path (Join-Path $work 'tests') | Out-Null
try {
    Copy-Item -Path (Join-Path $root 'src') -Destination $work -Recurse
    $versions = [ordered]@{
        colleague = Join-Path $PSScriptRoot 'colleague' 'PachaOps.Tests.ps1'
        corrected = Join-Path $root 'tests' 'PachaOps.Tests.ps1'
    }
    foreach ($name in $versions.Keys) {
        Copy-Item -Path $versions[$name] -Destination (Join-Path $work 'tests' 'PachaOps.Tests.ps1') -Force
        pwsh -NoProfile -Command "Invoke-Pester -Path '$work/tests/PachaOps.Tests.ps1' -CI -Output Detailed"
        "$name, on $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription): exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -Path $work -Recurse -Force
}
