# Clip 5.3: the test results that the workflow keeps as an artifact, read on the workstation.
# Invoke-Pester -CI writes testResults.xml, in the NUnit 2.5 format, into the current folder
# (ignored by Git).
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
Push-Location -Path $root
try {
    pwsh -NoProfile -Command 'Invoke-Pester -Path tests -CI -Output None'
    "exit code: $LASTEXITCODE"
    $results = [xml](Get-Content -Path testResults.xml -Raw)
    $results.'test-results' | Select-Object -Property total, failures, errors, date, time
    $results.SelectNodes('//test-case') | Select-Object -Property result, time, name | Format-Table -AutoSize
}
finally {
    Pop-Location
}
