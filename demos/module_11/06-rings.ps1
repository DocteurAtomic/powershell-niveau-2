# Clip 11.3: the deployment in rings. The test instance first; the production instances only
# when every test instance succeeded, three at a time. The rules of module 7: dbatools is
# imported here and the credential read here, once, before the loop. A function does not
# reach the runspaces: each one dot-sources the file of Deploy-PachaScript.
# Two of the production instances are names of the inventory that do not answer in the lab.
# With -PassThru, the objects instead of the table (08-monthly.ps1).
param(
    # The instances deployed first.
    [string[]] $TestInstance = @('localhost,14534'),
    # The instances deployed when the test instances succeeded.
    [string[]] $ProductionInstance = @('localhost,14533', 'compta01.pachadata.example,1433', 'elearn01.pachadata.example,1433'),
    # How many instances of a ring are deployed at the same time.
    [int] $ThrottleLimit = 3,
    # Return the objects.
    [switch] $PassThru
)
$ErrorActionPreference = 'Stop'
Import-Module -Name dbatools
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$function = Join-Path $PSScriptRoot 'Deploy-PachaScript.ps1'
$scripts = Join-Path $PSScriptRoot 'scripts'
$begin = Get-Date
$rings = [ordered]@{ Test = $TestInstance; Production = $ProductionInstance }
$stopped = $false
$results = foreach ($ring in $rings.GetEnumerator()) {
    if ($stopped) {
        foreach ($instance in $ring.Value) {
            [pscustomobject]@{ Ring = $ring.Key; SqlInstance = $instance; Script = $null; Status = 'NotDeployed'; Seconds = $null }
        }
        continue
    }
    $name = $ring.Key
    $deployed = $ring.Value | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        . $using:function
        Deploy-PachaScript -SqlInstance $_ -SqlCredential $using:credential -Path $using:scripts | ForEach-Object {
            [pscustomobject]@{
                Ring        = $using:name
                SqlInstance = $_.SqlInstance
                Script      = $_.Script
                Status      = $_.Status
                Seconds     = [math]::Round(((Get-Date) - $using:begin).TotalSeconds, 1)
            }
        }
    }
    $deployed
    if ($deployed | Where-Object -Property Status -NotIn 'Applied', 'AlreadyApplied') { $stopped = $true }
}
if ($PassThru) { return $results }
$results | Format-Table | Out-String
