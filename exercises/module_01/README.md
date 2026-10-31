# Exercice du module 1, l'analyse du rapport du matin

Analysez avec PSScriptAnalyzer et les réglages de l'équipe deux autres fonctions de
`PachaOps`, `Get-ErrorLogSummary` et `Get-MorningReport`. Corrigez dans une copie de
`Get-MorningReport` les règles que l'énoncé désigne, et gardez les autres en le disant,
par `SuppressMessageAttribute` et une justification. La correction est de forme : la fonction
doit rendre exactement les mêmes objets qu'avant.

## Les fichiers

- `Get-MorningReport.ps1` : votre copie de la fonction, telle qu'en `PachaOps` 0.1.0. C'est
  elle que vous modifiez, pas `src/PachaOps/Public/Get-MorningReport.ps1`.
- `reference/Get-MorningReport.ps1` : la fonction 0.1.0, à laquelle `check.ps1` compare ce que
  rend votre copie. Ne la modifiez pas.
- `check.ps1` : le contrôle. `solution/` : le corrigé.

## Les consignes

1. Analysez `src/PachaOps/Public/Get-ErrorLogSummary.ps1` avec les réglages de l'équipe
   (`-Settings ./PSScriptAnalyzerSettings.psd1`). Notez ce que l'analyse rend.
2. Analysez votre copie `exercises/module_01/Get-MorningReport.ps1` de la même façon.
3. Corrigez `PSAvoidUsingWriteHost` et `PSAvoidUsingCmdletAliases`.
4. Gardez `PSAvoidUsingPlainTextForPassword` et
   `PSAvoidUsingConvertToSecureStringWithPlainText` : les scripts plus anciens de l'équipe
   appellent encore la fonction avec `-Password`, et retirer ce paramètre change la façon de
   l'appeler, ce qui attend un test. Déclarez chaque règle gardée par
   `[Diagnostics.CodeAnalysis.SuppressMessageAttribute()]`, avec une justification qui dit
   pourquoi.
5. Ne touchez ni aux paramètres ni à ce que rend la fonction, ni au fichier de réglages de
   l'équipe.

## Le contrôle

Depuis la racine du clone, labo démarré :

```powershell
./exercises/module_01/check.ps1
```

Il analyse votre copie avec les réglages de l'équipe et vérifie qu'il ne reste rien, que les
règles désignées sont corrigées et non supprimées, et que chaque suppression a sa
justification. Il lance ensuite votre copie et la fonction 0.1.0, chacune dans un processus
`pwsh` à part, sur les deux instances du labo et une instance injoignable, avec
`-SqlCredential` puis avec `-Password` (le mot de passe vient du coffre `PachaOps`), et compare
les objets rendus. Il rend 0 et une ligne `OK` quand tout est juste, 1 sinon, avec une ligne
`FAIL` par problème. Sur le fichier de départ :

```text
FAIL  Line 16: PSAvoidUsingPlainTextForPassword is still reported; correct it, or suppress it with a justification.
FAIL  Line 19: PSAvoidUsingConvertToSecureStringWithPlainText is still reported; correct it, or suppress it with a justification.
FAIL  Line 22: PSAvoidUsingWriteHost is still reported; correct it.
FAIL  Line 33: PSAvoidUsingCmdletAliases is still reported; correct it.
```

`./exercises/module_01/check.ps1 -Solution` vérifie le corrigé.

---

# Module 1 exercise, analyzing the morning report

Analyze `Get-ErrorLogSummary` and `Get-MorningReport` with PSScriptAnalyzer and the team's
settings. In your copy of `Get-MorningReport`, correct `PSAvoidUsingWriteHost` and
`PSAvoidUsingCmdletAliases`, and keep the two password rules with
`SuppressMessageAttribute` and a justification, without changing the parameters or the
objects the function returns. Run `./exercises/module_01/check.ps1` from the root of the clone,
with the lab running.
