# Clip 7.1: the same connection test, three instances at a time. The credential is read once
# here and passed by $using:, and dbatools is imported here before the loop (clip 7.2 says
# why). Start and End are the seconds since the loop began: they show the waves (clip 7.2).
# In a runspace, a failed Connect-DbaInstance also writes a warning, which it does not do in
# the session (measured with dbatools 2.9.1): the warning is silenced, the object says it.
param(
    # How many instances are tested at the same time.
    [int] $ThrottleLimit = 3
)
Import-Module -Name dbatools
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$inventory = Import-Csv -Path (Join-Path $PSScriptRoot '..' '..' 'data' 'instances.csv')
$begin = Get-Date
$inventory | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
    $start = Get-Date
    try {
        $null = Connect-DbaInstance -SqlInstance $_.SqlInstance -SqlCredential $using:credential -WarningAction SilentlyContinue
        $reachable = $true
    }
    catch {
        $reachable = $false
    }
    [pscustomobject]@{
        Instance  = $_.Name
        Reachable = $reachable
        Start     = [math]::Round(($start - $using:begin).TotalSeconds, 1)
        End       = [math]::Round(((Get-Date) - $using:begin).TotalSeconds, 1)
    }
}
