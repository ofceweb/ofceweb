# Rendu complet d'un document de travail (WP) OFCE

Orchestre le build complet d'un WP Quarto : vérification du dépôt git,
vérification de la structure WP, consultation du registre central
(\`ofceweb/wp-registry\`) pour déterminer l'état \`stage\` (staging ou
publié), persistance de cet état dans la clé \`draft\` de
\`\_quarto.yml\` (lue par les extensions \`ofce-quarto-extensions\` pour
le bandeau « Version provisoire »). Les clés \`wp\`/\`annee\` de
\`\_quarto.yml\` sont synchronisées depuis l'entrée du registre trouvée
(dépôt publié) ou effacées (dépôt en staging, pas encore de numéro
attribué) — leur valeur n'est plus jamais laissée à la charge de
l'auteur·e. Suivent le nettoyage de \`\_site/\`, le rendu Quarto (HTML +
PDF), construction du sitemap, patch des hashes Bootstrap, écriture du
manifeste (champ \`stage\` inclus), synchronisation de
\`FTP_SERVER_DIR\` (WPs publiés confirmés uniquement), et
optionnellement déploiement sur la branche de déploiement et
prévisualisation locale.

## Usage

``` r
render_wp(
  path = ".",
  check = TRUE,
  progress = TRUE,
  render_site = TRUE,
  site2branch = FALSE,
  trigger = site2branch,
  workers = 8L
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- check:

  Logique. Si \`TRUE\` (défaut), appelle \[check_wp()\] avant le rendu
  et abandonne si des erreurs bloquantes sont détectées.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- render_site:

  Logique. Si \`TRUE\` (défaut), lance un serveur HTTP local via
  \[servr::httw()\] sur \`\_site/\` après le rendu.

- site2branch:

  Logique. Si \`TRUE\`, pousse \`\_site/\` vers la branche de
  déploiement via \[site2branch()\]. Défaut \`FALSE\`.

- trigger:

  Passé à \[site2branch()\]. Défaut = valeur de \`site2branch\`.

- workers:

  Entier. Nombre de workers parallèles pour le rendu. Défaut \`8L\`.

## Value

Invisible NULL.

## See also

\[setup_wp()\], \[check_wp()\], \[deploy_wp()\]
