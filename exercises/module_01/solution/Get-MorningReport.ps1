function Get-MorningReport {
    <#
    .SYNOPSIS
    The morning report: every database of the inventory, with its recovery model and its last
    full backup, and the instances that could not be reached.

    .EXAMPLE
    Get-MorningReport -InventoryPath data/instances.csv -SqlCredential (Get-Secret -Vault PachaOps -Name sql-lab)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password',
        Justification = 'Older scripts of the team still call -Password. Removing it changes how the function is called: that waits for a test.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Turns the -Password of the older scripts into a credential; goes away with -Password.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $InventoryPath,
        [pscredential] $SqlCredential,
        # Older scripts of the team pass the password of sa here.
        [string] $Password
    )
    if ($Password) {
        $SqlCredential = New-Object pscredential 'sa', (ConvertTo-SecureString $Password -AsPlainText -Force)
    }
    foreach ($instance in Import-Csv -Path $InventoryPath) {
        Write-Verbose "Checking $($instance.Name)..."
        try {
            $server = Connect-DbaInstance -SqlInstance $instance.SqlInstance -SqlCredential $SqlCredential
        }
        catch {
            [pscustomobject]@{
                Instance = $instance.Name; Status = 'Unreachable'; Version = $null
                Database = $null; RecoveryModel = $null; LastFullBackup = $null
            }
            continue
        }
        Get-DbaDatabase -SqlInstance $server -ExcludeDatabase tempdb | ForEach-Object {
            [pscustomobject]@{
                Instance       = $instance.Name
                Status         = 'Online'
                Version        = $server.VersionString
                Database       = $_.Name
                RecoveryModel  = $_.RecoveryModel
                LastFullBackup = if ($_.LastFullBackup -gt [datetime]'1900-01-01') { $_.LastFullBackup }
            }
        }
    }
}
