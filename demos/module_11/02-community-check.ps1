# Clip 11.1: what the three tools created in DBA on each instance, and the version that each
# one says it is: the proof that the files of setup/community were installed, and not another
# copy. The Maintenance Solution writes its version in the header of each procedure,
# sp_WhoIsActive in its own header, and sp_Blitz returns its own with @VersionCheckMode = 1.
param(
    [string[]] $SqlInstance = @('localhost,14533', 'localhost,14534'),
    [string] $Database = 'DBA'
)
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$query = @'
SELECT o.type_desc AS Type, COUNT(*) AS Objects
FROM sys.objects AS o
WHERE o.is_ms_shipped = 0 AND o.parent_object_id = 0
GROUP BY o.type_desc;
'@
$versions = @'
DECLARE @blitz varchar(30), @blitzDate datetime;
EXEC dbo.sp_Blitz @Version = @blitz OUTPUT, @VersionDate = @blitzDate OUTPUT, @VersionCheckMode = 1;
SELECT
    SUBSTRING(m.definition, CHARINDEX('Version: ', m.definition) + 9, 19) AS MaintenanceSolution,
    SUBSTRING(w.definition, CHARINDEX('Who Is Active? v', w.definition) + 16, 13) AS WhoIsActive,
    @blitz + ' of ' + CONVERT(char(10), @blitzDate, 23) AS FirstResponderKit
FROM sys.sql_modules AS m
CROSS JOIN sys.sql_modules AS w
WHERE m.object_id = OBJECT_ID(N'dbo.CommandExecute') AND w.object_id = OBJECT_ID(N'dbo.sp_WhoIsActive');
'@
Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $credential -Database $Database -Query $query -AppendServerInstance -EnableException |
    Select-Object -Property ServerInstance, Type, Objects | Format-Table | Out-String
Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $credential -Database $Database -Query $versions -AppendServerInstance -EnableException |
    Select-Object -Property ServerInstance, MaintenanceSolution, WhoIsActive, FirstResponderKit | Format-Table | Out-String
