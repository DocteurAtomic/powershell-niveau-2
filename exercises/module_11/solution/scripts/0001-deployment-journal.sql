-- 0001: the journal of the deployments of the team. Deploy-PachaScript writes one row here for
-- each script it applies, in the same transaction as the script. The script does not name its
-- database: the deployment chooses it.
CREATE TABLE dbo.DeploymentJournal (
    ScriptName  nvarchar(260) NOT NULL CONSTRAINT PK_DeploymentJournal PRIMARY KEY,
    Checksum    char(64)      NOT NULL,
    AppliedAt   datetime2(0)  NOT NULL CONSTRAINT DF_DeploymentJournal_AppliedAt DEFAULT SYSUTCDATETIME(),
    AppliedBy   nvarchar(128) NOT NULL,
    AppliedFrom nvarchar(128) NOT NULL,
    LoginName   sysname       NOT NULL CONSTRAINT DF_DeploymentJournal_LoginName DEFAULT SUSER_SNAME()
);
