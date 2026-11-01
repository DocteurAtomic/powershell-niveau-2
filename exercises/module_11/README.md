# Exercice du module 11, la vue des déploiements

Le matin, l'équipe veut lire sur chaque instance combien de scripts y ont été appliqués, et le
dernier : son nom, quand, par qui. C'est une vue sur le journal des déploiements, et elle se
déploie comme tout script de l'équipe : par `Deploy-PachaScript`, sur l'instance de test
d'abord, puis sur la production. Le script de déploiement qu'un collègue a écrit déploie tout
d'un coup, sans `-WhatIf`.

## Les fichiers

- `scripts/0001-deployment-journal.sql` : le journal, le même que celui de la démonstration. Ne
  le modifiez pas : un script appliqué ne change plus.
- `scripts/0002-deployment-summary.sql` : la vue, à écrire.
- `deploy.ps1` : le script de déploiement, à réécrire. Il charge `Deploy-PachaScript` depuis
  `demos/module_11`.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

1. Dans `0002-deployment-summary.sql`, la vue `dbo.DeploymentSummary` : une seule ligne, avec
   `ScriptCount` (le nombre de scripts du journal), `LastScript`, `LastAppliedAt` et
   `LastAppliedBy` (le dernier script appliqué, par `AppliedAt`, puis par nom quand deux scripts
   ont la même heure). Le script ne nomme pas sa base : pas de `USE`. C'est la fonction qui la
   choisit.
2. `deploy.ps1` déploie d'abord les instances de `-TestInstance`, puis celles de
   `-ProductionInstance`, dans cet ordre.
3. Quand une instance de test rend autre chose qu'`Applied` ou `AlreadyApplied`, la
   production n'est pas déployée, et le script lève une erreur qui nomme l'instance.
4. `deploy.ps1 -WhatIf` dit ce qui serait appliqué, sur toutes les instances, et n'applique
   rien.
5. Il rend les objets de `Deploy-PachaScript`.

Pour essayer, depuis la racine du clone, d'abord sans rien appliquer :

```powershell
./exercises/module_11/deploy.ps1 -WhatIf
./exercises/module_11/deploy.ps1
./demos/module_11/07-journal.ps1
```

Si vous avez joué les démonstrations, `0001-deployment-journal.sql` est déjà dans le journal de
`DBA` des deux instances : il en sort `AlreadyApplied`, parce qu'il est identique à celui de
`demos/module_11/scripts`.

## Le critère

Depuis la racine du clone, le labo démarré :

```powershell
./exercises/module_11/check.ps1
```

Le contrôle crée la base `m11_check` sur les deux instances et y déploie, pour ne pas toucher
`DBA`. Il lance `deploy.ps1` quatre fois, chaque fois dans un `pwsh` neuf :

| Passage | Attendu |
|---|---|
| `-WhatIf` | le script accepte `-WhatIf`, dit qu'il appliquerait `0002-deployment-summary.sql` sur les deux instances, et n'écrit rien |
| le déploiement | les deux scripts appliqués sur les deux instances, `localhost,14534` avant `localhost,14533` ; la vue rend deux scripts et `0002-deployment-summary.sql` comme dernier |
| le même, relancé | rien d'appliqué, aucune erreur, deux lignes dans chaque journal |
| `-TestInstance recette01.pachadata.example,1433`, base `m11_check_stop` | une erreur qui nomme l'instance de test, et rien sur la production |

Il supprime `m11_check` et `m11_check_stop` à la fin, prend une quarantaine de secondes, dont
une quinzaine à attendre l'instance injoignable, et rend 0 et une ligne `OK` quand tout est
juste, 1 sinon. Sur le départ, il commence par :

```text
FAIL  deploy.ps1 does not accept -WhatIf: [CmdletBinding(SupportsShouldProcess)].
FAIL  m11_check on localhost,14534 has no view dbo.DeploymentSummary: does the script create it without naming a database (no USE)?
```

`./exercises/module_11/check.ps1 -Solution` vérifie le corrigé.

## À réfléchir

- `-WhatIf` sur `deploy.ps1` atteint `Deploy-PachaScript` sans que vous le lui passiez. Pourquoi ?
  Le ferait-il si la fonction venait d'un module importé ?
- La vue est appliquée sur la production quelques secondes après le test. Combien de temps
  attendriez-vous entre les deux pour un script qui change une table de 50 millions de lignes,
  et qu'est-ce qui le dirait au script ?
- Une erreur dans la vue, trouvée une semaine plus tard. Vous ne modifiez pas
  `0002-deployment-summary.sql` : qu'écrivez-vous à la place ?
