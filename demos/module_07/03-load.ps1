# ci: skip (six simultaneous imports of dbatools fail at times, and hung once: see below)
# Clip 7.2: the cost of loading dbatools in the runspaces of ForEach-Object -Parallel. Run it
# in a new pwsh each time: once dbatools is loaded in a process, every later import is cheap.
#   pwsh -NoProfile -File ./demos/module_07/03-load.ps1
#   pwsh -NoProfile -File ./demos/module_07/03-load.ps1 -ImportInParent
# Without -ImportInParent, the six imports warn ("Failed to start runspace"), and on some runs
# dbatools writes an error from inside its own loading ("Operations that change non-concurrent
# collections must have exclusive access"), or the script hangs (measured with dbatools 2.9.1
# on 1 November 2026). That is the reason for the rule of the course: dbatools is imported in
# the session, before the loop. With -ImportInParent, none of this was seen.
param(
    # Import dbatools in this session before the loop.
    [switch] $ImportInParent
)
if ($ImportInParent) {
    $parent = Measure-Command { Import-Module -Name dbatools }
    'Import in the session: {0:N2} s' -f $parent.TotalSeconds
}
1..6 | ForEach-Object -ThrottleLimit 6 -Parallel {
    $import = Measure-Command { Import-Module -Name dbatools }
    [pscustomobject]@{ Runspace = $_; ImportSeconds = [math]::Round($import.TotalSeconds, 2) }
} | Sort-Object -Property Runspace
