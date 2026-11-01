# Clip 7.3: the connection test as thread jobs, one job per instance, three running at a time.
# A thread job runs in the same process: dbatools, imported here, is already loaded, and the
# setting of Set-DbatoolsInsecureConnection is seen by every job.
Import-Module -Name dbatools
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$inventory = Import-Csv -Path (Join-Path $PSScriptRoot '..' '..' 'data' 'instances.csv')
$jobs = foreach ($instance in $inventory) {
    Start-ThreadJob -Name $instance.Name -ThrottleLimit 3 -ScriptBlock {
        $instance = $using:instance
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
