<#
.SYNOPSIS
Checks the exercise of module 10.

.DESCRIPTION
Creates the database m10_checked on localhost,14534 and runs DBCC CHECKDB on it, so that one
database has a recent good CHECKDB. Then runs run-audit.ps1 with your configuration file and
your test file, in a pwsh process of its own (it starts one process with Pester 5.9.1 for
dbachecks, one with Pester 6.2.0 for your tests), and reads the JSON file it writes, not its
text output:

- dbachecks ran tests, none of them failed, the DAC test passed with the value False on
  both instances, the authentication test passed with SQL, and the ping and remoting tests
  were skipped;
- your rule ran tests on both instances, passed on m10_checked, failed on the databases
  whose last good CHECKDB is missing or older than seven days, and left tempdb out;
- the HTML report holds both parts.

Removes m10_checked at the end. Exits with 0 when everything is right, 1 otherwise, and says
what is missing. With -Solution, checks the files of the solution folder.

.EXAMPLE
./exercises/module_10/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your files.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$configFile = Join-Path $folder 'pachadata-instance.dbachecks.json'
$testFile = Join-Path $folder 'LastGoodCheckDb.Tests.ps1'
$instances = 'localhost,14533', 'localhost,14534'
$problems = [System.Collections.Generic.List[string]]::new()

Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-10-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
$resultPath = Join-Path $work 'audit.json'
$reportPath = Join-Path $work 'audit.html'
try {
    # One database with a good CHECKDB of today. The others of the lab have none, or one from
    # the day the backup of PachadataTraining was made.
    if (-not (Get-DbaDatabase -SqlInstance $instances[1] -SqlCredential $credential -Database m10_checked)) {
        New-DbaDatabase -SqlInstance $instances[1] -SqlCredential $credential -Name m10_checked -EnableException | Out-Null
    }
    Invoke-DbaQuery -SqlInstance $instances[1] -SqlCredential $credential -Database m10_checked `
        -Query 'DBCC CHECKDB WITH NO_INFOMSGS;' -EnableException
    $expected = foreach ($instance in $instances) {
        Get-DbaLastGoodCheckDb -SqlInstance $instance -SqlCredential $credential -ExcludeDatabase tempdb -EnableException |
            Select-Object -Property @{ Name = 'Instance'; Expression = { $instance } }, Database, LastGoodCheckDb
    }

    foreach ($file in $configFile, $testFile) {
        if (-not (Test-Path -Path $file)) { $problems.Add("$file does not exist.") }
    }
    if ($problems.Count -eq 0) {
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'run-audit.ps1') -ConfigFile $configFile -TestPath $testFile `
            -ResultPath $resultPath -ReportPath $reportPath *> $null
        if (-not (Test-Path -Path $resultPath)) {
            $problems.Add("run-audit.ps1 wrote no result (pwsh exit code $LASTEXITCODE): run it to see the error.")
        }
    }
    if (Test-Path -Path $resultPath) {
        $runs = Get-Content -Path $resultPath -Raw | ConvertFrom-Json

        # dbachecks, with the configuration of the team.
        $dbachecks = $runs.dbachecks
        $tests = @($dbachecks.Tests)
        if ($dbachecks.Summary.Error) { $problems.Add("dbachecks: $($dbachecks.Summary.Error).") }
        elseif ($dbachecks.Summary.Executed -eq 0) { $problems.Add('dbachecks ran no test: is the configuration file a JSON array of Name and Value pairs?') }
        else {
            foreach ($instance in $instances) {
                $mine = @($tests | Where-Object { $_.Test -like "* $instance" })
                $dac = @($mine | Where-Object -Property Test -Like 'DAC is set to *')
                if (-not ($dac | Where-Object { $_.Result -eq 'Passed' -and $_.Test -like 'DAC is set to False *' })) {
                    $problems.Add("On $instance, the DAC test does not pass with the value False: $(@($dac.Test) -join '; '). Set policy.dacallowed.")
                }
                if (-not ($mine | Where-Object { $_.Result -eq 'Passed' -and $_.Test -like 'auth scheme should be SQL *' })) {
                    $problems.Add("On $instance, the authentication test does not pass with SQL: $(@($mine | Where-Object Test -like 'auth scheme*').Test -join '; '). Set policy.connection.authscheme.")
                }
                foreach ($pattern in 'We should be able to ping host *', 'We should be able to remote onto *') {
                    if ($mine | Where-Object { $_.Test -like $pattern -and $_.Result -eq 'Failed' }) {
                        $problems.Add("On $instance, '$($pattern.TrimEnd(' *'))' fails: from Linux, dbachecks cannot ping and tests remoting with WinRM. Skip it with skip.connection.ping or skip.connection.remoting.")
                    }
                }
            }
            if (-not $problems.Count -and $dbachecks.Summary.Failed -gt 0) {
                $problems.Add("dbachecks: $($dbachecks.Summary.Failed) test(s) fail: $(@($tests | Where-Object Result -EQ 'Failed').Test -join '; ').")
            }
        }

        # The CHECKDB rule of the team, compared with what Get-DbaLastGoodCheckDb returns.
        $team = $runs.team
        $tests = @($team.Tests)
        $limit = (Get-Date).AddDays(-7)
        if ($team.Summary.Error) { $problems.Add("Your tests: $($team.Summary.Error). Run ./exercises/module_10/run-audit.ps1 to see the error.") }
        elseif ($team.Summary.Executed -eq 0) { $problems.Add('Your test file ran no test: one test per database is expected (It with -ForEach).') }
        else {
            if ($tests | Where-Object { $_.Test -match '\btempdb\b' }) {
                $problems.Add('Your rule tests tempdb, which SQL Server creates again at each start and which never keeps a last good CHECKDB: leave it out.')
            }
            foreach ($database in $expected) {
                $instance = $database.Instance
                $test = $tests | Where-Object { $_.Test -match "\b$([regex]::Escape($database.Database))\b" -and $_.Test -like "* $instance" }
                $recent = $database.LastGoodCheckDb -and ([datetime] $database.LastGoodCheckDb) -gt $limit
                $want = if ($recent) { 'Passed' } else { 'Failed' }
                if (-not $test) {
                    $problems.Add("No test names the database $($database.Database) on $instance (the name of the test holds the database and the instance).")
                }
                elseif (@($test)[0].Result -ne $want) {
                    $why = if (-not $database.LastGoodCheckDb) { 'it has never had a good CHECKDB' }
                           elseif ($recent) { "its last good CHECKDB is of $($database.LastGoodCheckDb)" }
                           else { "its last good CHECKDB is of $($database.LastGoodCheckDb), more than seven days ago" }
                    $problems.Add("The test of $($database.Database) on $instance is $(@($test)[0].Result), $want is expected: $why.")
                }
            }
        }

        if (-not (Test-Path -Path $reportPath)) { $problems.Add('run-audit.ps1 wrote no HTML report.') }
        elseif (-not ((Get-Content -Path $reportPath -Raw) -match 'DAC is set to' -and (Get-Content -Path $reportPath -Raw) -match 'm10_checked')) {
            $problems.Add('The HTML report does not hold both parts, dbachecks and your rule.')
        }
    }
}
finally {
    if (Get-DbaDatabase -SqlInstance $instances[1] -SqlCredential $credential -Database m10_checked) {
        Remove-DbaDatabase -SqlInstance $instances[1] -SqlCredential $credential -Database m10_checked -Confirm:$false | Out-Null
    }
    Remove-Item -Path $work -Recurse -Force
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
'OK    module 10: dbachecks and the CHECKDB rule ran on both instances, with the results of the rules of the team.'
exit 0
