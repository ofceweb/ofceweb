# Documents de travail (Working Papers)

## Vue d’ensemble

Chaque document de travail (WP) de l’OFCE vit dans son propre dépôt
GitHub. Un WP produit deux sorties :

- une **page HTML** (site Quarto avec l’extension `wp`)
- un **PDF** (LaTeX via `wp-pdf` ou Typst via `wp-typst`)

Il peut aussi contenir des **annexes** (`annexes.qmd`) et un
**historique des révisions** (`news.qmd`).

### Cycle de vie

| État | `wp` dans `_quarto.yml` | Hébergement | URL |
|----|----|----|----|
| Brouillon | `null` | GitHub Pages | `ofce.github.io/{repo}/` |
| Publié | `N` (entier) | Serveur OFCE FTP | `www.ofce.fr/wp/{annee}/{N}/{version}/` |

------------------------------------------------------------------------

## 1. Initialiser un nouveau WP

``` r

library(ofceweb)

# Depuis la racine du dépôt GitHub du WP
setup_wp(
  path          = ".",
  website_title = "Mon document de travail",
  wp            = NULL,    # NULL = brouillon ; entier = publié
  annee         = 2026,
  lang          = "fr",
  hypothesis    = FALSE,
  versionning   = TRUE
)
```

[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
:

1.  Initialise la branche orpheline `gh-pages` (pré-publication GitHub
    Pages)
2.  Copie les gabarits (`_quarto.yml`, `index.qmd`, `annexes.qmd`,
    `news.qmd`)
3.  Copie les assets OFCE (`www/`) et l’extension Quarto
    (`_extensions/wp/`)
4.  Copie les workflows GitHub Actions (`.github/workflows/`)
5.  Adapte `_quarto.yml` avec le titre, l’URL, le numéro WP, l’année, la
    langue

Après
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md),
éditez `_quarto.yml` et `index.qmd` pour renseigner les métadonnées
définitives (auteurs, résumé, date) avant de commiter.

------------------------------------------------------------------------

## 2. Vérifier la structure avant rendu

``` r

check_wp()
```

[`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md)
vérifie :

- Champs obligatoires dans `_quarto.yml` : `annee`, `author`, `date`,
  `citation`
- `index.qmd` présent et déclarant les formats `wp-html` et `wp-pdf` /
  `wp-typst`
- `references.bib` présent (warning sinon)
- `news.qmd` présent (warning sinon)
- Si WP publié : cohérence `version` / `site-path`, `annee` valide
- Tous les `.qmd` non-index référencés dans `website.other-links`
- Unicité des `output-file` PDF

Elle retourne un data frame de diagnostics et est automatiquement
appelée par
[`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md).

------------------------------------------------------------------------

## 3. Rendre le WP

``` r

render_wp(
  path        = ".",
  check_repo  = TRUE,   # vérifier l'état git avant rendu
  check       = TRUE,   # appeler check_wp() avant rendu
  render_site = TRUE,   # lancer un serveur local après rendu
  site2branch = FALSE   # pousser vers la branche de déploiement
)
```

**Pipeline** :

1.  `check_repo_status()` si `check_repo`
2.  [`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md)
    si `check` (abandon si erreurs bloquantes)
3.  Vide `_site/`
4.  `quarto::quarto_render(output_format = "all")` — HTML + PDF
5.  Reconstruction du sitemap
6.  Patch des hashes Bootstrap CSS
7.  [`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md)
    — écriture / mise à jour de `manifest.json`
8.  Réécriture des liens absolus en relatifs si `render_site`
9.  Pousse vers la branche de déploiement si `site2branch`
10. Lance `servr::httw("_site")` si `render_site`

------------------------------------------------------------------------

## 4. Déployer le WP

``` r

deploy_wp()
```

Le comportement dépend de la valeur de `wp` dans `_quarto.yml` :

- **Brouillon** (`wp: null`) → `quarto publish gh-pages` (publie sur
  `ofce.github.io/{repo}/`)
- **Publié** (`wp: N`) →
  [`site2branch()`](https://ofceweb.github.io/ofceweb/reference/site2branch.md)
  vers `site-deploy`, puis le workflow FTP transfère vers
  `www.ofce.fr/wp/{annee}/{N}/{version}/`

------------------------------------------------------------------------

## 5. Passer de brouillon à publié

1.  Dans `_quarto.yml`, renseigner les champs `wp` et `annee` :

``` yaml
wp: 6
annee: 2026
```

2.  Relancer
    [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
    avec le numéro WP pour mettre à jour les URLs et le workflow FTP :

``` r

setup_wp(wp = 6, annee = 2026)
```

3.  Rendre et déployer :

``` r

render_wp()
deploy_wp()
```

------------------------------------------------------------------------

## 6. Incrémenter la version après une révision

``` r

wp_version_up()           # v0 -> v1, v1 -> v2, etc.
wp_version_up(custom_version = "v1_corr")   # version personnalisée
```

[`wp_version_up()`](https://ofceweb.github.io/ofceweb/reference/wp_version_up.md)
met à jour en cascade :

1.  Le champ `version` dans `_quarto.yml`
2.  Le dernier segment de `website.site-path`
3.  Le `server-dir` dans `.github/workflows/ftp_deploy.yml`
4.  `manifest.json` (via
    [`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md))

Après l’incrémentation, rendre et déployer à nouveau :

``` r

render_wp()
deploy_wp()
```

------------------------------------------------------------------------

## 7. Manifeste JSON

[`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md)
(appelée automatiquement par
[`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md))
génère `manifest.json` à la racine du dépôt et dans `_site/` :

``` json
{
  "title": "Mon document de travail",
  "authors": [{"name": "Prénom Nom", "affiliation": "OFCE, Sciences Po Paris"}],
  "abstract": "Résumé...",
  "wp": 6,
  "annee": 2026,
  "version": "v0",
  "date": "2026-05-19",
  "date_modified": "2026-05-31",
  "url": "https://www.ofce.fr/wp/2026/6/v0/",
  "pdf": "OFCEWP2026-6.pdf",
  "repo": "https://github.com/ofce/mon-wp/",
  "lang": "fr"
}
```

Ce manifeste est collecté par `webhome` via la GitHub API pour
construire l’index des WPs de l’OFCE.

------------------------------------------------------------------------

## Structure d’un dépôt WP

    mon-wp/
    ├── _quarto.yml          # métadonnées WP (wp, annee, version, auteurs, …)
    ├── index.qmd            # corps du document
    ├── annexes.qmd          # annexes (optionnel)
    ├── news.qmd             # historique des révisions
    ├── references.bib       # bibliographie
    ├── manifest.json        # manifeste JSON (généré par render_wp)
    ├── www/                 # assets OFCE (logos, icônes)
    ├── _extensions/wp/      # extension Quarto WP
    └── .github/workflows/
        ├── ftp_deploy.yml   # déploiement FTP (WP publié)
        └── gh-pages.yml     # déploiement GitHub Pages (brouillon)
