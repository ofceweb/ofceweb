## ofceweb v0.6.0

* restructuration des _extensions
* navbar commune et fonction `update_navbar()` (@CharlesBordet)

## ofceweb v0.5.6

* Ajout d'une CI qui fait le rendu et qui envoie sur le FTP de l'OFCE
* Appliquée aux WP et aux sites

## ofceweb v0.5.5

* Nouvelle stratégie commune pour l'encryption : l'encryption est faite pour le staging uniquement, à condition que le secret STATICRYPT_PASSWORD soit défini. 
L'encryption est faite par github.com (CI) juste avant d'envoyer en FTP. 
* Cette stratégie sera la même pour tous les types de documents.
* La redirection éventuelle est aussi ajoutée à la fin du process de rendu (que ce soit en local ou sur la CI).

## ofceweb v0.5.4

* `setup_site()` est aligné sur `setup_wp()` pour plus de cohérence
* workflow `render-deploy` (peut être lancé sur un push)
* redirection pour une url stable dans le cas de versions (staging/_site_/ renvoie vers staging/_site_/vx)

## ofceweb v0.5.3

* la fonction `preview_qmd` permet la prévisualisation du qmd actif. Pratique non ?

## ofceweb v0.5.2

* Corrections de bugs pour la prévision, nettoyage des paramètres (dont `profile`).
* profils génériques (ie `review`) en plus de `publish`et `staging` déployés sur staging et cryptés avec ALT_STATICRYPT_PASSWORD u 
* Documentation mise à jour pour la prévision, avec une vignette

## ofceweb v0.5.1

* protection ajoutée à `setup_wp()` et `setup_prev()` pour ne pas faire le setup si le dossier est autre chose.

## ofceweb v0.5.0

### Suite de fonctions prévision (nouveau)

* `setup_prev()` — initialise un dépôt de prévision : copie les gabarits
  (`_quarto.yml`, profils staging/publish, `.qmd`, scripts `data_pays/`),
  installe les extensions Quarto depuis `inst/share/`, configure les variables
  GitHub Actions `FTP_STAGING_DIR` / `FTP_PUBLISH_DIR`, met à jour
  `.gitignore`. Détecte et corrige automatiquement `project.type: website` →
  `ofce-website`. Déduit `prev`, `annee` et `mois` du nom du dossier
  (`prev{YY}0{3|9}`).
* `check_prev()` — valide la configuration d'un dépôt (12 contrôles : nom du
  dossier, sous-dossiers, champs YAML, cohérence des `site-path`, présence des
  workflows, variables et secret GitHub).
* `render_prev(profile)` — rendu Quarto pur avec profil `"staging"` (défaut)
  ou `"publish"`. Le chiffrement est appliqué en CI, pas localement.
* `stage_prev()` — `render_prev("staging")` + push `_site_staging/` vers la
  branche `site-staging` (en clair ; le workflow CI chiffre avant FTP).
* `publish_prev()` — `render_prev("publish")` + push `_site_publish/` vers
  `site-publish`.
* `deploy_prev(target)` — déploiement seul (sans rendu), staging ou publish.
* `site2staging()` — wrapper de `site2branch()` pour la branche `site-staging`.
* `prev_version_up()` — incrémente la version staging dans
  `_quarto-staging.yml` et met à jour `FTP_STAGING_DIR`.
* `render_prev_publish()` — dépréciée, redirige vers `publish_prev()`.

### Templates et ressources

* `inst/setup_prev/` : gabarits YAML (`_quarto.yml` avec `type: ofce-website`,
  profils staging/publish), 23 fichiers `.qmd`, scripts `data_pays/`
  (`data_pays.R`, `tab_synthese.R`, `data_vars.R`, `graphiques.R`), workflows
  GitHub Actions (`ftp_deploy_staging.yml` avec chiffrement staticrypt,
  `ftp_deploy_publish.yml`).
* `inst/share/_extensions/` : ajout des extensions `ofce/ofce` (format
  `ofce-html`), `crossref-listings`, `mcanouil/iconify`, `pandoc-ext/section-bibliographies`.
* `inst/share/www/` : ajout de `ofce_banner_alt2.png`, `webex.css`, `webex.js`.

### Corrections

* `render_wp.R` : correction d'un bug où le chiffrement `encrypt_site: true`
  n'était pas appliqué lors du rendu local.
* plus d'utilisation de "/tmp" mais `tempdir()` à la place pour éviter un bug possible sur windows  
* NAMESPACE mis à jour avec les 9 nouvelles exportations.

## ofceweb v0.4.1

* divers bugs dans les fonctions pour les documents de travail corrigés

## ofceweb v0.4.0

* fonctions pour les documents de travail
* documentation du package et site associé
* NEWS dans le repo !
