# Changelog

## ofceweb v0.8.2

## ofceweb v0.8.1

- [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  calcule désormais systématiquement `website.site-path` /
  `website.site-url` dès que `wp` est non nul (fourni explicitement ou
  déjà présent dans `_quarto.yml`), plutôt que seulement lors de l’appel
  qui a défini `wp`. Un `site-path` manquant (fichier édité à la main,
  ou WP créé avant cette fonctionnalité) est désormais toujours
  recalculé.

- sécurité de la publication des WP — vérification anti-collision :
  [`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md)
  ajoute désormais un champ `source-repo` (`"owner/repo"`, résolu depuis
  le remote `origin`) au `manifest.json`. Le workflow `ftp_deploy.yml`
  télécharge le `manifest.json` déjà déployé à l’emplacement cible avant
  l’upload FTP et **annule le déploiement** si son `source-repo` ne
  correspond pas au dépôt courant — ceci empêche qu’un dépôt différent
  réutilisant le même `{annee, wp}` écrase un WP déjà publié.
  [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  migre automatiquement cette étape dans un `ftp_deploy.yml` existant
  qui ne l’a pas encore.

- correction de
  [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  : `citation.url` était calculée à partir de `website.site-url` +
  `website.site-path`, ce qui omettait le segment `wp/` de l’URL
  publique réelle (`www.ofce.fr/wp/{annee}/{wp}/`, tel que calculé
  indépendamment par
  [`deploy_wp()`](https://ofceweb.github.io/ofceweb/reference/deploy_wp.md)).
  `citation.url` est désormais construite directement depuis
  `annee`/`wp`, cohérente avec l’URL de déploiement effective.

- favicon spécifique aux documents de travail

- [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md),
  [`setup_prev()`](https://ofceweb.github.io/ofceweb/reference/setup_prev.md)
  et
  [`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)
  resynchronisent désormais systématiquement la clé `website.favicon`
  (`www/fofce-wp.png` pour les WP, `www/fofce.png` pour les prévisions
  et sites génériques), y compris sur un `_quarto.yml` déjà existant
  (auparavant seul un fichier nouvellement créé recevait cette valeur ;
  un dépôt existant conservait sa clé `favicon` d’origine).

## ofceweb v0.8.0

- nouvelle fonction
  [`render()`](https://ofceweb.github.io/ofceweb/reference/render.md) :
  détecte automatiquement le type de dépôt (WP, prévision, blog, site
  générique) via
  [`detect_repo_type()`](https://ofceweb.github.io/ofceweb/reference/detect_repo_type.md)
  et appelle
  [`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md)/[`render_prev()`](https://ofceweb.github.io/ofceweb/reference/render_prev.md)/[`render_blog()`](https://ofceweb.github.io/ofceweb/reference/render_blog.md)/[`render_site()`](https://ofceweb.github.io/ofceweb/reference/render_site.md)
  en conséquence. Si rien n’est reconnu, invite à lancer
  [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  ou
  [`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md).
- nouvelle fonction
  [`publish()`](https://ofceweb.github.io/ofceweb/reference/publish.md)
  : même détection que
  [`render()`](https://ofceweb.github.io/ofceweb/reference/render.md),
  mais appelle
  [`publish_wp()`](https://ofceweb.github.io/ofceweb/reference/publish_wp.md)/[`publish_prev()`](https://ofceweb.github.io/ofceweb/reference/publish_prev.md)/[`publish_blog()`](https://ofceweb.github.io/ofceweb/reference/publish_blog.md)/[`stage_site()`](https://ofceweb.github.io/ofceweb/reference/stage_site.md)
  (ce dernier en l’absence de `publish_site()` dédié).
- nouvelles primitives internes
  [`yaml_patch_scalar()`](https://ofceweb.github.io/ofceweb/reference/yaml_patch_scalar.md),
  [`yaml_patch_block()`](https://ofceweb.github.io/ofceweb/reference/yaml_patch_block.md),
  [`yaml_patch_delete()`](https://ofceweb.github.io/ofceweb/reference/yaml_patch_delete.md),
  [`yaml_patch_scalar_or_delete()`](https://ofceweb.github.io/ofceweb/reference/yaml_patch_scalar_or_delete.md)
  et
  [`yaml_patch_frontmatter_scalar()`](https://ofceweb.github.io/ofceweb/reference/yaml_patch_frontmatter_scalar.md)
  : édition ligne à ligne des fichiers YAML qui préserve les
  commentaires, lignes vides et l’ordre des clés.
- [`prev_version_up()`](https://ofceweb.github.io/ofceweb/reference/prev_version_up.md),
  [`wp_version_up()`](https://ofceweb.github.io/ofceweb/reference/wp_version_up.md)
  et
  [`site_version_up()`](https://ofceweb.github.io/ofceweb/reference/site_version_up.md)
  utilisent désormais ces primitives au lieu de
  [`yaml::write_yaml()`](https://yaml.r-lib.org/reference/write_yaml.html),
  qui écrasait silencieusement les commentaires des fichiers
  `_quarto*.yml`.
- [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  déduit et met à jour automatiquement `citation.issue` et
  `citation.url` à partir des autres champs YAML (`annee`, `wp`,
  `site-path`, etc.) à chaque appel ; ces champs ne sont plus à éditer à
  la main.
- gabarits `_quarto.yml` (`setup_wp`, `setup_site`, `setup_prev`) :
  favicon unifiée sur `www/fofce.png` (le logo “ofce”), désormais fourni
  dans `inst/share/www/` et `inst/setup_site/www/`. `setup_wp` utilise
  sa propre variante `www/fofce-wp.png` (même logo, badge “WP” ajouté)
  pour distinguer les onglets de navigateur des WP de ceux des autres
  dépôts ; `setup_prev`/`setup_site` gardent le favicon générique pour
  l’instant.
- `_pkgdown.yml` : nouvelle section « Dispatch automatique » pour
  [`render()`](https://ofceweb.github.io/ofceweb/reference/render.md) et
  [`publish()`](https://ofceweb.github.io/ofceweb/reference/publish.md).

## ofceweb v0.7.0

- aide et messages en français
- setup\_\* utilise setup_quarto comme source de vérité pour les
  extensions

## ofceweb v0.6.1

- divers mini bugs réduits (@claude)
- ajouts de tests (@claude) \# `setup_*` maintenant exécute
  [`update_navbar()`](https://ofceweb.github.io/ofceweb/reference/update_navbar.md)

## ofceweb v0.6.0

- restructuration des \_extensions
- navbar commune et fonction
  [`update_navbar()`](https://ofceweb.github.io/ofceweb/reference/update_navbar.md)
  (@CharlesBordet)

## ofceweb v0.5.6

- Ajout d’une CI qui fait le rendu et qui envoie sur le FTP de l’OFCE
- Appliquée aux WP et aux sites

## ofceweb v0.5.5

- Nouvelle stratégie commune pour l’encryption : l’encryption est faite
  pour le staging uniquement, à condition que le secret
  STATICRYPT_PASSWORD soit défini. L’encryption est faite par
  github.com (CI) juste avant d’envoyer en FTP.
- Cette stratégie sera la même pour tous les types de documents.
- La redirection éventuelle est aussi ajoutée à la fin du process de
  rendu (que ce soit en local ou sur la CI).

## ofceweb v0.5.4

- [`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)
  est aligné sur
  [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  pour plus de cohérence
- workflow `render-deploy` (peut être lancé sur un push)
- redirection pour une url stable dans le cas de versions
  (staging/*site*/ renvoie vers staging/*site*/vx)

## ofceweb v0.5.3

- la fonction `preview_qmd` permet la prévisualisation du qmd actif.
  Pratique non ?

## ofceweb v0.5.2

- Corrections de bugs pour la prévision, nettoyage des paramètres (dont
  `profile`).
- profils génériques (ie `review`) en plus de `publish`et `staging`
  déployés sur staging et cryptés avec ALT_STATICRYPT_PASSWORD u
- Documentation mise à jour pour la prévision, avec une vignette

## ofceweb v0.5.1

- protection ajoutée à
  [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  et
  [`setup_prev()`](https://ofceweb.github.io/ofceweb/reference/setup_prev.md)
  pour ne pas faire le setup si le dossier est autre chose.

## ofceweb v0.5.0

### Suite de fonctions prévision (nouveau)

- [`setup_prev()`](https://ofceweb.github.io/ofceweb/reference/setup_prev.md)
  — initialise un dépôt de prévision : copie les gabarits
  (`_quarto.yml`, profils staging/publish, `.qmd`, scripts
  `data_pays/`), installe les extensions Quarto depuis `inst/share/`,
  configure les variables GitHub Actions `FTP_STAGING_DIR` /
  `FTP_PUBLISH_DIR`, met à jour `.gitignore`. Détecte et corrige
  automatiquement `project.type: website` → `ofce-website`. Déduit
  `prev`, `annee` et `mois` du nom du dossier (`prev{YY}0{3|9}`).
- [`check_prev()`](https://ofceweb.github.io/ofceweb/reference/check_prev.md)
  — valide la configuration d’un dépôt (12 contrôles : nom du dossier,
  sous-dossiers, champs YAML, cohérence des `site-path`, présence des
  workflows, variables et secret GitHub).
- `render_prev(profile)` — rendu Quarto pur avec profil `"staging"`
  (défaut) ou `"publish"`. Le chiffrement est appliqué en CI, pas
  localement.
- [`stage_prev()`](https://ofceweb.github.io/ofceweb/reference/stage_prev.md)
  — `render_prev("staging")` + push `_site_staging/` vers la branche
  `site-staging` (en clair ; le workflow CI chiffre avant FTP).
- [`publish_prev()`](https://ofceweb.github.io/ofceweb/reference/publish_prev.md)
  — `render_prev("publish")` + push `_site_publish/` vers
  `site-publish`.
- `deploy_prev(target)` — déploiement seul (sans rendu), staging ou
  publish.
- [`site2staging()`](https://ofceweb.github.io/ofceweb/reference/site2staging.md)
  — wrapper de
  [`site2branch()`](https://ofceweb.github.io/ofceweb/reference/site2branch.md)
  pour la branche `site-staging`.
- [`prev_version_up()`](https://ofceweb.github.io/ofceweb/reference/prev_version_up.md)
  — incrémente la version staging dans `_quarto-staging.yml` et met à
  jour `FTP_STAGING_DIR`.
- [`render_prev_publish()`](https://ofceweb.github.io/ofceweb/reference/render_prev_publish.md)
  — dépréciée, redirige vers
  [`publish_prev()`](https://ofceweb.github.io/ofceweb/reference/publish_prev.md).

### Templates et ressources

- `inst/setup_prev/` : gabarits YAML (`_quarto.yml` avec
  `type: ofce-website`, profils staging/publish), 23 fichiers `.qmd`,
  scripts `data_pays/` (`data_pays.R`, `tab_synthese.R`, `data_vars.R`,
  `graphiques.R`), workflows GitHub Actions (`ftp_deploy_staging.yml`
  avec chiffrement staticrypt, `ftp_deploy_publish.yml`).
- `inst/share/_extensions/` : ajout des extensions `ofce/ofce` (format
  `ofce-html`), `crossref-listings`, `mcanouil/iconify`,
  `pandoc-ext/section-bibliographies`.
- `inst/share/www/` : ajout de `ofce_banner_alt2.png`, `webex.css`,
  `webex.js`.

### Corrections

- `render_wp.R` : correction d’un bug où le chiffrement
  `encrypt_site: true` n’était pas appliqué lors du rendu local.
- plus d’utilisation de “/tmp” mais
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html) à la place pour
  éviter un bug possible sur windows  
- NAMESPACE mis à jour avec les 9 nouvelles exportations.

## ofceweb v0.4.1

- divers bugs dans les fonctions pour les documents de travail corrigés

## ofceweb v0.4.0

- fonctions pour les documents de travail
- documentation du package et site associé
- NEWS dans le repo !
