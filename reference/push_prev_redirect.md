# Pousse la page de redirection stable /prev/derniere/ d'une prévision OFCE

Génère un \`index.html\` de redirection pointant vers la prévision
publiée courante (\`/prev/prevYYMM/\`, lue depuis le \`site-path\` de
\`\_quarto-publish.yml\`), le pousse sur la branche \`site-redirect\` du
dépôt de prévision, puis déclenche le workflow \`ftp_redirect.yml\` pour
publier la page à l'URL stable \`www.ofce.fr/prev/derniere/\`.

## Usage

``` r
push_prev_redirect(path = ".", progress = TRUE, trigger = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt de prévision. Défaut \`"."\`.

- progress:

  Logique. Affichage de la progression git. Défaut \`TRUE\`.

- trigger:

  Logique. Si \`TRUE\` (défaut), déclenche \`ftp_redirect.yml\` après le
  push via \[trigger_action()\].

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Met à jour la variable GitHub Actions \`FTP_REDIRECT_DIR\` avec
\`derniere/\` (chemin relatif au répertoire \`/prev/\` du compte FTP
\`PREV_USER\`, même convention que \`FTP_PUBLISH_DIR\`).

\*\*Non appelée automatiquement\*\* : la publication d'une prévision
(\[publish_prev()\] ou \[deploy_prev()\]\`(profile = "publish")\`) peut
aussi servir à corriger une prévision ancienne, auquel cas
\`/prev/derniere/\` ne doit \*\*pas\*\* être re-pointée. Appeler cette
fonction manuellement, depuis la racine du dépôt de la prévision qui
devient la prévision courante, juste après sa première publication.

## Prévision Users

## See also

\[publish_prev()\], \[deploy_prev()\], \[push_site_redirect()\]
