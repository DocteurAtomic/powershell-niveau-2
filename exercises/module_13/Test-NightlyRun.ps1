# The morning check of a colleague: it reads the last line of the trace of the evening task and
# writes OK when its exit code is 0. Exercise of module 13: make it return one object with its
# verdict and its reasons, and exit with 1 when the night proves nothing (README.md).
param(
    [string] $ResultPath = (Join-Path $PSScriptRoot '..' '..' 'lab' 'nightly')
)
$last = Get-Content -Path (Join-Path $ResultPath 'nightly.jsonl') | Select-Object -Last 1 | ConvertFrom-Json
if ($last.ExitCode -eq 0) {
    Write-Host 'Nightly OK'
}
else {
    Write-Host 'Nightly FAILED'
}
