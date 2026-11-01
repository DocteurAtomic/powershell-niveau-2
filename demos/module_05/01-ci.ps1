# Clip 5.1: what the step "Run the tests" of .github/workflows/test.yml does, played on the
# workstation. Invoke-Pester -CI ends the process it runs in: it always runs in a child pwsh.
# The broken test and the step file live in a temporary copy; the clone does not change.
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
$work = Join-Path ([System.IO.Path]::GetTempPath()) "demo-05-ci-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
    # The tests of the team, as the runner runs them.
    Push-Location -Path $root
    pwsh -NoProfile -Command 'Invoke-Pester -Path tests -CI -Output Normal'
    "exit code: $LASTEXITCODE"
    Pop-Location

    # A copy of the clone where the two tests that expect 10 days expect 11.
    Copy-Item -Path (Join-Path $root 'src'), (Join-Path $root 'tests') -Destination $work -Recurse
    $testFile = Join-Path $work 'tests' 'Get-BackupAge.Tests.ps1'
    (Get-Content -Path $testFile -Raw) -replace 'Should-Be 10', 'Should-Be 11' | Set-Content -Path $testFile -NoNewline
    Push-Location -Path $work
    pwsh -NoProfile -Command 'Invoke-Pester -Path tests -CI -Output None'
    "exit code with two failed tests: $LASTEXITCODE"

    # The step as the runner writes it: $ErrorActionPreference = 'stop' first, the exit code
    # of the last native command at the end. Without -CI, the git command run after the tests
    # leaves exit code 0, and the step passes.
    foreach ($ci in '', ' -CI') {
        Set-Content -Path step.ps1 -Value @(
            "`$ErrorActionPreference = 'stop'"
            "Invoke-Pester -Path tests -Output None$ci"
            'git --version'
            'if ((Test-Path -LiteralPath variable:\LASTEXITCODE)) { exit $LASTEXITCODE }'
        )
        pwsh -NoProfile -Command ". './step.ps1'"
        "step with 'Invoke-Pester$ci': exit code $LASTEXITCODE"
    }
    Pop-Location
}
finally {
    Remove-Item -Path $work -Recurse -Force
}
