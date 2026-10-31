# The functions of the operations team, one file each under Public.
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter *.ps1) {
    . $file.FullName
}
