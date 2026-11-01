# ci: skip (it starts other pwsh processes; run-checks runs the scripts it measures)
# Clip 7.1: measures a script several times, each time in a new pwsh process, so that nothing
# loaded or remembered by one run shortens the next one.
#   ./demos/module_07/measure.ps1 -Path ./demos/module_07/01-sequential.ps1
param(
    # The script to measure.
    [Parameter(Mandatory)]
    [string] $Path,
    # How many runs.
    [int] $Count = 3,
    # The parameters of the script, as they would be typed after its name.
    [string] $Arguments = ''
)
$script = (Resolve-Path -Path $Path).Path -replace "'", "''"
foreach ($run in 1..$Count) {
    $seconds = pwsh -NoProfile -Command "[math]::Round((Measure-Command { & '$script' $Arguments | Out-Null }).TotalSeconds, 1)"
    [pscustomobject]@{ Run = $run; Seconds = [double] $seconds }
}
