# Exercice du module 3, les tests de Remove-OldBackup

Écrivez, en Pester 6, les tests de `Remove-OldBackup`, la fonction de rétention de
`PachaOps`, en remplaçant `Remove-Item` par un mock : vos tests disent ce que la fonction
supprimerait, sans rien supprimer. Ils doivent passer sur la fonction qui marche, et tomber
sur des versions cassées.

## Les fichiers

- `Remove-OldBackup.Tests.ps1` : le fichier de départ, quatre tests vides à écrire. Gardez son
  bloc `param()` : `check.ps1` y passe le chemin d'une autre copie de la fonction
  (`$ModulePath`).
- `versions/correct.ps1` : la fonction de `PachaOps`, sur laquelle vos tests doivent passer.
- `versions/broken-*.ps1` : trois copies cassées, sur lesquelles au moins un de vos tests doit
  tomber.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

Créez les fichiers de sauvegarde dans `TestDrive:` seulement, jamais dans `lab/backups`, et
fixez leur date (`LastWriteTimeUtc`) à partir d'une date de référence que vous passez à
`-ReferenceDate`. Un mock de `Remove-Item` doit être injecté dans le module :
`Mock Remove-Item -ModuleName PachaOps`.

1. Avec une rétention de 14 jours, la fonction appelle `Remove-Item` pour chaque fichier `.bak`
   et `.trn` plus vieux que la rétention.
2. Elle ne l'appelle ni pour une sauvegarde récente, ni pour un fichier qui n'est pas une
   sauvegarde (un `.txt`, même vieux).
3. Elle rend les fichiers qu'elle a supprimés.
4. Avec `-WhatIf`, elle n'appelle pas `Remove-Item` et ne rend rien.

## Le contrôle

Depuis la racine du clone :

    Invoke-Pester -Path exercises/module_03/Remove-OldBackup.Tests.ps1 -Output Detailed
    ./exercises/module_03/check.ps1

`check.ps1` copie votre fichier de tests dans un dossier temporaire et le lance quatre fois
depuis là, chacune dans un processus `pwsh` à part avec Pester 6.2.0, et lit son objet de
résultat. Il rend 0 quand vos tests passent sur `versions/correct.ps1` et tombent sur chacune
des trois versions cassées, 1 sinon, avec une ligne `FAIL` par version que vos tests laissent
passer. `check.ps1 -Solution` vérifie le corrigé.

Lancé par `check.ps1`, un test qui oublie `-ModuleName` ne supprime rien dans votre clone.
Lancé directement par `Invoke-Pester`, il supprime de vrais fichiers : dans `TestDrive:` si
vous avez suivi la consigne, dans `lab/backups` sinon. `./setup/new-backupfiles.ps1` refait
les fichiers de `lab/backups`.

---

# Exercise of module 3, the tests of Remove-OldBackup

Write, in Pester 6, the tests of `Remove-OldBackup` with `Remove-Item` mocked in the module
(`Mock Remove-Item -ModuleName PachaOps`), on files created in `TestDrive:` only: the old
`.bak` and `.trn` files are removed, a recent backup and a file that is not a backup are
kept, the removed files are returned, and nothing is removed with `-WhatIf`. Keep the
`param()` block of `Remove-OldBackup.Tests.ps1`. `./exercises/module_03/check.ps1` copies your
test file to a temporary folder and runs it against the working version (the tests must
pass) and against three broken copies (each must make at least one test fail), and exits
with 0 when all four runs are right.
