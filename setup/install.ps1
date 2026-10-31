<#
.SYNOPSIS
Installs the lab of the course: two SQL Server 2025 instances, the database, the remote host,
the webhook test server, the modules.

.DESCRIPTION
1. Installs the modules at the versions the course is written against, for the current user,
   from the PowerShell Gallery: those of level 1, Pester 6.2.0 and 5.9.1 side by side,
   PSScriptAnalyzer, and dbachecks after its dependencies, so that no newer dbatools comes
   with it. Downloads the help (Update-Help).
2. Downloads the backup of PachadataTraining (626 MB) and the three community tools of
   module 11, and checks their SHA-256 hashes.
3. Creates the key of the student under lab/ssh, starts the containers of compose.yaml
   (docker compose or podman compose) and adds the key of the remote host to known_hosts.
4. Restores PachadataTraining on sql1, creates the database DBA on both instances, and gives
   them different memory settings (the legitimate difference of module 12).
5. Creates the vault PachaOps and its secret sql-lab if they are missing (level 1, module 9).
6. Creates the fake backup files, then checks the lab (setup/test-lab.ps1, setup/test-host.ps1).

Run it again at any time: what is already done is skipped, except the restore, which only
runs when the database is missing.

.EXAMPLE
./setup/install.ps1

.EXAMPLE
./setup/install.ps1 -Engine podman
#>
[CmdletBinding()]
param(
    # The container engine: docker or podman.
    [ValidateSet('docker', 'podman')]
    [string] $Engine = 'docker',
    # The lab password of sa, the same as in compose.yaml.
    [string] $SaPassword = 'Course-2026!lab'
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

# Order matters: dbachecks declares dbatools and PSFramework without a version, so they are
# installed first at the course's versions, and dbachecks without its dependency check.
$modules = @(
    @{ Name = 'dbatools'; Version = '2.9.1' }
    @{ Name = 'SqlServer'; Version = '22.4.5.1' }
    @{ Name = 'Microsoft.PowerShell.SecretManagement'; Version = '1.1.2' }
    @{ Name = 'Microsoft.PowerShell.SecretStore'; Version = '1.0.6' }
    @{ Name = 'Pester'; Version = '6.2.0' }
    @{ Name = 'Pester'; Version = '5.9.1' }
    @{ Name = 'PSScriptAnalyzer'; Version = '1.25.0' }
    @{ Name = 'PSFramework'; Version = '1.15.479' }
    @{ Name = 'dbachecks'; Version = '3.0.2'; SkipDependencyCheck = $true }
)
foreach ($module in $modules) {
    if (-not (Get-InstalledPSResource -Name $module.Name -Version $module.Version -ErrorAction SilentlyContinue)) {
        Write-Host "Installing $($module.Name) $($module.Version)..."
        Install-PSResource -Name $module.Name -Version $module.Version -Scope CurrentUser `
            -TrustRepository -SkipDependencyCheck:([bool] $module.SkipDependencyCheck)
    }
}
Import-Module dbatools -RequiredVersion 2.9.1

# PowerShell 7 ships without the full help: Get-Help -Examples shows nothing until it is
# downloaded. A module whose help cannot be downloaded is not an error here.
Write-Host 'Downloading the help of PowerShell (about 20 seconds)...'
Update-Help -Scope CurrentUser -UICulture en-US -ErrorAction SilentlyContinue

$backup = 'setup/backup/PachadataTraining-2026-10.bak'
$url = 'https://files.pachadata.com/public/api/raw?hash=tAsyC50c6kfVadBp3zc6TQ&file=/PachadataTraining/SqlServer/PachadataTraining-2026-10.bak'
$sha256 = '1D05970D8E0576CD0C57BDDBA64C2BA8A583845AD4744ADEB75D2EA4A3F7D44E'
if (-not (Test-Path $backup)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
    Write-Host 'Downloading PachadataTraining-2026-10.bak (626 MB)...'
    Invoke-WebRequest -Uri $url -OutFile "$backup.part"
    Move-Item "$backup.part" $backup
}
if ((Get-FileHash $backup -Algorithm SHA256).Hash -ne $sha256) {
    throw "Checksum mismatch for $backup : delete it and run this script again."
}

# The community tools of module 11, at fixed versions: without -LocalFile, dbatools would
# download the Maintenance Solution from the current main branch.
$community = @(
    @{ File = 'ola.zip'; Sha256 = 'A09F6301E30CD9D5010BFC2807DD5DE3F3794A3ECE938929922659927DD61644'
       Url = 'https://github.com/olahallengren/sql-server-maintenance-solution/archive/41617578643e722b790ea4d57ef80f8de38ae747.zip' }
    @{ File = 'whoisactive.zip'; Sha256 = '2A486774B0EFD18A7BA2A45B6BBFF79D32C9A9ACE6DA679ED661AEB500EFA125'
       Url = 'https://github.com/amachanic/sp_whoisactive/archive/refs/tags/20260409.zip' }
    @{ File = 'frk.zip'; Sha256 = '4413CA953C4BF22E16E1890C8C975A18D26CE658C2AF093802A4C145386890A5'
       Url = 'https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/archive/refs/tags/20260708.zip' }
)
New-Item -ItemType Directory -Force -Path setup/community | Out-Null
foreach ($tool in $community) {
    $path = Join-Path setup/community $tool.File
    if (-not (Test-Path $path)) { Invoke-WebRequest -Uri $tool.Url -OutFile $path }
    if ((Get-FileHash $path -Algorithm SHA256).Hash -ne $tool.Sha256) {
        throw "Checksum mismatch for $path : delete it and run this script again."
    }
}

# The key of the student for the remote host (module 8). The folder is readable by the
# container's sshd, which reads authorized_keys as the user student.
New-Item -ItemType Directory -Force -Path lab/ssh, lab/backups, lab/webhook | Out-Null
if (-not (Test-Path lab/ssh/id_ed25519)) {
    ssh-keygen -q -t ed25519 -N '' -C pwshcourse-student -f lab/ssh/id_ed25519
    if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen failed.' }
}
Copy-Item lab/ssh/id_ed25519.pub lab/ssh/authorized_keys -Force
if (-not $IsWindows) { chmod 755 lab/ssh; chmod 644 lab/ssh/authorized_keys; chmod 600 lab/ssh/id_ed25519 }

& $Engine compose up -d --build --wait
if ($LASTEXITCODE -ne 0) { throw "$Engine compose up failed (exit code $LASTEXITCODE)." }

# A new volume can belong to root (Docker): SQL Server, which runs as mssql, could not write
# its backups there.
& $Engine exec -u 0 pwshcourse chown -R mssql /var/opt/mssql/backup
if ($LASTEXITCODE -ne 0) { throw "chown of the backup volume failed." }

Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
$cred = [pscredential]::new('sa', (ConvertTo-SecureString $SaPassword -AsPlainText -Force))
if (-not (Get-DbaDatabase -SqlInstance 'localhost,14533' -SqlCredential $cred -Database PachadataTraining)) {
    & $Engine cp $backup 'pwshcourse:/var/opt/mssql/backup/PachadataTraining-2026-10.bak'
    if ($LASTEXITCODE -ne 0) { throw "Copy of the backup into pwshcourse failed." }
    & $Engine exec -u 0 pwshcourse chown mssql /var/opt/mssql/backup/PachadataTraining-2026-10.bak
    Restore-DbaDatabase -SqlInstance 'localhost,14533' -SqlCredential $cred `
        -Path /var/opt/mssql/backup/PachadataTraining-2026-10.bak `
        -DatabaseName PachadataTraining `
        -DestinationDataDirectory /var/opt/mssql/data -DestinationLogDirectory /var/opt/mssql/data `
        -EnableException | Out-Null
    # The backup is at level 160 (built on SQL Server 2022); the course runs at level 170.
    Set-DbaDbCompatibility -SqlInstance 'localhost,14533' -SqlCredential $cred `
        -Database PachadataTraining -Compatibility 170 | Out-Null
    # The reference backup stays in setup/backup on this computer. Out of the shared volume,
    # no command of the course can restore it again or delete it by mistake.
    & $Engine exec -u 0 pwshcourse rm -f /var/opt/mssql/backup/PachadataTraining-2026-10.bak
}

# DBA receives the community tools and the deployment journal (module 11). The memory
# settings differ on purpose: module 12 shows a difference that is not a drift.
foreach ($instance in @{ Name = 'localhost,14533'; MemoryMB = 2048 }, @{ Name = 'localhost,14534'; MemoryMB = 1536 }) {
    if (-not (Get-DbaDatabase -SqlInstance $instance.Name -SqlCredential $cred -Database DBA)) {
        New-DbaDatabase -SqlInstance $instance.Name -SqlCredential $cred -Name DBA -EnableException | Out-Null
    }
    Set-DbaMaxMemory -SqlInstance $instance.Name -SqlCredential $cred -Max $instance.MemoryMB -EnableException -WarningAction SilentlyContinue | Out-Null
}

# The key of the remote host. A script has no console to accept it, and ssh refuses an
# unknown host (module 8). localhost resolves to ::1 first, and the port listens on 127.0.0.1.
$sshDir = Join-Path $HOME '.ssh'
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
$knownHosts = Join-Path $sshDir 'known_hosts'
if (Test-Path $knownHosts) { ssh-keygen -q -R '[localhost]:14535' -f $knownHosts *> $null }
$hostKey = ''
foreach ($try in 1..10) {
    $hostKey = ssh-keyscan -t ed25519 -p 14535 -T 5 127.0.0.1 2> $null
    if ($hostKey) { break }
    Start-Sleep -Seconds 2
}
if (-not $hostKey) { throw 'The remote host pwshcourse-host does not answer on port 14535.' }
Add-Content -Path $knownHosts -Value ($hostKey -replace '^\[127\.0\.0\.1\]', '[localhost]')

# The vault of level 1, module 9, without a password, so that a scheduled script can read it.
# Set-SecretStoreConfiguration would ask for a password to create the store, and without a
# console that prompt ends the script with exit code 0. Reset-SecretStore creates it without
# asking, but erases an existing store: it only runs when there is none.
$store = if ($IsWindows) { Join-Path $env:LOCALAPPDATA 'Microsoft/PowerShell/secretmanagement/localstore' }
         else { Join-Path $HOME '.secretmanagement/localstore' }
if (-not (Test-Path $store)) {
    Reset-SecretStore -Authentication None -Interaction None -Scope CurrentUser -Force -WarningAction SilentlyContinue
}
if (-not (Get-SecretVault -Name PachaOps -ErrorAction SilentlyContinue)) {
    Register-SecretVault -Name PachaOps -ModuleName Microsoft.PowerShell.SecretStore
}
if (-not (Get-SecretInfo -Vault PachaOps -Name sql-lab)) {
    Set-Secret -Vault PachaOps -Name sql-lab -Secret $cred
}

./setup/new-backupfiles.ps1
./setup/test-lab.ps1 -SaPassword $SaPassword
./setup/test-host.ps1
