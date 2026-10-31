# The PSScriptAnalyzer rules of the operations team, written once for every workstation.
# Kept at the root, outside src/PachaOps, so that it is never packaged with the module
# (module 4). Usage, from the root of the clone:
#   Invoke-ScriptAnalyzer -Path src/PachaOps -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
#   Invoke-Formatter -ScriptDefinition $code -Settings ./PSScriptAnalyzerSettings.psd1
@{
    # Errors and warnings only: an Information finding does not stop anything.
    Severity            = @('Error', 'Warning')
    IncludeDefaultRules = $true
    # A rule is never excluded for the whole repository: a function that has a reason to
    # break one says so with SuppressMessageAttribute and a justification.
    ExcludeRules        = @()
    Rules               = @{
        # The layout of the team, applied by Invoke-Formatter and checked by the analyzer.
        PSPlaceOpenBrace          = @{ Enable = $true; OnSameLine = $true; NewLineAfter = $true; IgnoreOneLineBlock = $true }
        PSPlaceCloseBrace         = @{ Enable = $true; NewLineAfter = $true; IgnoreOneLineBlock = $true; NoEmptyLineBefore = $false }
        PSUseConsistentWhitespace = @{
            Enable                                  = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckSeparator                          = $true
            CheckPipe                               = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }
    }
}
