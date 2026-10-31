<#
.SYNOPSIS
Checks the exercise of module 4.

.DESCRIPTION
Reads your workstation and the team's repository, and checks the result of the exercise:

- lab/repository has PachaOps 0.2.0 and 0.2.1;
- your workstation has both installed (Get-InstalledPSResource, scope CurrentUser);
- each one loads by Import-Module -RequiredVersion, each in its own pwsh process, and
  Import-Module without a version loads 0.2.1;
- 0.2.1 has release notes of its own, and a CHANGELOG.md with an entry for 0.2.1;
- 0.2.1 holds only the files of the module (no tests, no settings): it was published from
  out/PachaOps, built by ./build.ps1;
- in 0.2.1, Get-MorningReport writes nothing with Write-Host, the analyzer reports nothing
  with the settings of the team, and PSAvoidUsingWriteHost and PSAvoidUsingCmdletAliases are
  corrected, not suppressed;
- 0.2.1 exports the same commands as 0.2.0, Get-MorningReport keeps its parameters, and it
  returns the same objects. The report runs without SQL Server: the two dbatools commands it
  calls are replaced, inside the module, by functions that return made-up objects.

Exits with 0 when everything is right, 1 otherwise, and says what is missing.

With -Solution, checks the solution instead, without touching your workstation: in a
temporary folder, it publishes the frozen copy of 0.2.0 (reference/) to a temporary
repository, installs it under a temporary HOME, then runs solution/release.ps1 on the files of
solution/ laid over that copy. The folder is removed at the end. The isolation goes through
HOME, which is how PowerShell finds the user's modules on Linux and macOS, not on Windows:
there, -Solution refuses to run.

.EXAMPLE
./exercises/module_04/check.ps1
#>
[CmdletBinding()]
param(
    # Check the solution instead of your workstation.
    [switch] $Solution
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$settings = Join-Path $root 'PSScriptAnalyzerSettings.psd1'
$toCorrect = 'PSAvoidUsingWriteHost', 'PSAvoidUsingCmdletAliases'
$versions = '0.2.0', '0.2.1'
$problems = [System.Collections.Generic.List[string]]::new()

# The child process that loads one version and reads it. Its text output is discarded; it
# writes what it found as JSON.
$inspector = {
    param($Version, $InventoryPath, $ResultPath)
    $WarningPreference = 'SilentlyContinue'
    $found = [ordered]@{ Version = $Version; Error = $null }
    try {
        if ($Version) {
            Import-Module -Name PachaOps -RequiredVersion $Version
        }
        else {
            Import-Module -Name PachaOps
        }
        $module = Get-Module -Name PachaOps
        $found.Loaded = "$($module.Version)"
        $found.ModuleBase = $module.ModuleBase
        $found.ReleaseNotes = "$($module.ReleaseNotes)"
        $found.Commands = @($module.ExportedCommands.Keys | Sort-Object)
        $found.Parameters = @((Get-Command -Name Get-MorningReport -Module PachaOps).Parameters.Values |
                Where-Object -Property Name -NotIn ([System.Management.Automation.PSCmdlet]::CommonParameters) |
                ForEach-Object { "$($_.Name):$($_.ParameterType.Name)" } | Sort-Object)
        # dbatools replaced inside the module: a function of the module's scope is found before
        # the commands that dbatools exports.
        & $module {
            function script:Connect-DbaInstance {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SqlCredential',
                    Justification = 'The fake accepts the parameter that the report passes.')]
                param($SqlInstance, [pscredential] $SqlCredential)
                if ("$SqlInstance" -like 'compta01*') { throw 'The instance does not answer.' }
                [pscustomobject]@{ VersionString = '17.0.4065.4' }
            }
            function script:Get-DbaDatabase {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SqlInstance',
                    Justification = 'The fake accepts the parameter that the report passes.')]
                param($SqlInstance, [string[]] $ExcludeDatabase)
                @(
                    [pscustomobject]@{ Name = 'master'; RecoveryModel = 'Simple'; LastFullBackup = [datetime]::MinValue }
                    [pscustomobject]@{ Name = 'tempdb'; RecoveryModel = 'Simple'; LastFullBackup = [datetime]::MinValue }
                    [pscustomobject]@{ Name = 'Planning'; RecoveryModel = 'Full'; LastFullBackup = [datetime]::new(2026, 11, 1, 22, 0, 0) }
                ) | Where-Object -Property Name -NotIn $ExcludeDatabase
            }
        }
        $report = Get-MorningReport -InventoryPath $InventoryPath -InformationVariable information
        $found.Report = @($report | Select-Object -Property Instance, Status, Version, Database, RecoveryModel,
            @{ Name = 'LastFullBackup'; Expression = { "$($_.LastFullBackup)" } })
        $found.HostLines = @($information | Where-Object -Property Tags -Contains 'PSHOST').Count
    }
    catch {
        $found.Error = $_.Exception.Message
    }
    [pscustomobject]$found | ConvertTo-Json -Depth 4 | Set-Content -Path $ResultPath
}

