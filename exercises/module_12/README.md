# Exercice du module 12, les options des bases

L'équipe a des règles pour les bases de ses instances : la vérification des pages par somme de
contrôle (`CHECKSUM`), ni fermeture ni réduction automatique, les statistiques créées et mises
à jour automatiquement. Elles sont écrites dans `pachadata-database.json`. Un collègue a écrit
un script qui les contrôle sur `sql2` : il ne lit qu'une option, écrit du texte que rien d'autre
ne peut lire, et regarde aussi les bases système.

## Les fichiers

- `pachadata-database.json` : les règles de l'équipe. `ExcludeDatabase`, les bases laissées de
  côté ; `Options`, chaque option sous le nom de la propriété que rend `Get-DbaDatabase`, avec
  sa valeur attendue.
- `Get-DatabaseDrift.ps1` : le script du collègue, à réécrire.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

1. `Get-DatabaseDrift.ps1` accepte `-SqlInstance` (par défaut `localhost,14534`) et
   `-ReferencePath` (par défaut le `pachadata-database.json` de son dossier).
2. Il lit les règles dans le fichier : les bases exclues et les options. Rien n'est écrit en dur
   dans le script.
3. Il rend un objet par base et par option qui s'écarte de la règle, avec `SqlInstance`,
   `Database`, `Option`, `Expected` et `Actual`, et rien quand tout est conforme.
4. Pas de `Write-Host` : la suite (un rapport, un webhook, le pipeline du module 13) lit des
   objets.

Pour essayer, depuis la racine du clone :

```powershell
./exercises/module_12/Get-DatabaseDrift.ps1 | Format-Table
```

Sur le labo dans l'état de l'installation, toutes les bases de `sql2` suivent les règles : le
script ne rend rien. Pour voir un écart, réglez une base à vous, par exemple
`ALTER DATABASE <base> SET AUTO_SHRINK ON;`, puis supprimez-la.

## Le critère

Depuis la racine du clone, le labo démarré :

```powershell
./exercises/module_12/check.ps1
```

Le contrôle crée deux bases sur `sql2` : `m12_check`, conforme, et `m12_check_drift`, où il pose
`AUTO_SHRINK ON` et `PAGE_VERIFY TORN_PAGE_DETECTION`. Il lance votre script trois fois, chaque
fois dans un `pwsh` neuf, avec un fichier de règles qu'il écrit lui-même :

| Passage | Attendu |
|---|---|
| les règles de l'équipe | deux écarts, tous deux sur `m12_check_drift` : `AutoShrink` (`False` attendu, `True` trouvé) et `PageVerify` (`Checksum` attendu, `TornPageDetection` trouvé) ; rien sur `m12_check` ni sur les bases système |
| les mêmes, `m12_check_drift` ajoutée à `ExcludeDatabase` | rien sur `m12_check_drift` |
| la seule règle `PageVerify` | un écart sur `m12_check_drift`, `PageVerify` |

Il supprime les deux bases à la fin, dans un `finally`, même quand un passage échoue. Il prend
une vingtaine de secondes, et rend 0 et une ligne `OK` quand tout est juste, 1 sinon. Sur le
départ :

```text
FAIL  With the rules of the team, Get-DatabaseDrift.ps1 returns no object with SqlInstance, Database, Option, Expected and Actual: Write-Host is text, not an object.
FAIL  With the rule PageVerify alone, the script returns 0 difference(s) on m12_check_drift (): PageVerify alone is expected. Read the options from the file.
```

`./exercises/module_12/check.ps1 -Solution` vérifie le corrigé.

## À réfléchir

- `PageVerify` est une énumération de SMO, la valeur du fichier une chaîne, `AutoShrink` un
  booléen des deux côtés. Comment votre comparaison traite-t-elle les deux cas ?
- Une base a le droit de se réduire automatiquement, par décision de l'équipe. Où l'écrivez-vous,
  pour qu'elle ne sorte plus en écart sans perdre la règle pour les autres bases ?
- Le contrôle du module 10 et ce script vérifient tous deux des règles de l'équipe. Qu'est-ce qui
  fait choisir dbachecks pour l'un et un script à vous pour l'autre ?
