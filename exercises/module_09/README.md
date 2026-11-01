# Exercice du module 9, l'alerte des sauvegardes

`Send-BackupAlert` envoie au webhook de l'équipe les problèmes d'une vérification des
sauvegardes, celle du module 7 : une ligne par base `Late` ou `Missing`, une ligne par instance
`Unreachable`, rien pour une base `Ok`. Elle confie les nouvelles tentatives à
`Invoke-RestMethod -MaximumRetryCount`, qui renvoie le message sur tout code de 400 à 599 : un
message refusé (400) arrive trois fois au serveur, et la fonction ne dit pas combien de requêtes
elle a envoyées. Réécrivez l'envoi pour qu'elle ne renvoie que ce qui a une chance de passer.

## Les fichiers

- `Send-BackupAlert.ps1` : le fichier de départ, à modifier. La construction du message est
  déjà écrite ; c'est l'envoi qui change.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

1. `Send-BackupAlert` garde ses paramètres : `-Uri`, `-BackupCheck` (les lignes de la
   vérification), `-MaximumAttempt` (le nombre de requêtes au plus, la première comprise, 3 par
   défaut) et `-RetryIntervalSec` (l'attente entre deux requêtes, 1 seconde par défaut).
2. Elle renvoie le message quand le serveur répond 429 (trop de requêtes) ou un code de 500 à
   599, au plus `-MaximumAttempt` requêtes en tout, en attendant `-RetryIntervalSec` secondes
   entre deux requêtes.
3. Sur tout autre code d'erreur, elle n'envoie le message qu'une fois.
4. Quand le message passe, elle rend un objet avec `StatusCode` (le code reçu) et `Attempts` (le
   nombre de requêtes envoyées).
5. Quand il ne passe pas, elle lève une erreur qui indique le dernier code reçu.

Deux paramètres d'`Invoke-RestMethod` font l'essentiel : `-SkipHttpErrorCheck`, sans lequel un
code d'erreur lève une exception, et `-StatusCodeVariable`, qui ne reçoit le code d'une erreur
qu'avec lui.

Pour essayer à la main, depuis la racine du clone :

```powershell
. ./exercises/module_09/Send-BackupAlert.ps1
$rows = @(
    [pscustomobject]@{ Instance = 'sql1'; Database = 'Finance'; Status = 'Late' }
    [pscustomobject]@{ Instance = 'sql1'; Database = 'Planning'; Status = 'Ok' }
    [pscustomobject]@{ Instance = 'compta01'; Database = $null; Status = 'Unreachable' }
)
Send-BackupAlert -Uri http://localhost:14580/flaky -BackupCheck $rows
Send-BackupAlert -Uri http://localhost:14580/status/400 -BackupCheck $rows
Get-Content -Path lab/webhook/received.jsonl -Tail 4 | ConvertFrom-Json | Format-Table -Property time, path, status
```

`/flaky` répond 503, 503, puis 200, et son compteur est partagé par tous ceux qui l'appellent :
si votre premier essai passe du premier coup, un essai précédent s'est arrêté en route. Le
contrôle le remet au début d'un cycle avant de s'en servir.

## Le critère

Depuis la racine du clone, le labo démarré :

```powershell
./exercises/module_09/check.ps1
```

Le contrôle lance votre fonction dans un `pwsh` neuf sur quatre routes du serveur de test, puis
lit ce que le serveur a reçu dans `lab/webhook/received.jsonl` :

| Route | Ce que le serveur répond | Ce qui est attendu |
|---|---|---|
| `/flaky` | 503, 503, puis 200 | trois requêtes, un objet `StatusCode` 200, `Attempts` 3 |
| `/status/400` | 400 | une seule requête, une erreur qui dit 400 |
| `/status/503` | 503 | `-MaximumAttempt 2` : deux requêtes, une erreur qui dit 503 |
| `/status/429` | 429 | `-MaximumAttempt 2` : deux requêtes, une erreur qui dit 429 |

Il vérifie aussi le message (une ligne par problème, aucune pour une base `Ok`) et l'attente
entre deux requêtes, d'environ une seconde. Les noms d'instance des lignes qu'il envoie contiennent une
marque propre à son passage, pour qu'il ne compte que ses requêtes. Il prend une dizaine de
secondes, et rend 0 et une ligne `OK` quand tout est juste, 1 sinon. Sur le départ :

```text
FAIL  On /flaky, Send-BackupAlert returns nothing; one object with StatusCode 200 and Attempts 3 is expected.
FAIL  On /status/400, the server received the same message 3 times; a refused message is sent once.
```

`./exercises/module_09/check.ps1 -Solution` vérifie le corrigé.

## À réfléchir

- Le serveur répond 503 après avoir posté le message dans le canal, puis 200 à la deuxième
  requête. Qu'aura vu l'équipe ? Qu'est-ce qui, côté serveur, permettrait de reconnaître une
  requête déjà reçue ?
- Avec `-MaximumAttempt 5` et `-RetryIntervalSec 30`, combien de temps la fonction peut-elle
  attendre avant de rendre la main ? Est-ce acceptable dans un script planifié qui envoie aussi
  le rapport du matin ?
- `Invoke-RestMethod` lit l'en-tête `Retry-After` d'une réponse 429. Votre boucle l'ignore : où
  le lire, et que faire d'une valeur de dix minutes ?
