# The tests of the module as a whole, in Pester 6.2.0. From the root of the clone:
#   Invoke-Pester -Path tests -Output Detailed
# A function file added to Public but forgotten in FunctionsToExport would load in no session:
# the manifest decides what the module exports.
BeforeAll {
    Import-Module -Name "$PSScriptRoot/../src/PachaOps/PachaOps.psd1" -Force
}

Describe 'PachaOps' {
    It 'exports one function per file of Public' {
        # The case of a folder name counts on Linux and macOS: Public, not public.
        $files = Get-ChildItem -Path "$PSScriptRoot/../src/PachaOps/Public" -Filter *.ps1
        @((Get-Module -Name PachaOps).ExportedFunctions.Keys | Sort-Object) |
            Should-BeCollection @($files.BaseName | Sort-Object)
    }
}

AfterAll {
    Remove-Module -Name PachaOps
}
