function Get-PachaConfiguration {
    <#
    .SYNOPSIS
    Reads the server configuration of an instance (sp_configure), reduced to what can be saved
    and compared: DisplayName, ConfiguredValue and RunningValue, sorted by DisplayName.

    .DESCRIPTION
    Get-DbaSpConfigure returns objects that ConvertTo-Json cannot serialize (they hold the SMO
    objects of the instance), so the function keeps three properties. The key is DisplayName,
    the name that sp_configure shows: with dbatools 2.9.1, twelve settings of SQL Server 2025
    have an empty Name, which SMO does not know.

    .EXAMPLE
    . ./demos/module_12/PachaConfiguration.ps1
    Get-PachaConfiguration -SqlInstance 'localhost,14534' -SqlCredential (Get-Secret -Vault PachaOps -Name sql-lab)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SqlInstance,
        [Parameter(Mandatory)]
        [pscredential] $SqlCredential
    )
    Get-DbaSpConfigure -SqlInstance $SqlInstance -SqlCredential $SqlCredential -EnableException |
        Sort-Object -Property DisplayName |
        ForEach-Object {
            [pscustomobject]@{
                DisplayName     = $_.DisplayName
                ConfiguredValue = [long] $_.ConfiguredValue
                RunningValue    = [long] $_.RunningValue
            }
        }
}

function Compare-PachaConfiguration {
    <#
    .SYNOPSIS
    Compares the configuration of each instance with its reference file, and returns one object
    per setting that differs.

    .DESCRIPTION
    A reference file, written by demos/module_12/02-snapshot.ps1 and kept in Git, holds the
    address of its instance and its settings. Each instance is compared with its own reference,
    not with another instance: two instances may differ on purpose (max server memory).

    One object per difference: SqlInstance, Setting, Status (Changed, New when the setting is
    not in the reference, Missing when the instance no longer has it), Reference (the
    configured value of the reference), Configured and Running (the values read now). Nothing
    when the instance is like its reference.

    .EXAMPLE
    . ./demos/module_12/PachaConfiguration.ps1
    Compare-PachaConfiguration -Path ./demos/module_12/reference/sql2.json -SqlCredential (Get-Secret -Vault PachaOps -Name sql-lab)
    #>
    [CmdletBinding()]
    param(
        # The reference files, one per instance.
        [Parameter(Mandatory)]
        [string[]] $Path,
        [Parameter(Mandatory)]
        [pscredential] $SqlCredential
    )
    foreach ($file in $Path) {
        $reference = Get-Content -Path $file -Raw | ConvertFrom-Json
        $current = Get-PachaConfiguration -SqlInstance $reference.SqlInstance -SqlCredential $SqlCredential
        $differences = Compare-Object -ReferenceObject $reference.Settings -DifferenceObject $current `
            -Property DisplayName, ConfiguredValue, RunningValue
        # A changed setting appears twice, once on each side: <= its line in the reference,
        # => its line now.
        foreach ($group in $differences | Group-Object -Property DisplayName) {
            $before = $group.Group | Where-Object -Property SideIndicator -EQ '<='
            $now = $group.Group | Where-Object -Property SideIndicator -EQ '=>'
            [pscustomobject]@{
                SqlInstance = $reference.SqlInstance
                Setting     = $group.Name
                Status      = if ($before -and $now) { 'Changed' } elseif ($now) { 'New' } else { 'Missing' }
                Reference   = $before.ConfiguredValue
                Configured  = $now.ConfiguredValue
                Running     = $now.RunningValue
            }
        }
    }
}

function Repair-PachaConfiguration {
    <#
    .SYNOPSIS
    Sets a changed setting back to the value of its reference, and writes why in the journal of
    the team.

    .DESCRIPTION
    Takes the objects of Compare-PachaConfiguration from the pipeline. For each Changed setting,
    it calls Set-DbaSpConfigure with the value of the reference, then adds one line to the
    journal (a JSON file of lines): when (UTC), by whom, from which computer, the instance, the
    setting, the previous and the new value, and the reason. -WhatIf says what would be set,
    and neither sets nor writes anything.

    .EXAMPLE
    Compare-PachaConfiguration -Path ./demos/module_12/reference/sql2.json -SqlCredential $credential |
        Repair-PachaConfiguration -SqlCredential $credential -Reason 'Set by hand on 2026-11-02, not in the reference' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # A difference returned by Compare-PachaConfiguration.
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $InputObject,
        [Parameter(Mandatory)]
        [pscredential] $SqlCredential,
        # Why the setting is set back: the journal keeps it.
        [Parameter(Mandatory)]
        [string] $Reason,
        # The journal of the team.
        [string] $LogPath = (Join-Path $PSScriptRoot '..' '..' 'lab' 'reports' 'configuration.jsonl')
    )
    process {
        if ($InputObject.Status -ne 'Changed') {
            Write-Warning "$($InputObject.Setting) on $($InputObject.SqlInstance) is $($InputObject.Status): only a changed setting is set back."
            return
        }
        # Set-DbaSpConfigure has its own -WhatIf, but the preference of this function does not
        # reach a command of a module: the function asks for itself.
        $target = "$($InputObject.SqlInstance), $($InputObject.Setting)"
        if (-not $PSCmdlet.ShouldProcess($target, "Set from $($InputObject.Configured) back to $($InputObject.Reference)")) {
            return
        }
        $setting = Get-DbaSpConfigure -SqlInstance $InputObject.SqlInstance -SqlCredential $SqlCredential -EnableException |
            Where-Object -Property DisplayName -EQ $InputObject.Setting
        $result = $setting | Set-DbaSpConfigure -Value $InputObject.Reference -EnableException
        $line = [ordered]@{
            Time          = [datetime]::UtcNow.ToString('o')
            Operator      = [System.Environment]::UserName
            Computer      = [System.Environment]::MachineName
            SqlInstance   = $InputObject.SqlInstance
            Setting       = $InputObject.Setting
            PreviousValue = $result.PreviousValue
            NewValue      = $result.NewValue
            Reason        = $Reason
        }
        New-Item -ItemType Directory -Path (Split-Path -Path $LogPath -Parent) -Force | Out-Null
        $line | ConvertTo-Json -Compress | Add-Content -Path $LogPath
        [pscustomobject] $line
    }
}
