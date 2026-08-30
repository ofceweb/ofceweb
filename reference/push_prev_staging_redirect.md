# Pousse la page de redirection stable pour la prévision en staging

Génère un \`index.html\` de redirection pointant vers la version
courante de la prévision en staging (lue depuis
\`\_quarto-staging.yml\`), le pousse sur la branche
\`site-staging-redirect\` du dépôt de prévision, puis déclenche le
workflow \`ftp_redirect_staging.yml\` pour publier la page à l'URL
stable \`staging.ofce.fr/prev_id/\`.

## Usage

``` r
push_prev_staging_redirect(path = ".", progress = TRUE, trigger = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt de prévision. Défaut \`"."\`.

- progress:

  Logique. Affichage de la progression git. Défaut \`TRUE\`.

- trigger:

  Logique. Si \`TRUE\` (défaut), déclenche \`ftp_redirect_staging.yml\`
  après le push via \[trigger_action()\].

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Met à jour la variable GitHub Actions \`FTP_STAGING_REDIRECT_DIR\` avec
le chemin parent (sans segment de version).

\*\*Appelée automatiquement\*\* par \[stage_prev()\] après le
déploiement de la version courante, afin que l'URL stable pointe
toujours vers la dernière version en staging. Peut aussi être appelée
manuellement pour rafraîchir la redirection sans refaire un build
complet.

## See also

\[stage_prev()\], \[push_prev_redirect()\], \[push_site_redirect()\]
