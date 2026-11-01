# Clip 6.2: a class changed in a session that has already loaded it. Import-Module does not
# give the types; Import-Module -Force compiles the changed class as a second type of the same
# name, and the name typed in the session still means the first one. Works on a copy of
# PachaReport.psm1, in a child pwsh, as the session of the clip.
$work = Join-Path ([System.IO.Path]::GetTempPath()) "demo-06-reload-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
    Copy-Item -Path (Join-Path $PSScriptRoot 'PachaReport.psm1'), (Join-Path $PSScriptRoot 'sample-report.ps1') -Destination $work
    # Import-Module alone: the function is there, the type is not.
    pwsh -NoProfile -Command "Import-Module -Name '$work/PachaReport.psm1'; try { [InstanceStatus] } catch { `$_.Exception.Message }"
    $session = @'
using module ./PachaReport.psm1
$rows = & ./sample-report.ps1
"before: $([InstanceStatus]::new('sql1', 'Ok'))"
# The change a colleague makes in the file while the session is open.
(Get-Content -Path ./PachaReport.psm1 -Raw).Replace("'{0} ({1})'", "'{0}: {1}'") | Set-Content -Path ./PachaReport.psm1
Import-Module -Name ./PachaReport.psm1 -Force
"from the module: $($rows | Get-InstanceStatus -ReferenceDate 2026-11-02 | Select-Object -First 1)"
"typed in the session: $([InstanceStatus]::new('sql1', 'Ok'))"
try { [InstanceStatus[]] $statuses = $rows | Get-InstanceStatus -ReferenceDate 2026-11-02 } catch { $_.Exception.Message }
"same type: $(($rows | Get-InstanceStatus -ReferenceDate 2026-11-02)[0] -is [InstanceStatus])"
'@
    Set-Content -Path (Join-Path $work 'session.ps1') -Value $session
    Push-Location -Path $work
    try { pwsh -NoProfile -File ./session.ps1 } finally { Pop-Location }
    # A new session reads the file as it is now.
    Push-Location -Path $work
    try { pwsh -NoProfile -Command "using module ./PachaReport.psm1`n`"new session: `$([InstanceStatus]::new('sql1', 'Ok'))`"" } finally { Pop-Location }
}
finally {
    Remove-Item -Path $work -Recurse -Force
}
