# Package index

## Dispatch automatique

Points d’entrée uniques qui détectent le type de dépôt (WP, prévision,
blog ou site générique) et appellent automatiquement la fonction de
rendu ou de publication correspondante.

- [`render()`](https://ofceweb.github.io/ofceweb/reference/render.md) :
  Détecte le type d'un dépôt et lance le bon rendu
- [`publish()`](https://ofceweb.github.io/ofceweb/reference/publish.md)
  : Détecte le type d'un dépôt et lance la bonne publication
- [`deploy()`](https://ofceweb.github.io/ofceweb/reference/deploy.md) :
  Détecte le type d'un dépôt et lance le bon déploiement
- [`check()`](https://ofceweb.github.io/ofceweb/reference/check.md) :
  Détecte le type d'un dépôt et lance le bon diagnostic
- [`registry_request()`](https://ofceweb.github.io/ofceweb/reference/registry_request.md)
  : Détecte le type d'un dépôt et lance la bonne demande
  d'enregistrement

## Prévisions

Suite complète pour les dépôts de prévision OFCE (`prev{YY}0{3|9}`).
Trois modes de déploiement : **staging** (versionné, chiffré en CI via
staticrypt), **publish** (URL fixe, non chiffré), et **profils
personnalisés** (arbitrary Quarto profiles avec chiffrement). Le
chiffrement des sites staging et custom est appliqué par les workflows
GitHub Actions — pas localement.

- [`setup_prev()`](https://ofceweb.github.io/ofceweb/reference/setup_prev.md)
  : Initialise un dépôt de prévision OFCE
- [`stage_prev()`](https://ofceweb.github.io/ofceweb/reference/stage_prev.md)
  : Rend et déploie la prévision en staging

## Working papers

Fonctions pour les dépôts de documents de travail OFCE (WP). Un WP peut
être en mode brouillon (déployé sur GitHub Pages) ou publié (déployé via
FTP sur `www.ofce.fr/wp/{annee}/{N}/`). Le chiffrement éventuel est
appliqué par le workflow GitHub Actions — pas localement.

- [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  : Initialise un dépôt de document de travail (WP) OFCE
- [`rescan_wp()`](https://ofceweb.github.io/ofceweb/reference/rescan_wp.md)
  : Rescanne les pages d'un document de travail

## Policy briefs

Fonctions pour les dépôts de policy briefs OFCE (PB). Équivalent PB des
fonctions *Working papers* ci-dessus : un PB peut être en mode brouillon
(déployé sur GitHub Pages ou en staging FTP) ou publié (déployé via FTP
sur `www.ofce.fr/pb/{N}/`, numérotation séquentielle indépendante de
l’année). Le registre central est partagé avec les WP
(`ofceweb/wp-registry`, sous-dossier `pb/`, fichier plat `pb/pb.json`).

- [`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
  : Initialise un dépôt de policy brief (PB) OFCE
- [`rescan_pb()`](https://ofceweb.github.io/ofceweb/reference/rescan_pb.md)
  : Rescanne les pages d'un policy brief

## Sites génériques

Fonctions pour les sites Quarto génériques hébergés sur `www.ofce.fr`.
Supporte l’hébergement OFCE (FTP via branche de déploiement) et GitHub
Pages. Le chiffrement staticrypt est appliqué **en CI**, juste avant le
transfert FTP, via le secret `STATICRYPT_PASSWORD` — aucune manipulation
locale n’est requise.

- [`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)
  : Initialise un site OFCE dans le dépôt courant
- [`rescan_site()`](https://ofceweb.github.io/ofceweb/reference/rescan_site.md)
  : Rescanne les pages et met à jour la section \`other-links\`

## Publication flash d’un dossier

Fonctions pour mettre en ligne un .qmd sur `staging.ofce.fr`. Le
chiffrement staticrypt est appliqué **en CI**, juste avant le transfert
FTP, via le secret `STATICRYPT_PASSWORD` — aucune manipulation locale
n’est requise.

- [`preview_folder()`](https://ofceweb.github.io/ofceweb/reference/preview_folder.md)
  : Preview a rendered ad-hoc folder site locally
- [`render_folder()`](https://ofceweb.github.io/ofceweb/reference/render_folder.md)
  : Render an arbitrary folder as a standalone Quarto site
- [`deploy_folder()`](https://ofceweb.github.io/ofceweb/reference/deploy_folder.md)
  : Deploy a rendered ad-hoc folder site to staging
- [`publish_folder()`](https://ofceweb.github.io/ofceweb/reference/publish_folder.md)
  : Render and deploy a folder as a standalone Quarto site, in one step

## Blog

Fonctions pour le blog OFCE bilingue (FR/EN). Gère le cache des posts,
la construction du sitemap et le déploiement incrémental.

- [`check_blog()`](https://ofceweb.github.io/ofceweb/reference/check_blog.md)
  : Vérifie la structure d'un post de blog avant soumission
- [`render_blog()`](https://ofceweb.github.io/ofceweb/reference/render_blog.md)
  : Rend le blog bilingue
- [`publish_blog()`](https://ofceweb.github.io/ofceweb/reference/publish_blog.md)
  : Publie le blog bilingue
- [`create_blog_version()`](https://ofceweb.github.io/ofceweb/reference/create_blog_version.md)
  : Créer une version blog d'un article EcoGaphe
- [`submit_blog()`](https://ofceweb.github.io/ofceweb/reference/submit_blog.md)
  : Soumet un post de blog pour relecture dans ofce/Blog_relecture

## Page d’accueil

Fonctions pour le site d’accueil OFCE.

- [`render_home()`](https://ofceweb.github.io/ofceweb/reference/render_home.md)
  : Génère la homepage du site OFCE
- [`publish_home()`](https://ofceweb.github.io/ofceweb/reference/publish_home.md)
  : Publie la homepage du site OFCE

## Déploiement & utilitaires

Fonctions de bas niveau partagées entre les différents types de dépôts.

- [`preview_qmd()`](https://ofceweb.github.io/ofceweb/reference/preview_qmd.md)
  : Prévisualise le document \`.qmd\` actif dans RStudio
- [`update_navbar()`](https://ofceweb.github.io/ofceweb/reference/update_navbar.md)
  : Met à jour la navbar du \`\_quarto.yml\` depuis la source
  centralisée
- [`check_fonts()`](https://ofceweb.github.io/ofceweb/reference/check_fonts.md)
  : Vérifie (et installe) les polices Google utilisées par les thèmes
  OFCE
- [`download_gh_dir()`](https://ofceweb.github.io/ofceweb/reference/download_gh_dir.md)
  : Download a directory from a GitHub repository
- [`download_gh_file()`](https://ofceweb.github.io/ofceweb/reference/download_gh_file.md)
  : Download a single file from a GitHub repository
- [`site2branch()`](https://ofceweb.github.io/ofceweb/reference/site2branch.md)
  : Pousse un dossier de site rendu vers une branche Git
