# Solution of the exercise of module 6: the type of a backup file of the team.
#   using module ./exercises/module_06/solution/BackupFile.psm1
#   Get-ChildItem -Path lab/backups -Recurse -Include *.bak, *.trn | ForEach-Object { [BackupFile]::new($_) }

# The three types of backup the team takes.
enum BackupType {
    Full
    Differential
    Log
}

class BackupFile {
    [string] $FullName
    [string] $Name
    [string] $Instance
    [string] $Database
    [BackupType] $Type
    [long] $Length
    [datetime] $LastWriteTimeUtc

    # A file named as the Maintenance Solution names it: instance_database_TYPE_date_time.ext.
    # The extension does not tell a full backup from a differential one, both are .bak: the
    # type is read in the name.
    BackupFile([System.IO.FileInfo] $file) {
        if ($file.Name -notmatch '^(?<instance>[^_]+)_(?<database>.+)_(?<type>FULL|DIFF|LOG)_\d{8}_\d{6}\.(bak|trn)$') {
            throw "Not a backup file of the team: $($file.FullName)"
        }
        $this.FullName = $file.FullName
        $this.Name = $file.Name
        $this.Instance = $Matches.instance
        $this.Database = $Matches.database
        $this.Type = switch ($Matches.type) {
            'FULL' { [BackupType]::Full }
            'DIFF' { [BackupType]::Differential }
            'LOG' { [BackupType]::Log }
        }
        $this.Length = $file.Length
        $this.LastWriteTimeUtc = $file.LastWriteTimeUtc
    }

    # The age in days at a reference date. A reference date in local time, such as Get-Date
    # or '2026-11-02', goes to UTC first, as in Get-BackupAge since PachaOps 0.2.0.
    [double] AgeDays([datetime] $referenceDate) {
        return ($referenceDate.ToUniversalTime() - $this.LastWriteTimeUtc).TotalDays
    }

    [bool] IsOlderThan([int] $days, [datetime] $referenceDate) {
        return $this.AgeDays($referenceDate) -gt $days
    }

    # A method parameter has no default value: a second overload takes the date of now.
    [bool] IsOlderThan([int] $days) {
        return $this.IsOlderThan($days, (Get-Date))
    }

    [string] ToString() {
        return $this.Name
    }
}
