# Exercice du module 6, le type d'un fichier de sauvegarde

Écrivez dans `BackupFile.psm1` une énumération `BackupType` et une classe `BackupFile` : un
objet par fichier de sauvegarde de l'équipe, qui dit son type sans qu'on relise son nom, et
qui sait dire s'il est plus vieux qu'un nombre de jours.

## Les fichiers

- `BackupFile.psm1` : le fichier de départ, une énumération à un seul nom et une classe à une
  seule propriété.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

1. `BackupType` a trois noms : `Full`, `Differential` et `Log`.
2. `BackupFile` a au moins ces propriétés, typées : `FullName` et `Database` en `[string]`,
   `Type` en `[BackupType]`, `Length` en `[long]`, `LastWriteTimeUtc` en `[datetime]`.
3. Son constructeur prend un `[System.IO.FileInfo]`, celui que rend `Get-ChildItem`. Il lit le
   type et la base dans le nom du fichier, que la Maintenance Solution écrit
   `instance_base_TYPE_date_heure.extension` (`sql1_Planning_DIFF_20261030_010000.bak`) :
   `FULL`, `DIFF` ou `LOG`. L'extension ne suffit pas, une sauvegarde complète et une
   différentielle sont toutes deux en `.bak`. Un fichier dont le nom n'a pas cette forme
   (`README-restore.txt`) fait lever une erreur au constructeur.
4. Une méthode `IsOlderThan([int] $days, [datetime] $referenceDate)` rend `[bool]` : vrai quand
   le fichier a été écrit plus de `$days` jours avant la date de référence. Cette date peut
   arriver en heure locale (`Get-Date`, `'2026-11-02'`) : comparez des instants UTC, comme
   `Get-BackupAge` depuis la 0.2.0 (module 2).

Une méthode n'a pas de valeur par défaut pour ses paramètres : une seconde surcharge
`IsOlderThan([int] $days)`, qui prend `Get-Date`, est permise et n'est pas contrôlée.

Essayez votre classe dans un `pwsh` neuf après chaque modification : une session qui l'a déjà
chargée garde l'ancienne (vidéo 6.2).

    pwsh -NoProfile
    using module ./exercises/module_06/BackupFile.psm1
    Get-ChildItem -Path lab/backups -Recurse -Include *.bak, *.trn | ForEach-Object { [BackupFile]::new($_) }

## Le contrôle

Depuis la racine du clone :

    ./exercises/module_06/check.ps1

`check.ps1` charge votre module par `using module` dans un processus `pwsh` à part, pour
qu'une version précédente de la classe, restée dans votre session, ne compte pas. Il contrôle
les noms de l'énumération, le type des propriétés, les objets construits sur trois fichiers
fabriqués (une complète, une différentielle, un journal), l'erreur sur un fichier qui n'est
pas une sauvegarde, une valeur refusée par `Type`, et `IsOlderThan(7, date)` sur des fichiers
écrits à 6 jours, à 7 jours moins et plus 30 minutes, et à 8 jours d'une date de référence
donnée en UTC puis en heure locale. Sous Linux et macOS, il joue ces derniers contrôles deux
fois, à Paris et à New York (variable `TZ`) : un mélange d'heure locale et d'UTC tombe sur
toute machine. Sous Windows, il les joue dans le fuseau du poste, et le dit si c'est l'UTC. Il
rend 0 et une ligne `OK` quand tout est juste, 1 sinon, avec une ligne `FAIL` par défaut
trouvé. `check.ps1 -Solution` vérifie le corrigé.

---

# Exercise of module 6, the type of a backup file

Write in `BackupFile.psm1` an enumeration `BackupType` (`Full`, `Differential`, `Log`) and a
class `BackupFile` with typed properties (`FullName` and `Database` as `[string]`, `Type` as
`[BackupType]`, `Length` as `[long]`, `LastWriteTimeUtc` as `[datetime]`), a constructor that
takes a `[System.IO.FileInfo]`, reads the type and the database in the name of the file
(`instance_database_TYPE_date_time.ext`, the naming of the Maintenance Solution) and throws on
a file that is not a backup, and a method `IsOlderThan([int] $days, [datetime] $referenceDate)`
that returns `[bool]` and compares UTC instants. `./exercises/module_06/check.ps1` loads your
module with `using module` in a separate pwsh, checks the objects it builds, and exits with 0
when everything is right.
