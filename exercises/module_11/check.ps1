<#
.SYNOPSIS
Checks the exercise of module 11.

.DESCRIPTION
Runs your deploy.ps1 with your scripts folder, each time in a new pwsh process, into the
database m11_check that it creates on both instances, so that the database DBA is not touched:

1. with -WhatIf: the script accepts it, says that it would apply 0002-deployment-summary.sql,
   and nothing is written on either instance;
2. for real: both scripts are applied on both instances, the test instance (localhost,14534)
   before the production one (localhost,14533), and the view dbo.DeploymentSummary of
   m11_check returns two scripts and 0002-deployment-summary.sql as the last one;
3. again: nothing is applied, no error, and each journal still holds two lines;
4. with an unreachable test instance and the database m11_check_stop: the script fails, and the
   production instance receives nothing.

Removes m11_check and m11_check_stop at the end. Takes about 40 seconds, most of it waiting
for the unreachable instance. Exits with 0 when everything is right, 1 otherwise, and says what
is missing. With -Solution, checks the solution folder.

.EXAMPLE
./exercises/module_11/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your files.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$deploy = Join-Path $folder 'deploy.ps1'
$test = 'localhost,14534'
$production = 'localhost,14533'
$unreachable = 'recette01.pachadata.example,1433'
$problems = [System.Collections.Generic.List[string]]::new()

Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab

# Runs deploy.ps1 in a new pwsh process, and returns its objects, its error and its text.
function Invoke-Deployment ([hashtable] $Parameters) {
    $work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-11-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        $runner = Join-Path $work 'runner.ps1'
        $resultPath = Join-Path $work 'result.json'
        $parameterPath = Join-Path $work 'parameters.json'
        $Parameters | ConvertTo-Json | Set-Content -Path $parameterPath
        Set-Content -Path $runner -Value @'
param($ScriptPath, $ResultPath, $ParameterPath)
$result = [ordered]@{ Objects = @(); Error = $null }
$parameters = Get-Content -Path $ParameterPath -Raw | ConvertFrom-Json -AsHashtable
try {
    $result.Objects = @(& $ScriptPath @parameters | Where-Object { $_.PSObject.Properties['Status'] } |
        Select-Object -Property SqlInstance, Database, Script, Status, Message)
}
catch {
    $result.Error = $_.Exception.Message
}
$result | ConvertTo-Json -Depth 4 | Set-Content -Path $ResultPath
'@
        $text = & pwsh -NoProfile -File $runner -ScriptPath $deploy -ResultPath $resultPath -ParameterPath $parameterPath *>&1 | Out-String
        $result = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
        [pscustomobject]@{ Objects = @($result.Objects); Error = $result.Error; Text = $text }
    }
    finally {
        Remove-Item -Path $work -Recurse -Force
    }
}

function Get-Journal ([string] $Instance, [string] $Database) {
    Invoke-DbaQuery -SqlInstance $Instance -SqlCredential $credential -Database $Database -EnableException -Query @'
IF OBJECT_ID(N'dbo.DeploymentJournal', N'U') IS NOT NULL
    SELECT ScriptName, AppliedAt FROM dbo.DeploymentJournal;
'@
}

