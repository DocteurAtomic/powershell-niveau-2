using module ./PachaReport.psm1
# Clip 6.3: the same status as a [pscustomobject] named by PSTypeName, with a format file,
# against the class: what each checks, and what each keeps through Export-Clixml.
$line = [pscustomobject]@{
    PSTypeName        = 'PachaOps.InstanceStatus'
    Instance          = 'sql1'
    Severity          = [Severity]::Warning
    Version           = '17.0.4065.4'
    Databases         = 5
    WithoutRecentFull = 5
}
$line.PSObject.TypeNames
$line | Out-Host
Update-FormatData -PrependPath (Join-Path $PSScriptRoot 'PachaReport.Format.ps1xml')
$line | Out-Host
# Nothing checks the value of a property of a [pscustomobject].
$line.Severity = 'Urgent'
$line | Out-Host

function Send-Status {
    param([Parameter(Mandatory)] [PSTypeName('PachaOps.InstanceStatus')] $Status)
    "sent: $($Status.Instance)"
}
Send-Status -Status $line
try { Send-Status -Status ([pscustomobject]@{ Instance = 'sql1' }) } catch { $_.Exception.Message }

# Through Export-Clixml, as through a remote session (module 8), an object keeps its
# properties and loses its type.
$status = [InstanceStatus]::new('sql1', 'Warning')
$path = Join-Path ([System.IO.Path]::GetTempPath()) "demo-06-$([guid]::NewGuid()).xml"
try {
    $status | Export-Clixml -Path $path
    $back = Import-Clixml -Path $path
    $back.PSObject.TypeNames
    $back -is [InstanceStatus]
    $line | Export-Clixml -Path $path
    (Import-Clixml -Path $path).PSObject.TypeNames
}
finally {
    Remove-Item -Path $path -ErrorAction SilentlyContinue
}
