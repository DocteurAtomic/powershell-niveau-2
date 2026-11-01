<#
.SYNOPSIS
Compares the options of the databases of each instance with the rules of the team, and returns
one object per difference.

.DESCRIPTION
The rules are a JSON file: ExcludeDatabase, the databases left out (the system ones), and
Options, the name of each option as Get-DbaDatabase returns it, with its expected value. One
object per database and per option that differs: SqlInstance, Database, Option, Expected,
Actual. Nothing when every database follows the rules.

.EXAMPLE
./exercises/module_12/solution/Get-DatabaseDrift.ps1 -SqlInstance 'localhost,14534' | Format-Table
#>
[CmdletBinding()]
param(
    [string[]] $SqlInstance = @('localhost,14534'),
    # The rules of the team.
    [string] $ReferencePath = (Join-Path $PSScriptRoot 'pachadata-database.json')
)
$ErrorActionPreference = 'Stop'
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$reference = Get-Content -Path $ReferencePath -Raw | ConvertFrom-Json
$exclude = @($reference.ExcludeDatabase)
foreach ($instance in $SqlInstance) {
    $databases = Get-DbaDatabase -SqlInstance $instance -SqlCredential $credential -EnableException |
        Where-Object -Property Name -NotIn $exclude
    foreach ($database in $databases) {
        foreach ($option in $reference.Options.PSObject.Properties) {
            $actual = $database.($option.Name)
            # Compared as text: PageVerify is an enumeration of SMO, the JSON value a string.
            if ("$actual" -ne "$($option.Value)") {
                [pscustomobject]@{
                    SqlInstance = $instance
                    Database    = $database.Name
                    Option      = $option.Name
                    Expected    = $option.Value
                    Actual      = $actual
                }
            }
        }
    }
}
