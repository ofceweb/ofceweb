# Package index

## Prévisions

Suite complète pour les dépôts de prévision OFCE (`prev{YY}0{3|9}`).
Trois modes de déploiement : **staging** (versionné, chiffré en CI via
staticrypt), **publish** (URL fixe, non chiffré), et **profils
personnalisés** (arbitrary Quarto profiles avec chiffrement). Le
chiffrement des sites staging et custom est appliqué par les workflows
GitHub Actions — pas localement.

- [`setup_prev()`](https://ofceweb.github.io/ofceweb/reference/setup_prev.md)
  : Initialise un dépôt de prévision OFCE
- [`check_prev()`](https://ofceweb.github.io/ofceweb/reference/check_prev.md)
  : Vérifie la structure d'un dépôt de prévision OFCE
- [`render_prev()`](https://ofceweb.github.io/ofceweb/reference/render_prev.md)
  : Rend le site de prévision OFCE (staging ou publish)
- [`stage_prev()`](https://ofceweb.github.io/ofceweb/reference/stage_prev.md)
  : Rend et déploie la prévision en staging
- [`publish_prev()`](https://ofceweb.github.io/ofceweb/reference/publish_prev.md)
  : Rend et publie la prévision (publish)
- [`deploy_prev()`](https://ofceweb.github.io/ofceweb/reference/deploy_prev.md)
  : Déploie la prévision OFCE (staging ou publish)
- [`site2staging()`](https://ofceweb.github.io/ofceweb/reference/site2staging.md)
  : Pousse \`\_site_staging/\` vers la branche \`site-staging\`
- [`site2profile()`](https://ofceweb.github.io/ofceweb/reference/site2profile.md)
  : Déploie un profil personnalisé vers staging/repo/profile/
- [`prev_version_up()`](https://ofceweb.github.io/ofceweb/reference/prev_version_up.md)
  : Incrémente la version staging d'une prévision OFCE
- [`render_prev_publish()`](https://ofceweb.github.io/ofceweb/reference/render_prev_publish.md)
  : Génère le site de la prévision (déprécié)
- [`preview_qmd()`](https://ofceweb.github.io/ofceweb/reference/preview_qmd.md)
  [`preview_qmd_staging()`](https://ofceweb.github.io/ofceweb/reference/preview_qmd.md)
  : Prévisualise le document \`.qmd\` actif dans RStudio

## Working papers

Fonctions pour les dépôts de documents de travail OFCE (WP). Un WP peut
être en mode brouillon (déployé sur GitHub Pages) ou publié (déployé via
FTP sur `www.ofce.fr/wp/{annee}/{N}/`).

- [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  : Initialise un dépôt de document de travail (WP) OFCE
- [`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md)
  : Vérifie la structure d'un dépôt de document de travail (WP)
- [`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md)
  : Rendu complet d'un document de travail (WP) OFCE
- [`publish_wp()`](https://ofceweb.github.io/ofceweb/reference/publish_wp.md)
  : Rendu et déploiement complet d'un document de travail (WP) OFCE
- [`deploy_wp()`](https://ofceweb.github.io/ofceweb/reference/deploy_wp.md)
  : Déploie un document de travail (WP) OFCE
- [`rescan_wp()`](https://ofceweb.github.io/ofceweb/reference/rescan_wp.md)
  : Rescanne les pages d'un document de travail
- [`wp_version_up()`](https://ofceweb.github.io/ofceweb/reference/wp_version_up.md)
  : Incrémente la version d'un document de travail OFCE publié
- [`encrypt_wp()`](https://ofceweb.github.io/ofceweb/reference/encrypt_wp.md)
  : Active le chiffrement statique d'un document de travail
- [`remove_encrypt()`](https://ofceweb.github.io/ofceweb/reference/remove_encrypt.md)
  : Désactive le chiffrement statique du site

## Sites génériques

Fonctions pour les sites Quarto génériques hébergés sur `www.ofce.fr`.
Supporte l’hébergement OFCE (FTP via branche de déploiement) et GitHub
Pages.

- [`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)
  : Initialise un site OFCE dans le dépôt courant
- [`render_site()`](https://ofceweb.github.io/ofceweb/reference/render_site.md)
  : Rendu d'un site OFCE générique
- [`deploy_site()`](https://ofceweb.github.io/ofceweb/reference/deploy_site.md)
  : Déploie le site selon l'hébergement déclaré dans \`\_quarto.yml\`
- [`rescan_site()`](https://ofceweb.github.io/ofceweb/reference/rescan_site.md)
  : Rescanne les pages et met à jour la section \`other-links\`
- [`site_version_up()`](https://ofceweb.github.io/ofceweb/reference/site_version_up.md)
  : Incrémente la version dans le \`site-path\` du \`\_quarto.yml\`
- [`push_site_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_site_redirect.md)
  : Déploie la page de redirection vers la version courante d'un site
  OFCE
- [`encrypt_site()`](https://ofceweb.github.io/ofceweb/reference/encrypt_site.md)
  : Active le chiffrement statique du site
- [`remove_encrypt()`](https://ofceweb.github.io/ofceweb/reference/remove_encrypt.md)
  : Désactive le chiffrement statique du site

## Blog

Fonctions pour le blog OFCE bilingue (FR/EN). Gère le cache des posts,
la construction du sitemap et le déploiement incrémental.

- [`render_blog()`](https://ofceweb.github.io/ofceweb/reference/render_blog.md)
  : Render the bilingual blog
- [`publish_blog()`](https://ofceweb.github.io/ofceweb/reference/publish_blog.md)
  : Publish the bilingual blog
- [`create_blog_version()`](https://ofceweb.github.io/ofceweb/reference/create_blog_version.md)
  : Créer une version blog d'un article EcoGaphe

## Page d’accueil

Fonctions pour le site d’accueil OFCE.

- [`render_home()`](https://ofceweb.github.io/ofceweb/reference/render_home.md)
  : Génère la homepage du site OFCE
- [`publish_home()`](https://ofceweb.github.io/ofceweb/reference/publish_home.md)
  : Publie la homepage du site OFCE

## Déploiement & utilitaires

Fonctions de bas niveau partagées entre les différents types de dépôts :
push vers une branche de déploiement, déclenchement de workflows GitHub
Actions avec inputs optionnels, téléchargement de fichiers depuis
GitHub.

- [`site2branch()`](https://ofceweb.github.io/ofceweb/reference/site2branch.md)
  : Push a rendered site folder to a Git branch
- [`site2publish()`](https://ofceweb.github.io/ofceweb/reference/site2publish.md)
  : Push a rendered site folder to a Git branch, set for publish
- [`trigger_action()`](https://ofceweb.github.io/ofceweb/reference/trigger_action.md)
  : Trigger a GitHub Actions workflow via \`workflow_dispatch\`
- [`download_gh_dir()`](https://ofceweb.github.io/ofceweb/reference/download_gh_dir.md)
  : Download a directory from a GitHub repository
- [`download_gh_file()`](https://ofceweb.github.io/ofceweb/reference/download_gh_file.md)
  : Download a single file from a GitHub repository
