# Exercice du module 8, l'espace des sauvegardes lu sur le serveur

`Get-BackupShareUsage` compte les fichiers de sauvegarde d'un dossier, additionne leur taille,
et lit la taille et l'espace libre du volume qui les contient. Elle le fait sur la machine où
elle tourne : le poste, et sa copie `lab/backups`. L'équipe veut ces chiffres lus sur le serveur
qui garde les sauvegardes, `pwshcourse-host`, dans son dossier `/srv/backups`.

## Les fichiers

- `Get-BackupShareUsage.ps1` : le fichier de départ, la version qui lit le poste.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

1. La fonction prend les paramètres de la connexion : `-HostName`, `-Port` (22 par défaut),
   `-UserName` et `-KeyFilePath`, et `-Path`, le dossier sur le serveur, `/srv/backups` par
   défaut.
2. Elle ouvre une session SSH par `New-PSSession`, fait le travail sur le serveur par
   `Invoke-Command -Session`, et ferme la session dans tous les cas, erreur comprise.
3. Elle rend un seul objet, avec exactement les propriétés `ComputerName` (le nom du serveur, lu
   sur le serveur), `Path`, `FileCount`, `BackupBytes`, `VolumeSizeBytes` et
   `VolumeFreeBytes`. Les propriétés que le remoting ajoute (`PSComputerName`, `RunspaceId`,
   `PSShowComputerName`) n'en font pas partie.

Le piège du module : une variable de la fonction lue dans le bloc distant sans `$using:` y est
vide.

Dans le labo, le conteneur `pwshcourse-host` partage le disque de votre poste : la taille et
l'espace libre du volume sont donc ceux de votre disque. C'est la taille du dossier qui
distingue le serveur du poste, `lab/backups` du clone n'étant pas le dossier que le serveur
monte quand vous travaillez dans une copie. Sur un vrai serveur de sauvegarde, le volume est le
sien.

Pour essayer à la main, depuis la racine du clone :

```powershell
. ./exercises/module_08/Get-BackupShareUsage.ps1
Get-BackupShareUsage -HostName localhost -Port 14535 -UserName student -KeyFilePath lab/ssh/id_ed25519
```

## Le critère

Depuis la racine du clone, le labo démarré :

```powershell
./exercises/module_08/check.ps1
```

Le contrôle lance votre fonction dans un `pwsh` neuf, sur `pwshcourse-host`, puis lit lui-même
les mêmes chiffres sur le serveur et compare. L'espace libre bouge pendant le contrôle (d'autres
programmes écrivent sur le disque) : il se compare à 2 % près de la taille du volume ; le reste
doit être égal. Le contrôle vérifie aussi qu'aucune session ne reste ouverte après l'appel. Il
rend 0 et une ligne `OK` quand tout est juste, 1 sinon. Sur le départ :

```text
FAIL  Get-BackupShareUsage has no parameter HostName, Port, UserName, KeyFilePath: it cannot reach the server yet.
```

`./exercises/module_08/check.ps1 -Solution` vérifie le corrigé.

## À réfléchir

- Le corrigé additionne les tailles sur le serveur et ne ramène que des nombres. Que
  ramènerait `Invoke-Command { Get-ChildItem -Path /srv/backups -Recurse -File }` sur un serveur
  de dix mille fichiers, et que pourriez-vous encore en faire sur le poste ?
- La fonction ouvre et ferme sa session à chaque appel. Si le rapport du matin l'appelait trois
  fois de suite pour le même serveur, combien de connexions ouvrirait-il, et comment en ouvrir
  moins ?
- Pourquoi la fonction ne recopie-t-elle pas l'objet distant tel quel, alors qu'il a déjà les
  bonnes valeurs ?
