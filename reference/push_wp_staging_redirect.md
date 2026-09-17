# Déploie la page de redirection stable pour le WP en staging

Génère un \`index.html\` de redirection pointant vers la version
courante d'un WP en staging FTP (lue depuis \`website.site-url\` de
\`\_quarto.yml\`, de la forme
\`https://staging.ofce.fr/repo/version/\`), le pousse sur la branche
\`site-staging-redirect\`, puis déclenche le workflow
\`ftp_redirect_staging.yml\` pour publier la page à l'URL stable
\`staging.ofce.fr/repo/\`.

## Usage

``` r
push_wp_staging_redirect(path = ".", progress = TRUE, trigger = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- progress:

  Logique. Affichage de la progression git. Défaut \`TRUE\`.

- trigger:

  Logique. Si \`TRUE\` (défaut), déclenche \`ftp_redirect_staging.yml\`
  après le push.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Met à jour la variable GitHub Actions \`FTP_STAGING_REDIRECT_DIR\` avec
\`repo/\` – chemin relatif à la racine chroot \`www/staging/\` du compte
FTP \`STAGING_USER\` (même convention que \`FTP_STAGING_DIR\`, cf.
\[setup_wp()\]).

Ne fait rien si \`website.site-url\` n'a pas la forme attendue (WP
publié, brouillon GitHub Pages, ou brouillon sans version encore
attribuée).

## See also

\[deploy_wp()\], \[push_wp_redirect()\], \[wp_version_up()\]
