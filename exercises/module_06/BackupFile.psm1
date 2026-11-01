# Exercise of module 6: the type of a backup file of the team. The README of this folder says
# what to write. Check it from the root of the clone with:
#   ./exercises/module_06/check.ps1
# A class is compiled once per session: after a change, try it in a new pwsh, as check.ps1 does.

# The three types of backup the team takes. Only one is written so far.
enum BackupType {
    Full
}

class BackupFile {
    [string] $FullName

    BackupFile([System.IO.FileInfo] $file) {
        $this.FullName = $file.FullName
    }
}
