# Clips 6.2 and 6.3: lines shaped like those of Get-MorningReport, for three instances, so that
# the clips run without the lab. sql1 has a full backup of each database in the last week,
# sql2 has a database without one, compta01 does not answer. The reference day is
# 2 November 2026.
#   $rows = & ./demos/module_06/sample-report.ps1
$recent = [datetime] '2026-11-01 01:00'
$old = [datetime] '2026-10-18 01:00'
[pscustomobject]@{ Instance = 'sql1'; Status = 'Online'; Version = '17.0.4065.4'; Database = 'master'; RecoveryModel = 'Simple'; LastFullBackup = $recent }
[pscustomobject]@{ Instance = 'sql1'; Status = 'Online'; Version = '17.0.4065.4'; Database = 'PachadataTraining'; RecoveryModel = 'Simple'; LastFullBackup = $recent }
[pscustomobject]@{ Instance = 'sql1'; Status = 'Online'; Version = '17.0.4065.4'; Database = 'DBA'; RecoveryModel = 'Full'; LastFullBackup = $recent }
[pscustomobject]@{ Instance = 'sql2'; Status = 'Online'; Version = '17.0.4065.4'; Database = 'master'; RecoveryModel = 'Simple'; LastFullBackup = $recent }
[pscustomobject]@{ Instance = 'sql2'; Status = 'Online'; Version = '17.0.4065.4'; Database = 'DBA'; RecoveryModel = 'Full'; LastFullBackup = $old }
[pscustomobject]@{ Instance = 'compta01'; Status = 'Unreachable'; Version = $null; Database = $null; RecoveryModel = $null; LastFullBackup = $null }
