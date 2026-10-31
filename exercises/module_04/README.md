# Exercice du module 4, PachaOps 0.2.1

`Get-MorningReport` est la dernière fonction de `PachaOps` à écrire avec `Write-Host` et à
appeler `ForEach-Object` par son alias `%`. Le module 1 l'a corrigée dans une copie
d'exercice, jamais dans le module. Corrigez-la dans `src/PachaOps`, publiez la version 0.2.1
avec sa note de version, mettez à jour votre poste, qui a 0.2.0, et chargez chaque version
par `-RequiredVersion`.

## Le point de départ

Les vidéos du module ont enregistré le dépôt `PachaTeam` sur `lab/repository`, publié
`PachaOps` 0.2.0 et installé 0.2.0 sur votre poste. Si vous ne les avez pas suivies, ou si
`setup/run-checks.ps1` a lancé `demos/module_04/99-cleanup.ps1`, refaites cet état depuis la
racine du clone :

    ./demos/module_04/02-repository.ps1
    ./demos/module_04/03-install.ps1

## Les consignes

1. Dans `src/PachaOps/Public/Get-MorningReport.ps1`, remplacez `Write-Host` par
   `Write-Verbose` et l'alias `%` par `ForEach-Object`. Ne changez pas les paramètres :
   `-Password` reste, et les deux règles de PSScriptAnalyzer qu'il déclenche se suppriment
   avec `SuppressMessageAttribute` et une justification, comme au module 1. Les tests de
   l'équipe (`Invoke-Pester -Path tests`) doivent rester verts.
2. Passez le manifeste à 0.2.1, avec une note de version qui dit ce que 0.2.1 change
   (`Update-PSModuleManifest -ModuleVersion -ReleaseNotes`), et ajoutez une entrée `## 0.2.1`
   en tête de `src/PachaOps/CHANGELOG.md`. Ce fichier est l'historique du module, installé
   avec lui ; le `CHANGELOG.md` à la racine du dépôt est celui des corrections du cours.
3. Publiez avec `./build.ps1 -Repository PachaTeam`, qui construit `out/PachaOps` et refuse une
   version déjà publiée.
4. Mettez à jour votre poste (`Update-PSResource`, avec `-SkipDependencyCheck`) et chargez
   chaque version par `Import-Module -RequiredVersion`, chacune dans son propre processus
   `pwsh`.

## Le contrôle

Depuis la racine du clone :

    ./exercises/module_04/check.ps1

Il lit `lab/repository` et les modules installés pour votre utilisateur, charge 0.2.0 et 0.2.1
chacune dans un processus `pwsh` à part, et contrôle le résultat : les deux versions publiées
et installées côte à côte, la note de version et l'entrée du `CHANGELOG.md` de 0.2.1, un
paquet qui ne contient que les fichiers du module, aucun `Write-Host` et aucune alerte de
PSScriptAnalyzer dans 0.2.1, les mêmes commandes, les mêmes paramètres et les mêmes objets
que 0.2.0. Le rapport tourne sans SQL Server : les deux commandes de dbatools qu'il appelle sont
remplacées, dans le module, par des fonctions qui rendent des objets fabriqués. Il rend 0 et
une ligne `OK` quand tout est juste, 1 sinon, avec une ligne `FAIL` par point qui manque.

`./exercises/module_04/check.ps1 -Solution` vérifie le corrigé sans toucher à votre poste :
dans un dossier temporaire, il publie la copie figée de 0.2.0 (`reference/PachaOps`) dans un
dépôt temporaire, l'installe sous un `HOME` temporaire, puis joue `solution/release.ps1` sur les
fichiers de `solution/PachaOps` posés sur cette copie. L'isolement passe par `HOME`, que
PowerShell ne lit pas sous Windows pour trouver les modules de l'utilisateur : sous Windows,
`-Solution` refuse de tourner.

## Le corrigé

`solution/PachaOps/` contient les trois fichiers qui changent (le manifeste, le
`CHANGELOG.md` et `Public/Get-MorningReport.ps1`), `solution/release.ps1` les commandes, depuis
la publication jusqu'au chargement de chaque version.

---

# Exercise of module 4, PachaOps 0.2.1

Correct `Get-MorningReport` in `src/PachaOps` (`Write-Verbose` instead of `Write-Host`,
`ForEach-Object` instead of `%`, same parameters, `-Password` included, the team's tests still
green), raise the manifest to 0.2.1 with release notes of its own, add a `## 0.2.1` entry to
`src/PachaOps/CHANGELOG.md`, publish with `./build.ps1 -Repository PachaTeam`, update your
workstation, which has 0.2.0, with `Update-PSResource -SkipDependencyCheck`, and load each
version with `Import-Module -RequiredVersion`. `./exercises/module_04/check.ps1` reads
`lab/repository` and your installed modules and exits with 0 when both versions are there and
0.2.1 is right; `-Solution` checks the solution in a temporary HOME (Linux and macOS only).
