<#
.SYNOPSIS
Checks the exercise of module 12.

.DESCRIPTION
Creates two databases on sql2 (localhost,14534): m12_check, which follows the rules of the
team, and m12_check_drift, where it sets AUTO_SHRINK ON and PAGE_VERIFY TORN_PAGE_DETECTION,
two changes made by hand. Then it runs your Get-DatabaseDrift.ps1 three times, each time in a
new pwsh process, with a file of rules that it writes itself:

1. the rules of the team: exactly two differences, both on m12_check_drift (AutoShrink and
   PageVerify, with the expected and the actual value), nothing on m12_check nor on the system
   databases;
2. the same rules, m12_check_drift excluded: nothing on it;
3. one rule only, PageVerify: one difference on m12_check_drift, PageVerify.

Removes both databases at the end, in a finally block, even when a run fails. Takes about
twenty seconds. Exits with 0 when everything is right, 1 otherwise, and says what is missing.
With -Solution, checks the solution folder.

.EXAMPLE
./exercises/module_12/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your files.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$script = Join-Path $folder 'Get-DatabaseDrift.ps1'
$instance = 'localhost,14534'
$system = 'master', 'model', 'msdb', 'tempdb'
$problems = [System.Collections.Generic.List[string]]::new()

Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab

# Runs Get-DatabaseDrift.ps1 in a new pwsh process with a file of rules, and returns its objects
# (values as text) and its error.
function Invoke-DriftScript ([hashtable] $Rules) {
    $work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-12-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        $rulesPath = Join-Path $work 'rules.json'
        $resultPath = Join-Path $work 'result.json'
        $runner = Join-Path $work 'runner.ps1'
        $Rules | ConvertTo-Json -Depth 3 | Set-Content -Path $rulesPath
        Set-Content -Path $runner -Value @'
param($ScriptPath, $SqlInstance, $RulesPath, $ResultPath)
$result = [ordered]@{ Objects = @(); Error = $null }
try {
    $result.Objects = @(& $ScriptPath -SqlInstance $SqlInstance -ReferencePath $RulesPath |
        Where-Object { $_.PSObject.Properties['Option'] } |
        ForEach-Object {
            [ordered]@{
                SqlInstance = "$($_.SqlInstance)"; Database = "$($_.Database)"; Option = "$($_.Option)"
                Expected = "$($_.Expected)"; Actual = "$($_.Actual)"
            }
        })
}
catch {
    $result.Error = $_.Exception.Message
}
$result | ConvertTo-Json -Depth 4 | Set-Content -Path $ResultPath
'@
        & pwsh -NoProfile -File $runner -ScriptPath $script -SqlInstance $instance -RulesPath $rulesPath -ResultPath $resultPath *> $null
        $result = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
        [pscustomobject]@{ Objects = @($result.Objects); Error = $result.Error }
    }
    finally {
        Remove-Item -Path $work -Recurse -Force
    }
}

function Format-Difference ($Objects) {
    ($Objects | ForEach-Object { "$($_.Database).$($_.Option) ($($_.Expected) expected, $($_.Actual) found)" }) -join ', '
}

