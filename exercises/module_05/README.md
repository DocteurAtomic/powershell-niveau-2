# Exercice du module 5, l'analyse dans le workflow

Le workflow de l'équipe, `.github/workflows/test.yml`, lance les tests sous Linux et sous
Windows. Il ne lance pas PSScriptAnalyzer : une fonction qui réintroduit `Write-Host` ou un
alias passe sans un mot, alors que l'équipe a écrit ses règles au module 1. Ajoutez au
workflow un contrôle PSScriptAnalyzer qui fait échouer le run dès qu'il trouve une alerte.

## Les consignes

1. Écrivez `analyze.ps1` à la racine du clone, à côté de `build.ps1`. Il analyse `src`, avec
   `-Recurse` et les réglages de l'équipe (`PSScriptAnalyzerSettings.psd1`, à la racine), écrit
   ce qu'il trouve, nom de la règle compris, et sort en code 1 s'il trouve au moins une alerte,
   en code 0 sinon. Il doit marcher lancé depuis la racine du clone, `./analyze.ps1`, comme le
   workflow le lancera.
2. Décidez ce que vous faites de `tests/`. Sur les fichiers de tests, PSScriptAnalyzer signale
   comme jamais lues les variables qu'un `BeforeAll` pose et qu'un `It` lit
   (`PSUseDeclaredVarsMoreThanAssignments`). Soit vous n'analysez que `src`, soit vous analysez
   aussi `tests` en excluant cette règle par `-ExcludeRule`. Dans les deux cas, un test
   Pester ordinaire ne doit pas faire tomber l'analyse.
3. Dans `.github/workflows/test.yml`, installez PSScriptAnalyzer à la version de l'équipe,
   1.25.0, par `Install-PSResource`, et ajoutez l'étape qui lance `./analyze.ps1`, dans le job
   des tests ou dans un job à part. Sans `continue-on-error: true` : une alerte doit faire
   échouer le run. Les tests restent.
4. Poussez sur votre dépôt GitHub et lisez le run.

Si votre `src` est celui du cours, en 0.2.0, l'analyse trouve quatre alertes dans
`Get-MorningReport` : `Write-Host`, l'alias `%`, et les règles du mot de passe en clair
(`PSAvoidUsingPlainTextForPassword`, `PSAvoidUsingConvertToSecureStringWithPlainText`). Le run
passe au rouge : c'est le contrôle qui fait son travail. Avec la correction de l'exercice du module 4 (0.2.1), elle ne trouve rien :
`Write-Host` et l'alias y sont corrigés, et les règles du mot de passe supprimées par
`SuppressMessageAttribute`, avec leur justification.

## Le contrôle

Depuis la racine du clone :

    ./exercises/module_05/check.ps1

PowerShell n'a pas de lecteur YAML : le contrôle cherche dans `test.yml`, par `Select-String`,
la ligne qui lance `analyze.ps1`, l'installation de PSScriptAnalyzer 1.25.0, l'appel à
`Invoke-Pester`, et l'absence de `continue-on-error: true`. Puis il lance votre `analyze.ps1`
dans un `pwsh` à part, depuis un dossier temporaire qui contient une copie des réglages et un
module fabriqué, quatre fois : une fonction propre (code 0 attendu), une fonction qui appelle
`Write-Host` (code non nul, et le nom de la règle dans la sortie), une accolade ouvrante seule
sur sa ligne, que seuls les réglages de l'équipe signalent (code non nul), et une fonction
propre à côté d'un test Pester (code 0). Il rend 0 et une ligne `OK` quand tout est juste, 1
sinon, avec une ligne `FAIL` par point qui manque. Une ligne `NOTE` dit enfin ce que votre
`analyze.ps1` trouve dans le `src` du clone, sans compter comme un échec : le run sur GitHub
le montre.

Le contrôle vérifie la partie locale. La preuve qui reste est le run sur GitHub : le job de
l'analyse rouge sur une alerte, vert quand `src` n'en a plus.

`./exercises/module_05/check.ps1 -Solution` vérifie le corrigé.

## Le corrigé

`solution/analyze.ps1` (à copier à la racine) et `solution/test.yml` (à copier dans
`.github/workflows/`), avec un job `analyze` à part, sous Linux seulement : l'analyse donne le
même résultat sur les deux systèmes, et un job à part laisse les tests tourner même quand
l'analyse tombe.

---

# Exercise of module 5, the analysis in the workflow

Write `analyze.ps1` at the root of the clone: it runs PSScriptAnalyzer on `src`, recursively,
with the settings of the team, writes its findings with the rule names, and exits with 1 on
any finding, 0 otherwise. A Pester test file must not make it fail (analyze `src` only, or
exclude `PSUseDeclaredVarsMoreThanAssignments` on `tests`). In `.github/workflows/test.yml`,
install PSScriptAnalyzer 1.25.0 and add a step that runs `./analyze.ps1`, without
`continue-on-error`, then push to your own repository and read the run.
`./exercises/module_05/check.ps1` searches the workflow as text and runs your script on
made-up modules; `-Solution` checks the solution.
