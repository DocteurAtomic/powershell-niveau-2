# PowerShell, niveau 2

Labo, données, démonstrations et exercices du cours en ligne
[« PowerShell, niveau 2 »](https://www.docteuratomic.com) de Docteur Atomic, la suite du
[niveau 1](https://github.com/DocteurAtomic/powershell-niveau-1).

## Ce qu'il faut

- PowerShell 7.6 (`pwsh`), installé par la méthode officielle de votre système :
  [Learn, Installer PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
  Sous Windows, le cours se suit dans PowerShell 7, pas dans Windows PowerShell 5.1.
- Git, OpenSSH (`ssh`, `ssh-keygen`, `ssh-keyscan`), et Docker ou Podman avec `compose`.
- Un compte GitHub pour le module 5.
- Environ 6 Go de mémoire libre et 3 Go de disque pour les conteneurs.

## Le labo

    git clone https://github.com/DocteurAtomic/powershell-niveau-2.git
    cd powershell-niveau-2
    pwsh ./setup/install.ps1                 # avec Docker
    pwsh ./setup/install.ps1 -Engine podman  # avec Podman

Le script installe pour votre utilisateur les modules du niveau 1 (dbatools 2.9.1,
SqlServer 22.4.5.1, SecretManagement 1.1.2, SecretStore 1.0.6), Pester 6.2.0 et 5.9.1 côte à
côte, PSScriptAnalyzer 1.25.0, PSFramework 1.15.479 et dbachecks 3.0.2. Il télécharge l'aide
de PowerShell, la sauvegarde de `PachadataTraining` (626 Mo) et les trois outils de la
communauté du module 11, et vérifie leurs sommes SHA-256. Il démarre ensuite les quatre
conteneurs, restaure la base sur la première instance, crée la base `DBA` sur les deux, crée
votre clé SSH sous `lab/ssh/` et inscrit la clé de l'hôte distant dans `~/.ssh/known_hosts`,
crée le coffre `PachaOps` s'il manque, puis contrôle le tout.

| Rôle | Conteneur | Adresse |
|---|---|---|
| sql1, SQL Server 2025 | `pwshcourse` | `localhost,14533` |
| sql2, SQL Server 2025 | `pwshcourse-b` | `localhost,14534` |
| Hôte distant, SSH | `pwshcourse-host` | `localhost`, port 14535, utilisateur `student` |
| Serveur de webhook | `pwshcourse-webhook` | `http://localhost:14580` |

Utilisateur `sa`, mot de passe de labo `Course-2026!lab`, à ne jamais reprendre ailleurs.
L'hôte distant voit `lab/backups/` sous `/srv/backups` ; le serveur de webhook écrit chaque
requête reçue dans `lab/webhook/received.jsonl`.

## Le contenu

- `data/` : l'inventaire des instances de l'équipe (`instances.csv`) et des journaux
  d'erreurs de SQL Server (`errorlog/`), repris du niveau 1.
- `host/` : l'image de l'hôte distant et du serveur de webhook (Ubuntu 24.04, OpenSSH,
  PowerShell 7.6.9).
- `setup/` : l'installation du labo, la création des fichiers de sauvegarde factices
  (`new-backupfiles.ps1`, relançable), le contrôle des instances (`test-lab.ps1`) et des deux
  conteneurs du niveau 2 (`test-host.ps1`), et `run-checks.ps1`, que l'intégration continue
  lance à chaque modification.

Jouez ces scripts sur le labo, jamais sur un serveur de production.

## Licence

Le code est sous licence MIT ([`LICENSE`](LICENSE)).

---

# PowerShell, Level 2

Lab, data, demos and exercises of the online course "PowerShell, Level 2" by Docteur Atomic,
the sequel of [Level 1](https://github.com/DocteurAtomic/powershell-niveau-1).

Requirements: PowerShell 7.6, Git, OpenSSH, Docker or Podman with `compose`, a GitHub account
for module 5, about 6 GB of free memory.

    pwsh ./setup/install.ps1                 # Docker
    pwsh ./setup/install.ps1 -Engine podman  # Podman

The script installs the modules at the versions of the course, downloads the database backup
and the community tools of module 11 and checks their hashes, starts the two SQL Server 2025
instances, the remote host (SSH on port 14535, user `student`) and the webhook test server
(port 14580), restores the database, creates the database `DBA` on both instances, your SSH
key and the vault `PachaOps`, then checks the lab. Lab password of `sa`: `Course-2026!lab`.
Run these scripts on the lab only. The code is under the MIT license.
