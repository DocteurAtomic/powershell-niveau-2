# Clips 13.1 and 13.3: the evening task run once by hand, as cron runs it, in a new pwsh
# without a profile and without a prompt, then its exit code.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
Push-Location -Path $root
try {
    $elapsed = Measure-Command -Expression {
        & pwsh -NoProfile -NonInteractive -File demos/module_13/nightly.ps1 | Out-Host
    }
    "exit code: $LASTEXITCODE, $([math]::Round($elapsed.TotalSeconds)) s"
    if ($LASTEXITCODE -ne 0) { throw "The evening task failed (exit code $LASTEXITCODE)." }
}
finally {
    Pop-Location
}
