# Clip 7.1: the connection test of the inventory, one instance after the other. Each object
# says whether the instance answered, and how many seconds the attempt took.
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$inventory = Import-Csv -Path (Join-Path $PSScriptRoot '..' '..' 'data' 'instances.csv')
foreach ($instance in $inventory) {
    $start = Get-Date
    try {
        $null = Connect-DbaInstance -SqlInstance $instance.SqlInstance -SqlCredential $credential
        $reachable = $true
    }
    catch {
        $reachable = $false
    }
    [pscustomobject]@{
        Instance  = $instance.Name
        Reachable = $reachable
        Seconds   = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    }
}
