<#
.SYNOPSIS
Checks the exercise of module 1.

.DESCRIPTION
Analyzes your copy of Get-MorningReport with the settings of the team
(PSScriptAnalyzerSettings.psd1, at the root of the clone) and checks three results:

- the analysis returns nothing;
- the rules the exercise asks you to correct (PSAvoidUsingWriteHost, PSAvoidUsingCmdletAliases)
  are corrected, not suppressed;
- every rule you keep is suppressed with SuppressMessageAttribute and a justification.

Then it runs your copy and the copy of PachaOps 0.1.0 (reference/) in two separate pwsh
processes, on the two instances of the lab and one unreachable instance, with -SqlCredential
and with -Password, and compares the objects they return: a correction of form changes no
result. Exits with 0 when everything is right, 1 otherwise, and says what is missing. With
-Solution, checks the solution folder.

.EXAMPLE
./exercises/module_01/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your copy.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$file = Join-Path $folder 'Get-MorningReport.ps1'
$reference = Join-Path $PSScriptRoot 'reference' 'Get-MorningReport.ps1'
$settings = Join-Path $root 'PSScriptAnalyzerSettings.psd1'
$toCorrect = 'PSAvoidUsingWriteHost', 'PSAvoidUsingCmdletAliases'
$problems = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -Path $file)) {
    "FAIL  $file does not exist."
    exit 1
}
Import-Module -Name PSScriptAnalyzer -RequiredVersion 1.25.0

# 1. What the analyzer still reports.
foreach ($record in Invoke-ScriptAnalyzer -Path $file -Settings $settings | Sort-Object -Property Line) {
    $advice = if ($record.RuleName -in $toCorrect) { 'correct it' } else { 'correct it, or suppress it with a justification' }
    $problems.Add("Line $($record.Line): $($record.RuleName) is still reported; $advice.")
}

# 2. What is suppressed, and why.
foreach ($record in Invoke-ScriptAnalyzer -Path $file -Settings $settings -SuppressedOnly | Sort-Object -Property Line) {
    if ($record.RuleName -in $toCorrect) {
        $problems.Add("Line $($record.Line): $($record.RuleName) is suppressed. The exercise asks you to correct it.")
    }
    elseif (-not ($record.Suppression | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Justification) })) {
        $problems.Add("Line $($record.Line): $($record.RuleName) is suppressed without a justification. Say why in Justification = '...'.")
    }
}

# 3. The same results as PachaOps 0.1.0, each version in its own process. The password comes
# from the vault of the lab, never from this script.
$runner = {
    param($FunctionPath, $InventoryPath, $ResultPath)
    $WarningPreference = 'SilentlyContinue'
    Import-Module -Name dbatools
    Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
    . $FunctionPath
    $credential = Get-Secret -Vault PachaOps -Name sql-lab
    $command = Get-Command -Name Get-MorningReport
    $select = 'Instance', 'Status', 'Version', 'Database', 'RecoveryModel',
        @{ Name = 'LastFullBackup'; Expression = { "$($_.LastFullBackup)" } }
    $call = {
        param([hashtable] $Arguments)
        try {
            @(Get-MorningReport @Arguments 6> $null | Select-Object -Property $select)
        }
        catch {
            "error: $($_.Exception.Message)"
        }
    }
    [pscustomobject]@{
        Parameters     = @($command.Parameters.Values |
                Where-Object Name -NotIn ([System.Management.Automation.PSCmdlet]::CommonParameters) |
                ForEach-Object { "$($_.Name):$($_.ParameterType.Name)" } | Sort-Object)
        WithCredential = & $call @{ InventoryPath = $InventoryPath; SqlCredential = $credential }
        WithPassword   = & $call @{ InventoryPath = $InventoryPath; Password = $credential.GetNetworkCredential().Password }
    } | ConvertTo-Json -Depth 4 | Set-Content -Path $ResultPath
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-01-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $inventory = Join-Path $work 'instances.csv'
    Import-Csv -Path (Join-Path $root 'data' 'instances.csv') |
        Where-Object Name -In 'sql1', 'sql2', 'compta01' |
        Export-Csv -Path $inventory
    $runs = @{}
    foreach ($version in @{ Name = 'reference'; Path = $reference }, @{ Name = 'yours'; Path = $file }) {
        $resultPath = Join-Path $work "$($version.Name).json"
        & pwsh -NoProfile -Command $runner -args $version.Path, $inventory, $resultPath *> $null
        if (-not (Test-Path -Path $resultPath)) {
            $problems.Add("Get-MorningReport did not run from $($version.Path) (pwsh exit code $LASTEXITCODE). Dot-source it in a pwsh session to see the error.")
            continue
        }
        $runs[$version.Name] = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
    }
    if ($runs.Count -eq 2) {
        if (($runs.reference.Parameters -join ', ') -ne ($runs.yours.Parameters -join ', ')) {
            $problems.Add("The parameters changed: $($runs.yours.Parameters -join ', ') instead of $($runs.reference.Parameters -join ', ').")
        }
        foreach ($case in 'WithCredential', 'WithPassword') {
            $expected = $runs.reference.$case | ConvertTo-Json -Depth 3 -Compress
            $actual = $runs.yours.$case | ConvertTo-Json -Depth 3 -Compress
            if (@($runs.reference.$case | Where-Object Status -EQ 'Online').Count -eq 0) {
                $problems.Add("The reference reached no instance ($case): is the lab running? ./setup/test-lab.ps1")
            }
            elseif ($expected -ne $actual) {
                $problems.Add("Your copy does not return the same objects as PachaOps 0.1.0 ($case). A correction of form must not change the result.")
            }
        }
    }
}
finally {
    Remove-Item -Path $work -Recurse -Force
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
'OK    module 1: nothing left for the analyzer, every suppression has its justification, and the report returns the same objects.'
exit 0
