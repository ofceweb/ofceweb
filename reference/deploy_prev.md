# Déploie la prévision OFCE (staging ou publish)

Pousse le répertoire de sortie déjà rendu vers la branche git appropriée
sans relancer le rendu Quarto. Pour staging, pousse \`\_site_staging/\`
vers \`site-staging\` ; pour publish, pousse \`\_site_publish/\` vers
\`site-publish\`.

## Usage

``` r
deploy_prev(
  path = ".",
  profile = "staging",
  progress = TRUE,
  trigger = TRUE,
  full_deploy = FALSE
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- profile:

  \`"staging"\` (défaut), \`"publish"\`, ou tout autre profil Quarto
  déclaré dans \`\_quarto.yml\`. Les profils personnalisés sont déployés
  vers \`staging/repo/profile/\` sans numéro de version.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- trigger:

  Logique. Déclenche le workflow GitHub Actions FTP après le push.
  Défaut \`TRUE\`.

- full_deploy:

  Logique. Si \`TRUE\`, force la ré-émission de tous les fichiers vers
  le FTP (ignore l'état incrémental). Défaut \`FALSE\`.

## Value

Invisible \`NULL\`.

## Details

Pour les profils \`"staging"\`/\`"publish"\`, la variable GitHub Actions
FTP correspondante (\`FTP_STAGING_DIR\`/\`FTP_PUBLISH_DIR\`) est
resynchronisée depuis \`\_quarto-staging.yml\`/\`\_quarto-publish.yml\`
juste avant de déclencher le workflow (voir \[sync_ftp_dir_var()\]),
pour rester correcte même si leur \`site-path\` a été modifié en dehors
de \[prev_version_up()\]/ \[setup_prev()\] depuis le dernier
déploiement. Un profil personnalisé n'a aucune variable à resynchroniser
: \`ftp_deploy_profile.yml\` calcule le répertoire cible directement à
partir du nom du dépôt et du profil.

## See also

\[stage_prev()\], \[publish_prev()\], \[site2staging()\]
