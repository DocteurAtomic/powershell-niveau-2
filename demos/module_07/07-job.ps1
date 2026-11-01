# Clip 7.3: the same test as background jobs. Each job is a new pwsh process: it loads dbatools
# again and needs its own Set-DbatoolsInsecureConnection, all six jobs run at once (Start-Job
# has no throttle limit), and their objects come back deserialized.
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$inventory = Import-Csv -Path (Join-Path $PSScriptRoot '..' '..' 'data' 'instances.csv')
$jobs = foreach ($instance in $inventory) {
    Start-Job -Name $instance.Name -ScriptBlock {
        $instance = $using:instance
        Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
        try {
            $null = Connect-DbaInstance -SqlInstance $instance.SqlInstance -SqlCredential $using:credential -WarningAction SilentlyContinue
            $reachable = $true
        }
        catch {
            $reachable = $false
        }
        [pscustomobject]@{ Instance = $instance.Name; Reachable = $reachable }
    }
}
$jobs | Receive-Job -Wait -AutoRemoveJob