$rules = [ordered]@{
    PageVerify                  = 'Checksum'
    AutoClose                   = $false
    AutoShrink                  = $false
    AutoCreateStatisticsEnabled = $true
    AutoUpdateStatisticsEnabled = $true
}
$databases = 'm12_check', 'm12_check_drift'
try {
    foreach ($name in $databases) {
        if (Get-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database $name) {
            Remove-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database $name -Confirm:$false | Out-Null
        }
        New-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Name $name -EnableException | Out-Null
    }
    Invoke-DbaQuery -SqlInstance $instance -SqlCredential $credential -Database master -EnableException -Query @'
ALTER DATABASE m12_check_drift SET AUTO_SHRINK ON;
ALTER DATABASE m12_check_drift SET PAGE_VERIFY TORN_PAGE_DETECTION;
'@

    if (-not (Test-Path -Path $script)) { throw "$script does not exist." }

    # 1. The rules of the team.
    $run = Invoke-DriftScript -Rules @{ ExcludeDatabase = $system; Options = $rules }
    if ($run.Error) {
        $problems.Add("Get-DatabaseDrift.ps1 failed with the rules of the team: $($run.Error)")
    }
    elseif ($run.Objects.Count -eq 0) {
        $problems.Add('With the rules of the team, Get-DatabaseDrift.ps1 returns no object with SqlInstance, Database, Option, Expected and Actual: Write-Host is text, not an object.')
    }
    else {
        $drift = @($run.Objects | Where-Object -Property Database -EQ 'm12_check_drift')
        $expected = @(
            [pscustomobject]@{ Option = 'AutoShrink'; Expected = 'False'; Actual = 'True' }
            [pscustomobject]@{ Option = 'PageVerify'; Expected = 'Checksum'; Actual = 'TornPageDetection' }
        )
        foreach ($line in $expected) {
            $found = $drift | Where-Object -Property Option -EQ $line.Option
            if (-not $found) {
                $problems.Add("m12_check_drift has $($line.Option) = $($line.Actual), against $($line.Expected) in the rules: the script does not return it.")
            }
            elseif ($found.Expected -ne $line.Expected -or $found.Actual -ne $line.Actual -or $found.SqlInstance -ne $instance) {
                $problems.Add("For m12_check_drift.$($line.Option), the script returns SqlInstance $($found.SqlInstance), Expected $($found.Expected) and Actual $($found.Actual): $instance, $($line.Expected) and $($line.Actual) are expected.")
            }
        }
        $extra = @($drift | Where-Object -Property Option -NotIn $expected.Option)
        if ($extra) { $problems.Add("The script returns differences that m12_check_drift does not have: $(Format-Difference $extra).") }
        $clean = @($run.Objects | Where-Object -Property Database -EQ 'm12_check')
        if ($clean) { $problems.Add("m12_check follows the rules, and the script returns $(Format-Difference $clean).") }
        $excluded = @($run.Objects | Where-Object -Property Database -In $system)
        if ($excluded) { $problems.Add("The rules leave the system databases out, and the script returns $(Format-Difference $excluded).") }
    }

    # 2. The same rules, m12_check_drift excluded.
    $run = Invoke-DriftScript -Rules @{ ExcludeDatabase = @($system) + 'm12_check_drift'; Options = $rules }
    if ($run.Error) {
        $problems.Add("Get-DatabaseDrift.ps1 failed with m12_check_drift in ExcludeDatabase: $($run.Error)")
    }
    elseif ($run.Objects | Where-Object -Property Database -EQ 'm12_check_drift') {
        $problems.Add('With m12_check_drift in ExcludeDatabase, the script still returns its differences: read ExcludeDatabase from the file.')
    }

    # 3. One rule only.
    $run = Invoke-DriftScript -Rules @{ ExcludeDatabase = $system; Options = @{ PageVerify = 'Checksum' } }
    if ($run.Error) {
        $problems.Add("Get-DatabaseDrift.ps1 failed with the rule PageVerify alone: $($run.Error)")
    }
    else {
        $drift = @($run.Objects | Where-Object -Property Database -EQ 'm12_check_drift')
        if ($drift.Count -ne 1 -or $drift[0].Option -ne 'PageVerify') {
            $problems.Add("With the rule PageVerify alone, the script returns $($drift.Count) difference(s) on m12_check_drift ($(Format-Difference $drift)): PageVerify alone is expected. Read the options from the file.")
        }
    }
}
catch {
    $problems.Add($_.Exception.Message)
}
finally {
    foreach ($name in $databases) {
        if (Get-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database $name) {
            Remove-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database $name -Confirm:$false | Out-Null
        }
    }
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
'OK    module 12: the two differences of m12_check_drift returned as objects, nothing on the databases that follow the rules, and the rules read from the file.'
exit 0
