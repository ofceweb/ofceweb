# Documents de travail (Working Papers)

## Vue d’ensemble

Chaque document de travail (WP) de l’OFCE vit dans son propre dépôt
GitHub. Un WP produit deux sorties :

- une **page HTML** (site Quarto avec l’extension `wp`)
- un **PDF** (LaTeX via `wp-pdf` ou Typst via `wp-typst`)

Il peut contenir des **annexes** (`annexes.qmd`) et un **historique des
révisions** (`news.qmd`), ainsi que tout autre document que l’on
souhaite (code, explications de code, de données, etc…).

### Cycle de vie

[TABLE]

Lorsque le docuement de travail est *stagé* sur le site staging.ofce.fr,
il est possible de versionner. Le versionnage est impossible sur github
gh-pages.

Pour être *stagé* sur le site ofce.fr ou publié, la propriété du dépôt
doit être transférée à l’organisation OFCE. On recommande la convention
de nommage suitante :
`wp-{initiales de l'auteur.e}-{nom court du projet}`, le TOUT EN
MINUSCULE. Par exemple `wp-gaxt-trec`.

------------------------------------------------------------------------

## 1. Initialiser un nouveau WP

Il suffit de lancer
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
dans un dépôt git qui contient (ou non) le matériau pour le document de
travail. Le document principal s’appelle `index.qmd` (c’est
obligatoire).
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
crée le document s’il n’existe pas, ne le change pas s’il existe. Il est
possible de copier coller un contenu dans le document créé.

``` r

library(ofceweb)

# Depuis la racine du dépôt GitHub du WP
setup_wp(
  path          = ".",
  lang          = "fr",
  hypothesis    = FALSE,
  versionning   = TRUE
)
```

[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
:

1.  Vérifie la connexion GitHub (`gh::gh("GET /user")`)
2.  Initialise la branche orpheline `gh-pages` (pré-publication GitHub
    Pages)
3.  Copie les gabarits (`_quarto.yml`, `index.qmd`, `annexes.qmd`,
    `news.qmd`)
4.  Copie les assets OFCE (`www/`) et installe/met à jour les extensions
    Quarto OFCE (`_extensions/`) via `ofce::setup_quarto()` (accès
    réseau nécessaire)
5.  Force-remplace les workflows GitHub Actions (`.github/workflows/`)
    depuis le package — les workflows ne doivent pas être édités
    manuellement
6.  Adapte `_quarto.yml` avec le titre, l’URL, le numéro WP, l’année, la
    langue
7.  Consulte le registre central `ofceweb/wp-registry` (accès réseau
    nécessaire) : si le dépôt y a une entrée confirmée, `wp`/`annee`
    sont synchronisés depuis cette entrée et `draft` est positionné en
    conséquence — voir « 5. Passer de brouillon à publié » ci-dessous ;
    en cas d’échec réseau, ces clés sont laissées inchangées.

Après
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md),
`_quarto.yml` est déjà correct et cohérent (`draft`, `wp`, `annee`,
`site-path`, `citation.*`) : éditez-le ainsi que `index.qmd` pour
renseigner les métadonnées définitives (auteurs, résumé, date) et bien
sûr le contenu avant de commiter.

------------------------------------------------------------------------

## 2. Vérifier la structure avant rendu

``` r

check_wp()
```

[`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md)
vérifie :

- Connexion GitHub : `gh::gh("GET /user")` (warning non bloquant si
  absent)
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
  check       = TRUE,   # appeler check_wp() avant rendu
  render_site = TRUE,   # lancer un serveur local après rendu
  site2branch = FALSE   # pousser vers la branche de déploiement
)
```

**Pipeline** :

1.  [`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md)
    si `check` (abandon si erreurs bloquantes)
    - Vérifie la connexion GitHub (`gh::gh("GET /user")`)
2.  Vide `_site/`
3.  `quarto::quarto_render(output_format = "all")` — HTML + PDF
4.  Reconstruction du sitemap
5.  Patch des hashes Bootstrap CSS
6.  [`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md)
    — écriture / mise à jour de `manifest.json`
7.  Synchronisation de `FTP_SERVER_DIR` (variable GitHub Actions)
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
  `ofce.github.io/{repo}/`) ou pousse en staging sur le site de l’ofce à
  l’adresse `staging.ofce.fr/{repo}/{version}/`.
