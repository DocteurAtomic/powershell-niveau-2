<#
.SYNOPSIS
The webhook test server of the course (module 9).

.DESCRIPTION
Answers HTTP requests on port 8080 and appends each request it receives, with the status it
answered, as one JSON line to the log file, which the exercise checks read.

  GET  /api/instances   200, a small JSON list (the read API of clip 9.1)
  POST /hook            200, the message is accepted
  ANY  /status/<code>   answers <code>, for example /status/400
  ANY  /flaky           503 twice, then 200 once, then 503 twice again
#>
param(
    [string] $LogPath = '/srv/webhook/received.jsonl',
    [int] $Port = 8080
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path (Split-Path $LogPath) | Out-Null
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://*:$Port/")
$listener.Start()
"webhook test server listening on port $Port, log $LogPath"
$flaky = 0
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
    $body = $reader.ReadToEnd()
    $path = $request.Url.AbsolutePath
    $answer = '{"ok":true}'
    $status = switch -Regex ($path) {
        '^/api/instances$' {
            $answer = '[{"name":"sql1","port":14533},{"name":"sql2","port":14534}]'
            200
        }
        '^/hook$' { 200 }
        '^/status/(\d{3})$' { [int] $Matches[1] }
        '^/flaky$' {
            $flaky++
            if ($flaky % 3 -eq 0) { 200 } else { 503 }
        }
        default { 404 }
    }
    if ($status -ne 200) { $answer = '{"ok":false}' }
    [ordered]@{
        time   = [datetime]::UtcNow.ToString('o')
        method = $request.HttpMethod
        path   = $path
        status = $status
        body   = $body
    } | ConvertTo-Json -Compress | Add-Content -Path $LogPath
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($answer)
    $context.Response.StatusCode = $status
    $context.Response.ContentType = 'application/json'
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.Close()
}
