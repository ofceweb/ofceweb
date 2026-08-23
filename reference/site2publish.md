# Pousse un dossier de site rendu vers une branche Git, pour publication

Commite le contenu de \`\_site_publish/\` dans un commit de type
orphelin et le force-pousse vers la branche \`site-publish\` du remote
\`origin\`. Déclenche un workflow GitHub Actions en aval (ex. un
déploiement FTP) via l'API \`workflow_dispatch\` (la branche par défaut
est détectée automatiquement).

## Usage

``` r
site2publish(path = ".", progress = TRUE, trigger = TRUE, full_deploy = FALSE)
```

## Arguments

- path:

  \`\[character(1)\]\`  
  Chemin vers la racine du dépôt Git local. Défaut ".".

- progress:

  \`\[logical(1)\]\`  
  Si \`TRUE\` (défaut), la sortie git est transmise à la console.

- trigger:

  \`\[logical(1)\]\`  
  Si \`TRUE\` (défaut \`FALSE\`), appelle \[trigger_ftp_deploy()\] après
  un push réussi pour déclencher le workflow de déploiement FTP. Les
  échecs sont capturés et signalés comme des avertissements sans annuler
  le push. Généralement, un push sur site-deploy va déclencher le
  déploiement.

- full_deploy:

  \`\[logical(1)\]\`  
  Transmis à \[site2branch()\]. Mettre \`TRUE\` pour forcer un re-upload
  complet.

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
} # }
```