$databases = @{ m11_check = @($test, $production); m11_check_stop = @($production) }
try {
    foreach ($name in $databases.Keys) {
        foreach ($instance in $databases[$name]) {
            if (Get-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database $name) {
                Remove-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database $name -Confirm:$false | Out-Null
            }
            New-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Name $name -EnableException | Out-Null
        }
    }

    if (-not (Test-Path -Path $deploy)) { throw "$deploy does not exist." }

    # 1. -WhatIf
    $run = Invoke-Deployment -Parameters @{ Database = 'm11_check'; WhatIf = $true }
    if ($run.Error -match 'WhatIf') {
        $problems.Add('deploy.ps1 does not accept -WhatIf: [CmdletBinding(SupportsShouldProcess)].')
    }
    else {
        foreach ($instance in $test, $production) {
            if (Get-Journal -Instance $instance -Database m11_check) {
                $problems.Add("With -WhatIf, deploy.ps1 applied scripts on $instance.")
            }
            elseif ($run.Text -notmatch "What if: .*0002-deployment-summary\.sql.*$([regex]::Escape($instance))|What if: .*$([regex]::Escape($instance)).*0002-deployment-summary\.sql") {
                $problems.Add("With -WhatIf, deploy.ps1 does not say that it would apply 0002-deployment-summary.sql on $instance.")
            }
        }
    }

    # 2. The deployment.
    $run = Invoke-Deployment -Parameters @{ Database = 'm11_check' }
    if ($run.Error) { $problems.Add("deploy.ps1 failed: $($run.Error)") }
    foreach ($line in $run.Objects | Where-Object -Property Status -NotIn 'Applied', 'AlreadyApplied') {
        $problems.Add("$($line.Script) is $($line.Status) on $($line.SqlInstance): $($line.Message)")
    }
    $order = @($run.Objects | ForEach-Object { $_.SqlInstance } | Select-Object -Unique)
    if ($order.Count -eq 2 -and $order[0] -ne $test) {
        $problems.Add("deploy.ps1 deployed $($order[0]) first: the test instance, $test, goes first.")
    }
    foreach ($instance in $test, $production) {
        $journal = @(Get-Journal -Instance $instance -Database m11_check)
        if ($journal.ScriptName -notcontains '0002-deployment-summary.sql') {
            $problems.Add("0002-deployment-summary.sql is not in the journal of m11_check on $instance.")
            continue
        }
        $view = Invoke-DbaQuery -SqlInstance $instance -SqlCredential $credential -Database m11_check -EnableException `
            -Query "SELECT OBJECT_ID(N'dbo.DeploymentSummary', N'V') AS Id;"
        if ($view.Id -is [System.DBNull]) {
            $problems.Add("m11_check on $instance has no view dbo.DeploymentSummary: does the script create it without naming a database (no USE)?")
            continue
        }
        try {
            $summary = @(Invoke-DbaQuery -SqlInstance $instance -SqlCredential $credential -Database m11_check -EnableException `
                -Query 'SELECT * FROM dbo.DeploymentSummary;')
            $columns = 'ScriptCount', 'LastScript', 'LastAppliedAt', 'LastAppliedBy'
            $missing = @($columns | Where-Object { $summary.Count -and -not $summary[0].Table.Columns.Contains($_) })
            if ($summary.Count -ne 1) { $problems.Add("dbo.DeploymentSummary returns $($summary.Count) rows on $instance, one is expected.") }
            elseif ($missing) { $problems.Add("dbo.DeploymentSummary has no column $($missing -join ', ') on $instance.") }
            elseif ($summary[0].ScriptCount -ne 2 -or $summary[0].LastScript -ne '0002-deployment-summary.sql') {
                $problems.Add("dbo.DeploymentSummary on $instance says $($summary[0].ScriptCount) script(s) and $($summary[0].LastScript) as the last one: 2 and 0002-deployment-summary.sql are expected.")
            }
        }
        catch {
            $problems.Add("SELECT * FROM dbo.DeploymentSummary fails on ${instance}: $($_.Exception.Message)")
        }
    }
    $testTime = (Get-Journal -Instance $test -Database m11_check | Where-Object ScriptName -EQ '0002-deployment-summary.sql').AppliedAt
    $productionTime = (Get-Journal -Instance $production -Database m11_check | Where-Object ScriptName -EQ '0002-deployment-summary.sql').AppliedAt
    if ($testTime -and $productionTime -and $testTime -gt $productionTime) {
        $problems.Add("0002-deployment-summary.sql was applied on $production at $productionTime, before $test at $testTime.")
    }

    # 3. Again.
    $run = Invoke-Deployment -Parameters @{ Database = 'm11_check' }
    if ($run.Error) { $problems.Add("The second run of deploy.ps1 failed: $($run.Error)") }
    if ($run.Objects | Where-Object -Property Status -EQ 'Applied') {
        $problems.Add('The second run applied scripts again.')
    }
    foreach ($instance in $test, $production) {
        $count = @(Get-Journal -Instance $instance -Database m11_check).Count
        if ($count -ne 2) { $problems.Add("After the second run, the journal of m11_check on $instance holds $count line(s), 2 are expected.") }
    }

    # 4. An unreachable test instance.
    $run = Invoke-Deployment -Parameters @{ Database = 'm11_check_stop'; TestInstance = $unreachable }
    if (Get-Journal -Instance $production -Database m11_check_stop) {
        $problems.Add("With an unreachable test instance, deploy.ps1 still deployed $production.")
    }
    if (-not $run.Error) {
        $problems.Add('With an unreachable test instance, deploy.ps1 ends without an error: throw one that names the instance.')
    }
    elseif ($run.Error -notmatch [regex]::Escape($unreachable)) {
        $problems.Add("The error of deploy.ps1 does not name the test instance that failed: $($run.Error)")
    }
}
catch {
    $problems.Add($_.Exception.Message)
}
finally {
    foreach ($name in $databases.Keys) {
        foreach ($instance in $databases[$name]) {
            if (Get-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database $name) {
                Remove-DbaDatabase -SqlInstance $instance -SqlCredential $credential -Database $name -Confirm:$false | Out-Null
            }
        }
    }
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
'OK    module 11: the view deployed on the test instance, then on production, once, and nothing on production when the test instance fails.'
exit 0
