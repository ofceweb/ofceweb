# Pousse un dossier de site rendu vers une branche Git

Commite le contenu de \`\_site/\` (ou un autre dossier produit par un
générateur de site statique) dans un commit de type orphelin et le
force-pousse vers la branche \`site-deploy\` (ou celle indiquée dans
\`branch\`) du remote \`origin\`. Déclenche en option un workflow GitHub
Actions en aval (ex. un déploiement FTP) via l'API \`workflow_dispatch\`
(la branche par défaut est détectée automatiquement).

## Usage

``` r
site2branch(
  path = ".",
  branch = "site-deploy",
  source = "_site",
  progress = TRUE,
  trigger = TRUE,
  workflow = "ftp_deploy.yml",
  full_deploy = FALSE,
  inputs = list()
)
```

## Arguments

- path:

  \`\[character(1)\]\`  
  Chemin vers la racine du dépôt Git local. Défaut ".".

- branch:

  \`\[character(1)\]\`  
  nom de la branche ciblée ("site-deploy")

- source:

  \`\[character(1)\]\`  
  chemin du dossier à déployer ("\_site")

- progress:

  \`\[logical(1)\]\`  
  Si \`TRUE\` (défaut), la sortie git est transmise à la console.

- trigger:

  \`\[logical(1)\]\`  
  Si \`TRUE\` (défaut \`TRUE\`), appelle \[trigger_ftp_deploy()\] après
  un push réussi pour déclencher le workflow de déploiement FTP. Les
  échecs sont capturés et signalés comme des avertissements sans annuler
  le push. Généralement, un push sur site-deploy va déclencher le
  déploiement.

- workflow:

  \`\[character(1)\]\`  
  nom du workflow à déclencher

- full_deploy:

  \`\[logical(1)\]\`  
  Si \`FALSE\` (défaut), le fichier \`.ftp-deploy-sync-state.json\` est
  reporté depuis la branche distante afin que l'upload FTP reste
  incrémental. Mettre \`TRUE\` pour remettre à zéro chaque hash du
  fichier d'état avant le push, ce qui pousse ftp-deploy à re-uploader
  tous les fichiers sans rien supprimer d'autre sur le serveur FTP.

- inputs:

  \`\[list()\]\`  
  Liste nommée d'entrées de workflow transmises à \[trigger_action()\]
  en tant qu'entrées \`workflow_dispatch\` (ex. \`list(profile =
  "review")\`). Défaut une liste vide.

## Value

Renvoie invisiblement \`NULL\`. Appelée pour ses effets de bord.

## Details

Les identifiants sont résolus dans l'ordre suivant : 1. La variable
d'environnement \`DEPLOY_PAT\` (recommandé en CI). 2. Le gestionnaire
d'identifiants du système (Keychain macOS, GCM Windows, libsecret Linux)
via le paquet credentials — adapté à un usage interactif local.

Les URL de remote en SSH sont automatiquement converties en HTTPS avant
le push car libgit2 ne peut pas utiliser l'agent SSH du système.

## Examples

``` r
if (FALSE) { # \dontrun{
# Pousser _site/ et déclencher le workflow FTP
site2branch()

# Pousser seulement, sans déclencher le workflow en aval
site2branch(trigger = FALSE)

# Forcer un re-upload complet (ignorer l'état incrémental)
site2branch(full_deploy = TRUE)
} # }
```
