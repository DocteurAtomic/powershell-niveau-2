# Changelog of PachaOps

What changed in each published version of the module, newest first. The team's rule, in
0.x: the minor number goes up when a function returns different objects, the patch number
when nothing it returns changes. The CHANGELOG.md at the root of the repository is another
file: it lists the corrections of the course.

## 0.2.1

- Get-MorningReport writes "Checking <instance>..." with Write-Verbose instead of Write-Host:
  the lines show only with -Verbose. Its loop calls ForEach-Object instead of the % alias. It
  returns the same objects as 0.2.0, with the same parameters, -Password included.

## 0.2.0

- Get-BackupAge computes the age between two UTC times. It subtracted the UTC write time of
  the file from a local reference date, so every age was off by the UTC offset of the
  workstation (10.08 days instead of 10.04 in Paris, for a file written on 23 October and a
  report on 2 November 2026, both at 10:00).
- Get-BackupAge writes the age of each file with Write-Verbose instead of Write-Host.
- The manifest has a Description and release notes: a module without a description cannot be
  published.

## 0.1.0

- Get-BackupAge, Remove-OldBackup, Get-ErrorLogSummary and Get-MorningReport, from the
  scripts of the team. Copied from workstation to workstation, never published.
