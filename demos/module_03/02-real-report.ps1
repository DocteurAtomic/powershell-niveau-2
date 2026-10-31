# Clip 3.2: the morning report on the lab, as the team runs it every morning.
# Run it from the root of the clone, or type the lines one after the other.
# The four .example instances of the inventory do not answer: the report waits for each one.
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
Import-Module -Name ./src/PachaOps/PachaOps.psd1
$credential = Get-Secret -Vault PachaOps -Name sql-lab

$duration = Measure-Command {
    $report = Get-MorningReport -InventoryPath data/instances.csv -SqlCredential $credential 6> $null
}
$report | Group-Object -Property Instance, Status -NoElement | Out-Host
'{0:N1} s' -f $duration.TotalSeconds
