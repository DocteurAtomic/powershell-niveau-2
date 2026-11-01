# Exercice du module 7, la vérification des sauvegardes en parallèle

`Get-BackupCheck` vérifie les sauvegardes de l'inventaire une instance après l'autre : pour
chaque base, la dernière sauvegarde complète, le dernier journal, et un état (`Ok`, `Late`,
`Missing`), plus une ligne `Unreachable` par instance qui ne répond pas. Sur le labo, elle met
une minute, presque toute à attendre les quatre instances `.example`. Écrivez
`Get-BackupCheckParallel`, qui rend les mêmes objets en vérifiant trois instances à la fois.

## Les fichiers

- `Get-BackupCheck.ps1` : la version séquentielle, la référence. Ne la modifiez pas.
- `Get-BackupCheckParallel.ps1` : le fichier de départ, une copie de la référence sous un autre
  nom, avec un paramètre `-ThrottleLimit` qui ne sert encore à rien.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

1. `Get-BackupCheckParallel` garde les paramètres de la référence, plus `[int] $ThrottleLimit`,
   qui vaut 3 par défaut.
2. Elle vérifie les instances de l'inventaire avec `ForEach-Object -Parallel`, trois à la fois.
3. Elle rend les mêmes objets que `Get-BackupCheck`, dans n'importe quel ordre : mêmes
   propriétés, mêmes valeurs.
4. L'identifiant arrive par le paramètre `-SqlCredential` : il passe dans les runspaces par
   `$using:`, jamais par un `Get-Secret` dans la boucle. dbatools s'importe une fois, avant la
   boucle.

Le piège du module : une variable ou un paramètre de la fonction qui n'est pas lu par `$using:`
est vide dans le runspace, et `Connect-DbaInstance` y part sans identifiant.

Pour essayer à la main, depuis la racine du clone :

```powershell
Set-DbatoolsInsecureConnection -SessionOnly | Out-Null
. ./exercises/module_07/Get-BackupCheckParallel.ps1
$credential = Get-Secret -Vault PachaOps -Name sql-lab
Measure-Command { $rows = Get-BackupCheckParallel -InventoryPath data/instances.csv -SqlCredential $credential }
$rows | Sort-Object -Property Instance, Database | Format-Table
```

Pour une mesure qui compte, prenez un `pwsh` neuf : une session a déjà chargé dbatools et
ouvert ses connexions, et une mesure de la version parallèle du module, faite juste après trois
passages de la version séquentielle dans la même session, est sortie une fois à 14,8 secondes
au lieu de 30.

## Le critère

Depuis la racine du clone, le labo démarré :

```powershell
./exercises/module_07/check.ps1
```

Le contrôle lance la référence puis votre fonction, chacune dans un `pwsh` neuf, et compare
leurs objets après les avoir triés par instance et par base. Il ne compare pas une durée à un
nombre de secondes, qui dépend de la machine : il compare votre durée à celle de la référence
mesurée dans le même passage. Les quatre instances `.example` attendent chacune leur délai de
connexion ; l'une après l'autre, cela fait quatre attentes, trois à la fois deux vagues, quatre
ou plus à la fois une seule. Au-dessus de 80 % de la durée de la référence, la fonction ne
tourne pas en parallèle ; au-dessous de 40 %, elle vérifie plus de trois instances à la fois.
Le contrôle prend environ une minute et demie. Il rend 0 et une ligne `OK` quand tout est
juste, 1 sinon. Sur le départ :

```text
Running Get-BackupCheck, the reference, one instance after the other...
Running Get-BackupCheckParallel...
FAIL  Get-BackupCheckParallel does not run in parallel: 58.9 s against 59.2 s for the reference, 99%.
```

`./exercises/module_07/check.ps1 -Solution` vérifie le corrigé.

## À réfléchir

- Le corrigé calcule la date limite des sept jours une fois, avant la boucle. Que se
  passerait-il si chaque runspace la calculait de son côté, sur une vérification qui tourne à
  minuit ?
- Avec `-ThrottleLimit 6`, la vérification du labo descend vers 15 secondes. Pourquoi l'équipe
  garde-t-elle trois sur un parc de trente instances réelles, qui répondent toutes ?
- `Start-Job` donnerait le même résultat, sans limite. Qu'est-ce que chaque tâche devrait
  refaire, que la boucle parallèle fait une seule fois ?
