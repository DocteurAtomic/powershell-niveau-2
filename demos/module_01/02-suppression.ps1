# Clip 1.2: a function that writes to the console on purpose, and says why.
# Invoke-ScriptAnalyzer -Path demos/module_01/02-suppression.ps1 returns nothing;
# add -SuppressedOnly to read what is suppressed, and the justification.
function Write-CheckLine {
    <#
    .SYNOPSIS
    Writes one line of a check, in green or red, for the person at the console.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Colored lines for the person at the console; the checks return their objects separately.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Text,
        [switch] $Failed
    )
    $color = if ($Failed) { 'Red' } else { 'Green' }
    Write-Host -Object $Text -ForegroundColor $color
}
