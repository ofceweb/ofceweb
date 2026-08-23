# Déclenche un workflow GitHub Actions via \`workflow_dispatch\`

Envoie un événement \`workflow_dispatch\` à l'API GitHub Actions pour
démarrer manuellement un workflow (typiquement un job de déploiement
FTP). Ceci est appelé automatiquement par \[site2branch()\] sauf si
\`trigger = FALSE\`.

## Usage

``` r
trigger_action(
  root = ".",
  workflow = "ftp_deploy.yml",
  branch = NULL,
  inputs = list()
)
```

## Arguments

- root:

  \`\[character(1)\]\`  
  Chemin vers le dépôt Git local utilisé pour résoudre le propriétaire
  et le nom du dépôt GitHub depuis l'URL du remote \`origin\`. Défaut
  \[here::here()\].

- workflow:

  \`\[character(1)\]\`  
  Nom du fichier de workflow à déclencher (ex. \`"ftp_deploy.yml"\`).

- branch:

  \`\[character(1)\]\`  
  Branche sur laquelle le workflow sera exécuté. Défaut \`NULL\`, ce qui
  détecte automatiquement la branche par défaut du dépôt via l'API
  GitHub.

- inputs:

  \`\[list()\]\`  
  Liste nommée d'entrées de workflow transmises à l'événement
  \`workflow_dispatch\` (ex. \`list(profile = "review")\`). Défaut une
  liste vide (pas d'entrée).

## Value

Renvoie invisiblement \`NULL\`. Appelée pour ses effets de bord.

## Details

Le token GitHub est résolu dans l'ordre suivant : 1. La variable
d'environnement \`DEPLOY_PAT\` — \*\*requise en CI\*\* car le
\`GITHUB_TOKEN\` intégré ne peut pas déclencher d'autres workflows
(GitHub le bloque pour empêcher les exécutions récursives). 2. Le
gestionnaire d'identifiants du système via gitcreds — adapté à un usage
interactif local.

## Examples

``` r
if (FALSE) { # \dontrun{
trigger_action()
trigger_action(workflow = "deploy.yml")
} # }
```
