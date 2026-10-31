# Clip 1.1: PachaOps 0.1.0, imported by its manifest, and the error log summary as a function.
# Run it from the root of the clone, or type the lines one after the other.
Get-ChildItem -Path src/PachaOps -Recurse -Name

Import-Module -Name ./src/PachaOps/PachaOps.psd1
Get-Module -Name PachaOps | Select-Object -Property Name, Version, RequiredModules | Out-Host
Get-Command -Module PachaOps | Out-Host

# One object per error log of the folder.
Get-ErrorLogSummary -Path data/errorlog | Format-Table -AutoSize | Out-Host

# A folder that does not exist: the function throws, and the caller decides what to do.
try {
    Get-ErrorLogSummary -Path data/errorlogs
}
catch {
    "Caught: $($_.Exception.Message)"
}
