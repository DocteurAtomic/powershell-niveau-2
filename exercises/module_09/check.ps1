<#
.SYNOPSIS
Checks the exercise of module 9.

.DESCRIPTION
Runs your Send-BackupAlert in a new pwsh process against four routes of the webhook test
server of the lab, then reads what the server received in lab/webhook/received.jsonl:

  /flaky        503 twice, then 200: three requests, and an object StatusCode 200, Attempts 3
  /status/400   a refused message: one request only, and an error
  /status/503   a server that stays down: -MaximumAttempt requests, and an error
  /status/429   too many requests: -MaximumAttempt requests, and an error

Every call sends rows whose instance names carry a marker of this run, so that the lines of
the log are told apart from those of other runs. The check also reads the message: one line
per problem, none for a database whose status is Ok, and waits of at least about
-RetryIntervalSec between two requests. Takes about ten seconds. Exits with 0 when everything
is right, 1 otherwise, and says what is missing. With -Solution, checks the solution folder.

.EXAMPLE
./exercises/module_09/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your file.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$folder = if ($Solution) { Join-Path $PSScriptRoot 'solution' } else { $PSScriptRoot }
$candidate = Join-Path $folder 'Send-BackupAlert.ps1'
$log = Join-Path $PSScriptRoot '..' '..' 'lab' 'webhook' 'received.jsonl'
$base = 'http://localhost:14580'
$problems = [System.Collections.Generic.List[string]]::new()

try {
    $null = Invoke-RestMethod -Uri "$base/api/instances"
}
catch {
    "FAIL  The check cannot reach the webhook test server at ${base}: $($_.Exception.Message) Start the lab, then run setup/test-host.ps1."
    exit 1
}
if (-not (Test-Path -Path $log)) {
    "FAIL  $log is missing: the webhook test server does not write into this clone. Start the lab from this folder."
    exit 1
}

