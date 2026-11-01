# Clip 9.2: what Invoke-RestMethod does with an error status, and what -MaximumRetryCount
# retries. /flaky answers 503 twice, then 200; /status/400 always answers 400. Every request
# carries a marker, so that the lines of this run can be read back from the log.
param(
    # The webhook test server of the lab.
    [string] $BaseUri = 'http://localhost:14580'
)
$log = Join-Path $PSScriptRoot '..' '..' 'lab' 'webhook' 'received.jsonl'
$marker = [guid]::NewGuid().ToString('N').Substring(0, 8)
$json = @{ text = "retry $marker" } | ConvertTo-Json -Compress

# The counter of /flaky is shared by everyone who calls it: realign it on the start of a cycle
# (the next answers are then 503, 503, 200).
foreach ($i in 1..3) {
    $null = Invoke-RestMethod -Uri "$BaseUri/flaky" -Method Post -Body '{"text":"align"}' `
        -ContentType 'application/json' -SkipHttpErrorCheck -StatusCodeVariable aligned
    if ($aligned -eq 200) { break }
}

# An error status is an exception, with the status code and the body of the answer.
try {
    Invoke-RestMethod -Uri "$BaseUri/status/400" -Method Post -Body $json -ContentType 'application/json'
}
catch {
    [pscustomobject]@{
        Case       = 'status 400, no retry'
        Exception  = $_.Exception.GetType().Name
        StatusCode = [int] $_.Exception.Response.StatusCode
        Body       = $_.ErrorDetails.Message -replace '\s', ''
    }
}

# -SkipHttpErrorCheck: no exception, the answer and its status go to the pipeline.
$answer = Invoke-RestMethod -Uri "$BaseUri/status/400" -Method Post -Body $json `
    -ContentType 'application/json' -SkipHttpErrorCheck -StatusCodeVariable code
[pscustomobject]@{ Case = 'status 400, -SkipHttpErrorCheck'; Exception = $null; StatusCode = $code; Body = $answer.ok }

# -MaximumRetryCount on /flaky: two 503, then 200.
$flaky = Measure-Command {
    $null = Invoke-RestMethod -Uri "$BaseUri/flaky" -Method Post -Body $json -ContentType 'application/json' `
        -MaximumRetryCount 3 -RetryIntervalSec 1 -StatusCodeVariable code
}
[pscustomobject]@{ Case = "flaky, 3 retries, $([math]::Round($flaky.TotalSeconds, 1)) s"; Exception = $null; StatusCode = $code; Body = $null }

# -MaximumRetryCount on a 400: the same message is sent three times.
try {
    Invoke-RestMethod -Uri "$BaseUri/status/400" -Method Post -Body $json -ContentType 'application/json' `
        -MaximumRetryCount 2 -RetryIntervalSec 1
}
catch {
    [pscustomobject]@{ Case = 'status 400, 2 retries'; Exception = $_.Exception.GetType().Name; StatusCode = [int] $_.Exception.Response.StatusCode; Body = $null }
}

# What the server received from this run.
Get-Content -Path $log | Select-String -Pattern $marker -SimpleMatch |
    ForEach-Object { $_.Line | ConvertFrom-Json } |
    Group-Object -Property path, status -NoElement |
    Format-Table -Property Name, Count
