# Exercice du module 10, l'audit des instances

L'audit veut aussi la preuve que les instances respectent d'autres règles de l'équipe :

1. La connexion administrateur dédiée (DAC) n'est pas ouverte aux connexions distantes.
2. DBCC CHECKDB a réussi depuis moins de sept jours sur toutes les bases, sauf `tempdb`.

dbachecks sait vérifier la première, avec sa vérification `DAC`, à condition de lui donner la
valeur de l'équipe. Il ne lance pas la seconde sous Pester 5 : `LastGoodCheckDb` fait partie
des vérifications qu'il laisse de côté (`dbachecks.checks.notv5ready`). Vous l'écrivez en
Pester 6, comme l'équipe a écrit la règle des sauvegardes au clip 10.4.

Le lanceur joue aussi la vérification `InstanceConnection`, qui teste la connexion à chaque
instance. Depuis un poste Linux, deux de ses tests tombent pour une raison qui n'a rien
à voir avec l'instance (clip 10.3) : dbachecks ne fait de ping que sous Windows, et teste le
remoting par WinRM. Et son test du schéma d'authentification attend Kerberos, alors que le labo
se connecte par un compte SQL.

## Les fichiers

- `pachadata-instance.dbachecks.json` : la configuration de l'équipe pour dbachecks, à écrire.
  Au départ, un tableau vide.
- `LastGoodCheckDb.Tests.ps1` : la règle CHECKDB en Pester 6, à écrire. Ses paramètres sont
  déjà là.
- `run-audit.ps1` : le lanceur, à ne pas modifier. Il lance dbachecks (Pester 5.9.1) avec votre
  configuration, sur les vérifications `InstanceConnection` et `DAC`, puis votre fichier de
  tests (Pester 6.2.0), chacun dans son propre processus, par les deux scripts de
  `demos/module_10`, et écrit le rapport HTML dans `lab/reports/`.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

1. Dans `pachadata-instance.dbachecks.json`, un tableau d'objets `Name` et `Value`, comme
   `demos/module_10/pachadata.dbachecks.json`, qui règle :
   - la valeur attendue pour la DAC distante (`policy.dacallowed`) ;
   - le schéma d'authentification attendu (`policy.connection.authscheme`) : celui de vos
     connexions au labo ;
   - le ping et le test de remoting, à sauter depuis un poste Linux (`skip.connection.ping`,
     `skip.connection.remoting`).

   `Get-DbcConfig -Name policy.dacallowed, policy.connection.*, skip.connection.*`, dans une
   session Pester 5.9.1, affiche leur valeur par défaut et leur description.
2. Dans `LastGoodCheckDb.Tests.ps1`, un test par base et par instance, pour toutes les bases
   sauf `tempdb`, lues à la découverte par `Get-DbaLastGoodCheckDb`. Le test passe quand la
   dernière vérification réussie date de moins de `$MaxAgeDays` jours, et tombe quand elle est
   plus ancienne ou qu'il n'y en a jamais eu. Le nom du test contient le nom de la base et celui
   de l'instance tel qu'il est passé (`localhost,14534`), par exemple
   `Database <Database> has a good CHECKDB of less than <MaxAgeDays> days on <Instance>`.
3. Une instance injoignable fait tomber le fichier, au lieu de disparaître du rapport.

Pour essayer, depuis la racine du clone :

```powershell
./exercises/module_10/run-audit.ps1
```

Sur le labo, la règle CHECKDB tombe sur presque toutes les bases : personne n'y a jamais lancé
DBCC CHECKDB, et celle de `PachadataTraining` date du jour de la sauvegarde d'où elle vient.
Ces échecs sont le constat de l'audit, et votre test a raison de les rendre.

## Le critère

Depuis la racine du clone, le labo démarré :

```powershell
./exercises/module_10/check.ps1
```

Le contrôle crée la base `m10_checked` sur `localhost,14534` et y lance DBCC CHECKDB, pour
qu'une base au moins ait une vérification du jour. Puis il lance `run-audit.ps1` avec vos deux
fichiers et lit le fichier JSON que le lanceur écrit, pas sa sortie :

- dbachecks a joué des tests, aucun n'est tombé, le test de la DAC passe avec la valeur `False`
  sur les deux instances, celui de l'authentification avec `SQL`, et le ping et le remoting
  sont sautés (`Skipped`) ;
- votre règle a joué des tests sur les deux instances : elle passe sur `m10_checked`, tombe
  sur les bases dont la dernière vérification manque ou date de plus de sept jours, et ne teste
  pas `tempdb` ;
- le rapport HTML contient les deux parties.

Il supprime `m10_checked` à la fin, prend une vingtaine de secondes, et rend 0 et une ligne
`OK` quand tout est juste, 1 sinon. Sur le départ, il commence par :

```text
FAIL  On localhost,14533, the DAC test does not pass with the value False: DAC is set to True on localhost,14533. Set policy.dacallowed.
FAIL  On localhost,14533, the authentication test does not pass with SQL: auth scheme should be Kerberos on localhost,14533. Set policy.connection.authscheme.
```

et finit par :

```text
FAIL  Your test file ran no test: one test per database is expected (It with -ForEach).
FAIL  The HTML report does not hold both parts, dbachecks and your rule.
```

`./exercises/module_10/check.ps1 -Solution` vérifie le corrigé.

## À réfléchir

- Le contrôle dit « aucun test de dbachecks n'est tombé », alors que le rapport de la démonstration
  en contenait un. Qu'est-ce qui distingue un test sauté (`Skipped`) d'une règle que l'équipe a
  décidé de ne pas appliquer ? Où l'écririez-vous, pour l'auditeur ?
- `Get-DbaLastGoodCheckDb` rend l'heure du serveur. Si le serveur est en UTC et votre poste à
  Paris, de combien votre règle peut-elle se tromper, et dans quel sens ?
- Lancer DBCC CHECKDB sur toutes les bases pour faire passer la règle prend du temps et des
  ressources. Quand la lanceriez-vous sur une instance de production, et par quoi ?
