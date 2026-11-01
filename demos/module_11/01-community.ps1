# Clip 11.1: the three community tools of the request, installed on both instances of the lab
# into the database DBA, from the files that setup/install.ps1 downloaded once, at fixed
# versions. Without -Database, two of them install into master. 99-cleanup.ps1 removes them.
# The Maintenance Solution comes as the archive of a commit, whose folder is named after the
# commit. dbatools 2.9.1 only takes an archive whose folder is named
# sql-server-maintenance-solution-main: given another one, it writes a warning and installs the
# copy it carries in its own folder. The archive is rebuilt under that name, in a temporary
# folder. -ReplaceExisting replaces the four procedures of the Maintenance Solution when they
# are already there (with -LogToTable, it would also drop the table CommandLog and its history):
# without it, a second run stops on the Maintenance Solution.
param(
    # The instances of the team.
    [string[]] $SqlInstance = @('localhost,14533', 'localhost,14534'),
    # The database that receives the tools.
    [string] $Database = 'DBA'
)
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$credential = Get-Secret -Vault PachaOps -Name sql-lab
$community = Join-Path $PSScriptRoot '..' '..' 'setup' 'community'
$common = @{ SqlInstance = $SqlInstance; SqlCredential = $credential; Database = $Database; EnableException = $true }

$work = Join-Path ([System.IO.Path]::GetTempPath()) "m11-ola-$([guid]::NewGuid())"
try {
    Expand-Archive -LiteralPath (Join-Path $community 'ola.zip') -DestinationPath $work
    $folder = Get-ChildItem -Path $work -Directory
    $main = Rename-Item -Path $folder.FullName -NewName 'sql-server-maintenance-solution-main' -PassThru
    $ola = Join-Path $work 'ola-main.zip'
    Compress-Archive -Path $main.FullName -DestinationPath $ola
    $maintenance = Install-DbaMaintenanceSolution @common -LocalFile $ola -ReplaceExisting
}
finally {
    Remove-Item -Path $work -Recurse -Force
}
$whoIsActive = Install-DbaWhoIsActive @common -LocalFile (Join-Path $community 'whoisactive.zip')
$firstResponder = Install-DbaFirstResponderKit @common -LocalFile (Join-Path $community 'frk.zip')

# One line per tool and per instance: the three commands return objects of different shapes,
# and the First Responder Kit one object per procedure. 02-community-check.ps1 lists the objects.
@(
    $maintenance | Select-Object -Property SqlInstance, @{ Name = 'Tool'; Expression = { 'Maintenance Solution' } },
        @{ Name = 'Status'; Expression = { $_.Results } }
    $whoIsActive | Select-Object -Property SqlInstance, @{ Name = 'Tool'; Expression = { 'sp_WhoIsActive' } }, Status
    $firstResponder | Group-Object -Property SqlInstance | ForEach-Object {
        [pscustomobject]@{
            SqlInstance = $_.Name
            Tool        = 'First Responder Kit'
            Status      = ($_.Group.Status | Sort-Object -Unique) -join ', '
        }
    }
) | Sort-Object -Property SqlInstance, Tool | Format-Table | Out-String
