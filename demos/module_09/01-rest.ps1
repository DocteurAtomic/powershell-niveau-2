# Clip 9.1: the webhook test server of the lab, read with Invoke-RestMethod and with
# Invoke-WebRequest, then two POST requests, one with a hashtable as body and one with JSON,
# read back from what the server received (lab/webhook/received.jsonl).
param(
    # The webhook test server of the lab.
    [string] $BaseUri = 'http://localhost:14580'
)
$log = Join-Path $PSScriptRoot '..' '..' 'lab' 'webhook' 'received.jsonl'

# GET: Invoke-RestMethod turns the JSON into objects, Invoke-WebRequest returns the response.
$instances = Invoke-RestMethod -Uri "$BaseUri/api/instances"
$response = Invoke-WebRequest -Uri "$BaseUri/api/instances"
[pscustomobject]@{
    Command    = 'Invoke-RestMethod'
    Type       = $instances[0].GetType().Name
    StatusCode = $null
    Value      = ($instances.name -join ', ')
}
[pscustomobject]@{
    Command    = 'Invoke-WebRequest'
    Type       = $response.GetType().Name
    StatusCode = $response.StatusCode
    Value      = $response.Content
}

# POST: a hashtable is sent as a form, a JSON string as JSON.
$marker = [guid]::NewGuid().ToString('N').Substring(0, 8)
$null = Invoke-RestMethod -Uri "$BaseUri/hook" -Method Post -Body @{ text = "form $marker" }
$null = Invoke-RestMethod -Uri "$BaseUri/hook" -Method Post -ContentType 'application/json' `
    -Body (@{ text = "json $marker" } | ConvertTo-Json -Compress) -StatusCodeVariable status
Get-Content -Path $log | Select-String -Pattern $marker -SimpleMatch |
    ForEach-Object { $_.Line | ConvertFrom-Json } |
    Format-Table -Property method, path, status, body
"Status of the JSON request: $status"