# Your function, in a child process: it dot-sources the file and calls the function once per
# route, with the rows of its case, and writes what it returned or threw as JSON.
$runner = @'
param($ScriptPath, $BaseUri, $Marker, $ResultPath)
$ErrorActionPreference = 'Stop'
$result = [ordered]@{ Error = $null; Missing = @(); Cases = [ordered]@{} }
try {
    . $ScriptPath
    $command = Get-Command -Name Send-BackupAlert -CommandType Function -ErrorAction SilentlyContinue
    if (-not $command) { throw "$ScriptPath does not define the function Send-BackupAlert." }
    $result.Missing = @('Uri', 'BackupCheck', 'MaximumAttempt', 'RetryIntervalSec' | Where-Object { -not $command.Parameters.ContainsKey($_) })
    if (-not $result.Missing) {
        $cases = [ordered]@{ flaky = @('flaky', 3); refused = @('status/400', 3); down = @('status/503', 2); throttled = @('status/429', 2) }
        foreach ($name in $cases.Keys) {
            $rows = @(
                [pscustomobject]@{ Instance = "$Marker-$name-sql1"; Database = 'Finance'; LastFullBackup = [datetime] '2026-10-20'; LastLogBackup = $null; Status = 'Late' }
                [pscustomobject]@{ Instance = "$Marker-$name-sql1"; Database = 'Planning'; LastFullBackup = [datetime] '2026-11-01'; LastLogBackup = $null; Status = 'Ok' }
                [pscustomobject]@{ Instance = "$Marker-$name-sql2"; Database = 'DBA'; LastFullBackup = $null; LastLogBackup = $null; Status = 'Missing' }
                [pscustomobject]@{ Instance = "$Marker-$name-compta01"; Database = $null; LastFullBackup = $null; LastLogBackup = $null; Status = 'Unreachable' }
            )
            if ($name -eq 'flaky') {
                # The counter of /flaky is shared: realign it on the start of a cycle (503, 503, 200).
                foreach ($i in 1..3) {
                    $null = Invoke-RestMethod -Uri "$BaseUri/flaky" -Method Post -Body '{"text":"align"}' `
                        -ContentType 'application/json' -SkipHttpErrorCheck -StatusCodeVariable aligned
                    if ($aligned -eq 200) { break }
                }
            }
            $case = [ordered]@{ Output = @(); Error = $null }
            try {
                $output = Send-BackupAlert -Uri "$BaseUri/$($cases[$name][0])" -BackupCheck $rows -MaximumAttempt $cases[$name][1] -RetryIntervalSec 1
                $case.Output = @($output | ForEach-Object { [ordered]@{ StatusCode = $_.StatusCode; Attempts = $_.Attempts } })
            }
            catch {
                $case.Error = $_.Exception.Message
            }
            $result.Cases[$name] = $case
        }
    }
}
catch {
    $result.Error = $_.Exception.Message
}
$result | ConvertTo-Json -Depth 5 | Set-Content -Path $ResultPath
'@
$marker = 'm09chk' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module09-$PID"
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    $runnerPath = Join-Path $work 'runner.ps1'
    $resultPath = Join-Path $work 'result.json'
    Set-Content -Path $runnerPath -Value $runner
    & pwsh -NoProfile -File $runnerPath -ScriptPath $candidate -BaseUri $base -Marker $marker -ResultPath $resultPath *> $null
    if (-not (Test-Path -Path $resultPath)) {
        "FAIL  The run of Send-BackupAlert wrote no result (exit $LASTEXITCODE)."
        exit 1
    }
    $actual = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
}
finally {
    Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
}
if ($actual.Error) {
    "FAIL  Send-BackupAlert does not run: $($actual.Error)"
    exit 1
}
if ($actual.Missing) {
    "FAIL  Send-BackupAlert has no parameter $($actual.Missing -join ', ')."
    exit 1
}

# What the server received, case by case.
$received = @(Get-Content -Path $log | Select-String -Pattern $marker -SimpleMatch | ForEach-Object { $_.Line | ConvertFrom-Json })
function Get-Received([string] $Name) { @($received | Where-Object { $_.body -like "*$marker-$Name-*" }) }

$flaky = Get-Received 'flaky'
$case = $actual.Cases.flaky
if ($case.Error) { $problems.Add("On /flaky (503, 503, then 200), Send-BackupAlert throws: $($case.Error)") }
if ($flaky.Count -ne 3 -or ($flaky.status -join ',') -ne '503,503,200') {
    $problems.Add("On /flaky, the server received $($flaky.Count) request(s), statuses $($flaky.status -join ', '); 503, 503, 200 is expected.")
}
$output = @($case.Output)
if ($output.Count -ne 1 -or $output[0].StatusCode -ne 200 -or $output[0].Attempts -ne 3) {
    $shown = if ($output.Count) { ($output | ForEach-Object { "StatusCode $($_.StatusCode), Attempts $($_.Attempts)" }) -join '; ' } else { 'nothing' }
    $problems.Add("On /flaky, Send-BackupAlert returns $shown; one object with StatusCode 200 and Attempts 3 is expected.")
}
if ($flaky.Count -ge 2) {
    $times = @($flaky | ForEach-Object { [datetimeoffset]::Parse($_.time) })
    for ($i = 1; $i -lt $times.Count; $i++) {
        $gap = ($times[$i] - $times[$i - 1]).TotalSeconds
        if ($gap -lt 0.8) { $problems.Add("Two requests on /flaky are $([math]::Round($gap, 2)) s apart; -RetryIntervalSec 1 asks for about one second.") ; break }
    }
}
if ($flaky.Count -ge 1) {
    $text = try { ($flaky[0].body | ConvertFrom-Json).text } catch { $null }
    if (-not $text) {
        $problems.Add('The body of the message is not JSON with a property text.')
    }
    else {
        foreach ($expected in "$marker-flaky-sql1/Finance: Late", "$marker-flaky-sql2/DBA: Missing", "$marker-flaky-compta01: Unreachable") {
            if ($text -notlike "*$expected*") { $problems.Add("The message has no line '$expected'.") }
        }
        if ($text -like '*Planning*') { $problems.Add('The message names Planning, whose backup is Ok.') }
    }
}

$refused = Get-Received 'refused'
if ($refused.Count -ne 1) {
    $problems.Add("On /status/400, the server received the same message $($refused.Count) times; a refused message is sent once.")
}
if (-not $actual.Cases.refused.Error) {
    $problems.Add('On /status/400, Send-BackupAlert does not throw: the message was not delivered, and the caller must know it.')
}
elseif ($actual.Cases.refused.Error -notmatch '400') {
    $problems.Add("On /status/400, the error does not give the status: '$($actual.Cases.refused.Error)'.")
}

foreach ($name in 'down', 'throttled') {
    $route = if ($name -eq 'down') { '/status/503' } else { '/status/429' }
    $code = $route.Substring(8)
    $lines = Get-Received $name
    if ($lines.Count -ne 2) {
        $problems.Add("On $route with -MaximumAttempt 2, the server received $($lines.Count) request(s); 2 are expected.")
    }
    if (-not $actual.Cases.$name.Error) {
        $problems.Add("On $route, Send-BackupAlert does not throw after its last attempt.")
    }
    elseif ($actual.Cases.$name.Error -notmatch $code) {
        $problems.Add("On $route, the error does not give the status: '$($actual.Cases.$name.Error)'.")
    }
}

if ($problems.Count) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
'OK    Send-BackupAlert sends again on 503 and 429, never on 400, and the server received the problems of the check.'
exit 0