- **Publié** (`wp: N`) →
  [`site2branch()`](https://ofceweb.github.io/ofceweb/reference/site2branch.md)
  vers `site-deploy`, puis le workflow FTP transfère vers
  `www.ofce.fr/wp/{annee}/{N}/{version}/`

------------------------------------------------------------------------

## 5. Passer de brouillon à publié

Le numéro WP (`wp`) et l’année (`annee`) sont la propriété du **registre
central** `ofceweb/wp-registry`, pas de l’auteur·e : dès que le dépôt y
a une entrée confirmée,
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
synchronise `wp`/`annee` (et `draft`) depuis cette entrée, en écrasant
toute valeur passée en argument ou déjà présente dans `_quarto.yml`.

1.  Demander un numéro via
    [`wp_registry_request()`](https://ofceweb.github.io/ofceweb/reference/wp_registry_request.md),
    qui calcule le numéro (auto-incrémenté, ou fourni via `wp =`) et
    ouvre une PR contre `ofceweb/wp-registry` — `annee` est lu depuis
    `_quarto.yml` si absent, et `contact` depuis `git config user.email`
    si non fourni :

``` r

wp_registry_request()
```

    Un·e admin OFCE doit approuver et fusionner cette PR — la fonction
    n'attend pas la fusion (fire-and-forget).

2.  Une fois la PR fusionnée, relancer
    [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
    pour synchroniser `_quarto.yml` (`wp`, `annee`, `draft`,
    `site-path`, `citation.url`/`citation.issue`) et mettre à jour les
    variables FTP (`FTP_SERVER_DIR`, `FTP_REDIRECT_DIR`) :

``` r

setup_wp()
```

3.  Rendre et déployer :

``` r

render_wp()
deploy_wp()
```

[`publish_wp()`](https://ofceweb.github.io/ofceweb/reference/publish_wp.md)
(qui enchaîne
[`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md)
et
[`deploy_wp()`](https://ofceweb.github.io/ofceweb/reference/deploy_wp.md)
— voir
[`publish()`](https://ofceweb.github.io/ofceweb/reference/publish.md)
pour la dispatche automatique selon le type de dépôt) refait cette
consultation du registre juste avant le rendu, pour rattraper un
enregistrement survenu depuis le dernier
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
— mais ne recalcule que `draft`/`wp`/`annee`, pas
`site-path`/`citation.*` : si le numéro change à cette étape, relancer
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
avant de publier à nouveau.

Pour un dépôt **pas encore enregistré**, `wp=`/`annee=` restent les
seuls arguments qui pilotent `_quarto.yml` — utile pour un brouillon en
attente de numéro (le bandeau « Version préliminaire » reste affiché
tant que le registre ne confirme rien).

------------------------------------------------------------------------

## 6. Chiffrement (optionnel)

Le chiffrement est géré **exclusivement en CI** (GitHub Actions), juste
avant le transfert FTP. Aucune manipulation locale n’est requise.

Si le secret `STATICRYPT_PASSWORD` est défini sur le dépôt, le workflow
`ftp_deploy.yml` chiffre automatiquement tous les fichiers HTML avant
l’envoi au serveur. Si le secret est absent, le déploiement s’effectue
avec chiffrement en utilisant la valeur par défaut du mot de passe
STATICRYPT_PASSWORD (voir les administrateurs pour cette valeur).

``` sh
# Activer le chiffrement
gh secret set STATICRYPT_PASSWORD --repo owner/mon-wp

# Désactiver le chiffrement
gh secret delete STATICRYPT_PASSWORD --repo owner/mon-wp
```

Le rendu local
([`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md))
produit toujours du HTML en clair.

------------------------------------------------------------------------

## 7. Incrémenter la version après une révision

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

## 8. Manifeste JSON

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
    ├── _extensions/ofce/      # extension Quarto ofce
    └── .github/workflows/
        ├── ftp_deploy.yml   # déploiement FTP (WP publié)
        └── gh-pages.yml     # déploiement GitHub Pages (brouillon)
