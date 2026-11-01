# Clip 6.2: the status of an instance in the morning report, as a class, in a module of its
# own. Load it with:
#   using module ./demos/module_06/PachaReport.psm1
# Import-Module loads the function, not the types: Severity and InstanceStatus are only known
# to a session or a script that has the using module statement.

# How serious the state of an instance is. The order of the names is the order of the values:
# Ok is 0, Warning 1, Critical 2.
enum Severity {
    Ok
    Warning
    Critical
}

class InstanceStatus {
    [string] $Instance
    [Severity] $Severity
    [string] $Version
    [int] $Databases
    # Databases whose last full backup is missing or older than seven days.
    [int] $WithoutRecentFull

    InstanceStatus([string] $instance, [Severity] $severity) {
        $this.Instance = $instance
        $this.Severity = $severity
    }

    # The status of one instance, from its lines of Get-MorningReport.
    static [InstanceStatus] FromReport([object[]] $rows, [datetime] $referenceDate) {
        $status = [InstanceStatus]::new($rows[0].Instance, [Severity]::Ok)
        if ($rows[0].Status -eq 'Unreachable') {
            $status.Severity = [Severity]::Critical
            return $status
        }
        $limit = $referenceDate.AddDays(-7)
        $status.Version = $rows[0].Version
        $status.Databases = $rows.Count
        $status.WithoutRecentFull = @($rows | Where-Object { $null -eq $_.LastFullBackup -or $_.LastFullBackup -lt $limit }).Count
        if ($status.WithoutRecentFull -gt 0) {
            $status.Severity = [Severity]::Warning
        }
        return $status
    }

    [string] ToString() {
        return '{0} ({1})' -f $this.Instance, $this.Severity
    }
}

function Get-InstanceStatus {
    <#
    .SYNOPSIS
    Turns the lines of the morning report into one InstanceStatus per instance.

    .EXAMPLE
    Get-MorningReport -InventoryPath data/instances.csv -SqlCredential $credential | Get-InstanceStatus
    #>
    [CmdletBinding()]
    [OutputType([InstanceStatus])]
    param(
        # The lines of Get-MorningReport.
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $InputObject,
        # The day the backups are judged for; now by default.
        [datetime] $ReferenceDate = (Get-Date)
    )
    begin {
        $rows = [System.Collections.Generic.List[psobject]]::new()
    }
    process {
        $rows.Add($InputObject)
    }
    end {
        foreach ($group in $rows | Group-Object -Property Instance) {
            [InstanceStatus]::FromReport($group.Group, $ReferenceDate)
        }
    }
}

Export-ModuleMember -Function Get-InstanceStatus
