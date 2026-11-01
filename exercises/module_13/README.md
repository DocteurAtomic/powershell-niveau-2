# Exercice du module 13

Objectif : dire chaque matin, par un objet et un code de sortie, si la tâche du soir a prouvé ce
qu'elle devait prouver.

La tâche du soir (`demos/module_13/nightly.ps1`) laisse une trace (`lab/nightly/nightly.jsonl`,
une ligne par exécution) et, dans le dossier de chaque exécution, un `summary.json`. Le script
d'un collègue, `Test-NightlyRun.ps1`, lit la dernière ligne de la trace et écrit `Nightly OK`
quand son code de sortie vaut 0. Une nuit au code 0 peut pourtant ne rien prouver : une
trace d'il y a trois jours, un contrôle à zéro test joué, une version annoncée publiée
que le dépôt de l'équipe n'a pas.

## Avant de commencer

Lancez la tâche une fois à la main, depuis la racine du clone, le labo démarré :

```powershell
./demos/module_13/01-setup.ps1
pwsh -NoProfile -NonInteractive -File demos/module_13/nightly.ps1
```

Relisez `lab/nightly/nightly.jsonl` et le `summary.json` du dossier qu'elle a écrit : c'est ce que
votre script lit.

## Les consignes

1. `exercises/module_13/Test-NightlyRun.ps1` accepte `-ResultPath` (par défaut le `lab/nightly` du
   clone), `-Repository` (par défaut `PachaTeam`) et `-MaxAgeHours` (par défaut 26).
2. Il rend un seul objet, avec `Time` (l'heure de la dernière exécution), `Folder`, `Version`,
   `Verdict` (`OK` ou `FAILED`) et `Problems` (les raisons d'un `FAILED`, vide sinon).
3. Le verdict est `FAILED` quand : il n'y a pas de trace ; la dernière exécution a plus de
   `-MaxAgeHours` heures ; son code de sortie n'est pas 0 ; les tests n'ont joué aucun test ou
   l'un d'eux a échoué ; aucun contrôle n'a tourné, ou un contrôle n'a joué aucun test ; la
   version du résumé n'est pas dans le dépôt `-Repository`.
4. Il sort avec le code 1 quand le verdict est `FAILED`, et ne lève pas d'erreur : un contrôle
   du matin dit que la nuit a échoué, il n'échoue pas lui-même.
5. Pas de `Write-Host`.

## Le critère

Depuis la racine du clone (aucune instance n'est nécessaire) :

```powershell
./exercises/module_13/check.ps1
```

Le contrôle fabrique six nuits dans un dossier temporaire, au format de `nightly.ps1`, et un dépôt
à lui, `m13_check`, où `build.ps1` publie `PachaOps` 0.2.0. Il lance votre script une fois par
nuit, chaque fois dans un `pwsh` neuf :

| Nuit | Attendu |
|---|---|
| une bonne nuit, il y a une heure | `OK`, code 0 |
| la même, il y a trois jours | `FAILED`, code 1 |
| deux tests échoués, rien publié | `FAILED`, code 1 |
| code 0, mais dbachecks n'a joué aucun test | `FAILED`, code 1 |
| code 0, mais la 0.2.1 annoncée n'est pas dans le dépôt | `FAILED`, code 1 |
| aucune trace | `FAILED`, code 1 |

Chaque `FAILED` doit avoir au moins une raison dans `Problems`. Le contrôle retire `m13_check` et
son dossier dans un `finally`, prend quelques secondes, et rend 0 et une ligne `OK` quand tout est
juste, 1 sinon. `./exercises/module_13/check.ps1 -Solution` vérifie le corrigé.

## À réfléchir

- Le contrôle de `dbachecks` a joué zéro test et la tâche est sortie avec le code 0. Où faut-il
  le voir : dans la tâche du soir, dans le contrôle du matin, ou dans les deux ?
- `-MaxAgeHours` vaut 26 et non 24. Pourquoi laisser cette marge à une tâche qui démarre chaque
  soir à la même heure ?
- Qui lance ce script le matin, et qui lit son code de sortie ?
