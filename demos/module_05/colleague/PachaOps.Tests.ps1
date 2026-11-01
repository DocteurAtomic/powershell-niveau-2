# ci: skip. The test of a colleague, written on Windows, before module 5 corrected it in
# tests/PachaOps.Tests.ps1: it names the folder public, and the folder is Public. It passes
# where the file system ignores case (Windows, by default) and fails on Linux.
# demos/module_05/02-case.ps1 runs it from a copy of the clone, as tests/PachaOps.Tests.ps1.
BeforeAll {
    Import-Module -Name "$PSScriptRoot/../src/PachaOps/PachaOps.psd1" -Force
}

Describe 'PachaOps' {
    It 'exports one function per file of Public' {
        $files = Get-ChildItem -Path "$PSScriptRoot/../src/PachaOps/public" -Filter *.ps1
        @((Get-Module -Name PachaOps).ExportedFunctions.Keys | Sort-Object) |
            Should-BeCollection @($files.BaseName | Sort-Object)
    }
}

AfterAll {
    Remove-Module -Name PachaOps
}