# The child process that reads what the workstation has installed.
$lister = {
    param($ResultPath)
    @(Get-InstalledPSResource -Name PachaOps -Scope CurrentUser -ErrorAction SilentlyContinue |
            ForEach-Object { "$($_.Version)" }) | ConvertTo-Json | Set-Content -Path $ResultPath
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) "check-module-04-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
$savedEnvironment = @{}
try {
    $repository = Join-Path $root 'lab' 'repository'
    if ($Solution) {
        if ($IsWindows) {
            'FAIL  -Solution isolates the installations through HOME, which Windows does not use for modules: run it on Linux or macOS, or in the continuous integration.'
            exit 1
        }
        # A temporary workstation: HOME and the XDG folders point into $work for every child
        # process, so that the installations, the registered repository and the NuGet settings
        # stay there.
        $workstation = Join-Path $work 'home'
        foreach ($name in 'HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME') {
            $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
        }
        $env:HOME = $workstation
        $env:XDG_DATA_HOME = Join-Path $workstation '.local' 'share'
        $env:XDG_CONFIG_HOME = Join-Path $workstation '.config'
        $env:XDG_CACHE_HOME = Join-Path $workstation '.cache'
        New-Item -ItemType Directory -Path $env:XDG_DATA_HOME, $env:XDG_CONFIG_HOME, $env:XDG_CACHE_HOME | Out-Null

        $repository = Join-Path $work 'repository'
        $source = Join-Path $work 'src' 'PachaOps'
        New-Item -ItemType Directory -Path $repository, (Split-Path $source) | Out-Null
        Copy-Item -Path (Join-Path $PSScriptRoot 'reference' 'PachaOps') -Destination $source -Recurse
        $setup = {
            param($Repository, $Build, $Source, $Overlay, $Release, $OutputPath)
            $ErrorActionPreference = 'Stop'
            Register-PSResourceRepository -Name PachaTeam -Uri $Repository -Trusted
            # The state the exercise starts from: 0.2.0 published and installed.
            & $Build -SourcePath $Source -OutputPath $OutputPath -Repository PachaTeam | Out-Null
            Install-PSResource -Name PachaOps -Version 0.2.0 -Repository PachaTeam -SkipDependencyCheck -Scope CurrentUser
            # The solution: its files over the module, then its commands.
            Copy-Item -Path (Join-Path $Overlay '*') -Destination $Source -Recurse -Force
            & $Release -Repository PachaTeam -SourcePath $Source -OutputPath $OutputPath
        }
        Push-Location -Path $work
        try {
            & pwsh -NoProfile -Command $setup -args $repository, (Join-Path $root 'build.ps1'), $source,
                (Join-Path $PSScriptRoot 'solution' 'PachaOps'), (Join-Path $PSScriptRoot 'solution' 'release.ps1'),
                (Join-Path $work 'out') *> (Join-Path $work 'setup.log')
        }
        finally {
            Pop-Location
        }
        if ($LASTEXITCODE -ne 0) {
            $problems.Add("The solution did not run (pwsh exit code $LASTEXITCODE): $((Get-Content -Path (Join-Path $work 'setup.log') -Tail 5) -join ' ')")
        }
    }

    # 1. The repository.
    foreach ($version in $versions) {
        if (-not (Test-Path -Path (Join-Path $repository "PachaOps.$version.nupkg"))) {
            $problems.Add("$repository has no PachaOps $version. Publish it: ./build.ps1 -Repository PachaTeam")
        }
    }

    # 2. What the workstation has installed.
    $listPath = Join-Path $work 'installed.json'
    & pwsh -NoProfile -Command $lister -args $listPath *> $null
    $installed = @(if (Test-Path -Path $listPath) { Get-Content -Path $listPath -Raw | ConvertFrom-Json })
    foreach ($version in $versions) {
        if ($version -notin $installed) {
            $problems.Add("PachaOps $version is not installed on this workstation (installed: $(if ($installed) { $installed -join ', ' } else { 'none' })). Install-PSResource, then Update-PSResource, with -SkipDependencyCheck.")
        }
    }

    # 3. Each version, then Import-Module without a version, each in its own process.
    $inventory = Join-Path $work 'instances.csv'
    Set-Content -Path $inventory -Value 'Name,SqlInstance', 'sql1,"sql1.pachadata.example,1433"', 'compta01,"compta01.pachadata.example,1433"'
    $runs = [ordered]@{}
    if ($installed -contains '0.2.0' -and $installed -contains '0.2.1') {
        foreach ($version in $versions + '') {
            $resultPath = Join-Path $work "load-$version.json"
            & pwsh -NoProfile -Command $inspector -args $version, $inventory, $resultPath *> $null
            $run = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
            $label = if ($version) { "Import-Module PachaOps -RequiredVersion $version" } else { 'Import-Module PachaOps' }
            if ($run.Error) {
                $problems.Add("$label fails: $($run.Error)")
                continue
            }
            if ($Solution -and -not $run.ModuleBase.StartsWith($workstation)) {
                $problems.Add("$label loads $($run.ModuleBase), outside the temporary workstation.")
            }
            if ($version -and $run.Loaded -ne $version) {
                $problems.Add("$label loads $($run.Loaded).")
            }
            if (-not $version -and $run.Loaded -ne '0.2.1') {
                $problems.Add("$label loads $($run.Loaded), not the newest version, 0.2.1.")
            }
            $runs[$(if ($version) { $version } else { 'newest' })] = $run
        }
    }

    if ($runs.Contains('0.2.0') -and $runs.Contains('0.2.1')) {
        $old = $runs['0.2.0']
        $new = $runs['0.2.1']
        if (@($old.Report).Count -ne 3 -or @($old.Report | Where-Object -Property Status -EQ 'Online').Count -ne 2) {
            $problems.Add("The report of 0.2.0 returned $(@($old.Report).Count) row(s) instead of 3 with the replaced dbatools commands: the check cannot compare the versions.")
        }
        if ($old.HostLines -eq 0) {
            $problems.Add('The installed 0.2.0 writes nothing with Write-Host: it is not the 0.2.0 of the course. Was 0.2.0 published again with the correction? A published version does not change.')
        }

        # 4. The release notes and the changelog.
        if ([string]::IsNullOrWhiteSpace($new.ReleaseNotes)) {
            $problems.Add('0.2.1 has no release notes: ReleaseNotes in PrivateData.PSData of the manifest (Update-PSModuleManifest -ReleaseNotes).')
        }
        elseif ($new.ReleaseNotes -eq $old.ReleaseNotes) {
            $problems.Add('The release notes of 0.2.1 are those of 0.2.0: say what 0.2.1 changes.')
        }
        $changelog = Join-Path $new.ModuleBase 'CHANGELOG.md'
        if (-not (Test-Path -Path $changelog)) {
            $problems.Add("0.2.1 has no CHANGELOG.md ($($new.ModuleBase)).")
        }
        elseif (-not (Select-String -Path $changelog -Pattern '^#+\s+0\.2\.1\b' -Quiet)) {
            $problems.Add('The CHANGELOG.md of 0.2.1 has no heading for 0.2.1 (## 0.2.1).')
        }

        # 5. The files of the package.
        $allowed = 'PachaOps.psd1', 'PachaOps.psm1', 'CHANGELOG.md', 'PSGetModuleInfo.xml'
        foreach ($file in Get-ChildItem -Path $new.ModuleBase -Recurse -File) {
            $relative = [System.IO.Path]::GetRelativePath($new.ModuleBase, $file.FullName) -replace '\\', '/'
            $isFunction = $relative -like 'Public/*.ps1' -and $relative -notlike '*.Tests.ps1'
            if ($relative -notin $allowed -and -not $isFunction) {
                $problems.Add("0.2.1 contains $relative, which is not part of the module. Publish out/PachaOps, built by ./build.ps1.")
            }
        }

        # 6. The correction.
        if ($new.HostLines -gt 0) {
            $problems.Add("In 0.2.1, Get-MorningReport still writes $($new.HostLines) line(s) with Write-Host.")
        }
        Import-Module -Name PSScriptAnalyzer -RequiredVersion 1.25.0
        foreach ($record in Invoke-ScriptAnalyzer -Path $new.ModuleBase -Recurse -Settings $settings) {
            $problems.Add("In 0.2.1, $($record.ScriptName) line $($record.Line): $($record.RuleName) is reported.")
        }
        foreach ($record in Invoke-ScriptAnalyzer -Path $new.ModuleBase -Recurse -Settings $settings -SuppressedOnly) {
            if ($record.RuleName -in $toCorrect) {
                $problems.Add("In 0.2.1, $($record.RuleName) is suppressed in $($record.ScriptName). The exercise asks you to correct it.")
            }
            elseif (-not ($record.Suppression | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Justification) })) {
                $problems.Add("In 0.2.1, $($record.RuleName) is suppressed without a justification in $($record.ScriptName).")
            }
        }

        # 7. Nothing else changes.
        if (($new.Commands -join ', ') -ne ($old.Commands -join ', ')) {
            $problems.Add("0.2.1 exports $($new.Commands -join ', ') instead of $($old.Commands -join ', ').")
        }
        if (($new.Parameters -join ', ') -ne ($old.Parameters -join ', ')) {
            $problems.Add("The parameters of Get-MorningReport changed: $($new.Parameters -join ', ') instead of $($old.Parameters -join ', ').")
        }
        if (($new.Report | ConvertTo-Json -Depth 3 -Compress) -ne ($old.Report | ConvertTo-Json -Depth 3 -Compress)) {
            $problems.Add('Get-MorningReport 0.2.1 does not return the same objects as 0.2.0. A patch version changes no result.')
        }
    }
}
finally {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name])
    }
    Remove-Item -Path $work -Recurse -Force
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { "FAIL  $_" }
    exit 1
}
'OK    module 4: 0.2.0 and 0.2.1 installed side by side, 0.2.1 corrected, with its release notes.'
exit 0
