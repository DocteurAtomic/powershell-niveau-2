# Exercice du module 2, les tests de Get-ErrorLogSummary

Écrivez, en Pester 6, les tests de `Get-ErrorLogSummary`, la fonction de `PachaOps` qui lit
les journaux d'erreurs de SQL Server d'un dossier et rend un objet par fichier (`File`,
`Lines`, `Matches`, `First`, `Last`). Vos tests doivent passer sur la fonction qui marche, et
tomber sur des versions cassées.

## Les fichiers

- `Get-ErrorLogSummary.Tests.ps1` : le fichier de départ, quatre tests vides à écrire. Gardez
  son bloc `param()` : `check.ps1` y passe le chemin d'une autre copie de la fonction
  (`$ModulePath`) et celui des journaux (`$ErrorLogPath`).
- `versions/correct.ps1` : la fonction de `PachaOps` 0.1.0, sur laquelle vos tests doivent
  passer.
- `versions/broken-*.ps1` : quatre copies cassées, sur lesquelles au moins un de vos tests
  doit tomber.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

1. La fonction rend un objet par fichier de `data/errorlog/`, et un seul.
2. Elle compte les lignes et les lignes qui contiennent `Login failed`, pour chaque fichier.
   Les valeurs attendues se lisent dans les journaux, pas dans un premier appel à la fonction.
3. Pour un dossier qui contient un fichier vide, elle rend `Lines` 0 et `Matches` 0, sans
   erreur. Fabriquez ce dossier dans `TestDrive:`.
4. Elle lève une erreur quand le dossier n'existe pas.

## Le contrôle

Depuis la racine du clone :

    Invoke-Pester -Path exercises/module_02/Get-ErrorLogSummary.Tests.ps1 -Output Detailed
    ./exercises/module_02/check.ps1

`check.ps1` lance vos tests cinq fois, chacune dans un processus `pwsh` à part avec
Pester 6.2.0, et lit leur objet de résultat. Il rend 0 quand ils passent sur
`versions/correct.ps1` et tombent sur chacune des quatre versions cassées, 1 sinon, avec une
ligne `FAIL` par version que vos tests laissent passer. `check.ps1 -Solution` vérifie le
corrigé.

---

# Exercise of module 2, the tests of Get-ErrorLogSummary

Write, in Pester 6, the tests of `Get-ErrorLogSummary`: one object per file of
`data/errorlog/`, the count of lines and of `Login failed` lines per file, `Lines` 0 and
`Matches` 0 for an empty file, an error when the folder does not exist. Keep the `param()`
block of `Get-ErrorLogSummary.Tests.ps1`. `./exercises/module_02/check.ps1` runs your tests
against the working version (they must pass) and against four broken copies (each must make
at least one test fail), and exits with 0 when all five runs are right.
