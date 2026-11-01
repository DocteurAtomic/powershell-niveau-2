# Module 13: removes what the scripts of the module left: the entry m13_nightly of the crontab
# (03-schedule.ps1), and the crontab itself when nothing else is left in it (cronie, on Fedora,
# then keeps a copy in ~/.cache/crontab/crontab.bak); the secret m13_team_webhook; lab/nightly,
# out/ and the packages of lab/repository; the repository PachaTeam. Like
# demos/module_04/99-cleanup.ps1, it also removes what an exercise published there: run it
# yourself once the exercise is checked.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..' '..')).Path
if (Get-Command -Name crontab -CommandType Application -ErrorAction SilentlyContinue) {
    $current = @(& crontab -l 2>$null)
    if ($current -match 'm13_nightly') {
        $inside = $false
        $kept = foreach ($line in $current) {
            if ($line -match '^# m13_nightly begin') { $inside = $true; continue }
            if ($line -match '^# m13_nightly end') { $inside = $false; continue }
            if (-not $inside) { $line }
        }
        if ($kept) { $kept | & crontab - } else { & crontab -r }
        "crontab: entry m13_nightly removed, $(@($kept).Count) line(s) left"
    }
}
if (Get-SecretInfo -Vault PachaOps -Name m13_team_webhook) {
    Remove-Secret -Vault PachaOps -Name m13_team_webhook
}
Remove-Item -Path (Join-Path $root 'lab' 'nightly'), (Join-Path $root 'out'),
    (Join-Path $root 'lab' 'repository' 'PachaOps.*.nupkg') -Recurse -Force -ErrorAction SilentlyContinue
if (Get-PSResourceRepository -Name PachaTeam -ErrorAction SilentlyContinue) {
    Unregister-PSResourceRepository -Name PachaTeam
}
'secret m13_team_webhook removed, lab/nightly, out/ and lab/repository emptied, PachaTeam unregistered'
