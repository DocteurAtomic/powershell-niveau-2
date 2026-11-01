-- 0002: what the team reads in the morning on each instance: how many scripts were applied,
-- and the last one, when and by whom. Like every script of the team, it does not name its
-- database.
CREATE VIEW dbo.DeploymentSummary
AS
SELECT TOP (1)
    (SELECT COUNT(*) FROM dbo.DeploymentJournal) AS ScriptCount,
    ScriptName AS LastScript,
    AppliedAt AS LastAppliedAt,
    AppliedBy AS LastAppliedBy
FROM dbo.DeploymentJournal
ORDER BY AppliedAt DESC, ScriptName DESC;
