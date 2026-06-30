# Pousse la page de redirection vers la version courante d'un site OFCE

Génère un \`index.html\` de redirection pointant vers la version
courante du site (lue depuis le \`site-path\` du \`\_quarto.yml\`) et le
pousse sur la branche \`site-redirect\`, puis déclenche le workflow
\`ftp_redirect.yml\` pour publier la page sur le serveur FTP.

## Usage

``` r
push_site_redirect(path = ".", progress = TRUE, trigger = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- trigger:

  Logique. Si \`TRUE\` (défaut), déclenche \`ftp_redirect.yml\` après le
  push via \[trigger_action()\].

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Sans effet (sortie silencieuse) si \`site-path\` ne contient pas de
segment de version (\`/v+\`) ou si \`ofce_host\` n'est pas \`true\`.

Appelée automatiquement par \[site_version_up()\] lors d'un incrément de
version, et par \[stage_site()\] à chaque déploiement staging.

## Site Users

## See also

\[site_version_up()\], \[stage_site()\], \[deploy_site()\]
