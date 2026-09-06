# Policy briefs (PB)

## Vue d’ensemble

Le workflow **policy brief (PB)** est calqué sur celui des [documents de
travail
(WP)](https://ofceweb.github.io/ofceweb/articles/working-papers.md) :
mêmes étapes (initialisation, vérification, rendu, déploiement,
incrémentation de version), fonctions `pb_*` équivalentes aux fonctions
`wp_*`, mêmes gabarits Quarto (`_quarto.yml`, `index.qmd`,
`annexes.qmd`, `news.qmd`) et les mêmes workflows GitHub Actions.

Ce document ne répète pas en détail ce qui est déjà couvert par la
vignette WP ; il se concentre sur les **différences** propres aux PB.

### Différences avec les WP

|  | Working paper (WP) | Policy brief (PB) |
|----|----|----|
| Fonctions | [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md), [`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md), [`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md), [`deploy_wp()`](https://ofceweb.github.io/ofceweb/reference/deploy_wp.md), [`publish_wp()`](https://ofceweb.github.io/ofceweb/reference/publish_wp.md), [`wp_version_up()`](https://ofceweb.github.io/ofceweb/reference/wp_version_up.md), [`wp_registry_request()`](https://ofceweb.github.io/ofceweb/reference/wp_registry_request.md) | [`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md), [`check_pb()`](https://ofceweb.github.io/ofceweb/reference/check_pb.md), [`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md), [`deploy_pb()`](https://ofceweb.github.io/ofceweb/reference/deploy_pb.md), [`publish_pb()`](https://ofceweb.github.io/ofceweb/reference/publish_pb.md), [`pb_version_up()`](https://ofceweb.github.io/ofceweb/reference/pb_version_up.md), [`pb_registry_request()`](https://ofceweb.github.io/ofceweb/reference/pb_registry_request.md) |
| Numérotation | par année (`annee` + `wp`) | **séquentielle depuis l’origine**, indépendante de l’année ; `annee` n’est **pas utilisé** pour les PB |
| Registre central | `ofceweb/wp-registry`, `wp/{annee}.json` (sharded par année) | **partagé** avec les WP : `ofceweb/wp-registry`, sous-dossier `pb/`, **fichier plat unique** `pb/pb.json` |
| Branche de PR registre | `request/{annee}/{wp}` | `request/pb/{pb}` (préfixe `pb/` pour éviter toute collision dans le dépôt partagé) |
| Convention de nommage du dépôt | `wp-{initiales}-{nom court}` | `pb-{initiale}-{nom court}` |
| URL publiée | `www.ofce.fr/wp/{annee}/{N}/{version}/` | `www.ofce.fr/pb/{N}/{version}/` (pas de segment année) |
| URL stable (citation) | dérivée de `annee`/`wp` | `https://www.ofce.fr/pb/{N}/` |
| Nom du PDF publié | `OFCEWP{annee}-{N}.pdf` | `OFCEPB{N}.pdf` (pas d’année) |
| Nom du PDF brouillon | — | `OFCEPB-draft.pdf` |
| Formats Quarto | `wp-html`, `wp-pdf` / `wp-typst` | `pb-html`, `pb-pdf` / `pb-typst` (mutuellement exclusifs, comme pour les WP) |
| Favicon | `www/fofce-wp.png` | `www/fofce-wp.png` (partagé) |
| Marqueur `_quarto.yml` | `ofce_wp: true` | `ofce_pb: true` |

[`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
refuse d’être appliqué à un dépôt marqué `ofce_wp: true` ou
`ofce_prev: true` (et réciproquement pour
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md))
: un dépôt a un type unique.

### Cycle de vie

| État | `pb` dans `_quarto.yml` | Hébergement | URL \| \| |
|----|----|----|----|
| Brouillon | `null` | GitHub Pages ou OFCE staging |  |
| Publié | `N` (entier) | Serveur OFCE FTP | `www.ofce.fr/pb/{N}/{version}/` \| \| |

Comme pour les WP, pour être *stagé* sur `staging.ofce.fr` avec
versionnage ou publié, la propriété du dépôt doit être transférée à
l’organisation OFCE. Convention de nommage recommandée :
`pb-{initiale de l'auteur.e}-{nom court du projet}`, tout en minuscule
(ex. `pb-gaxt-relance`).

------------------------------------------------------------------------

## 1. Initialiser un nouveau PB

``` r

library(ofceweb)

# Depuis la racine du dépôt GitHub du PB
setup_pb(
  path        = ".",
  lang        = "fr",
  hypothesis  = FALSE,
  versionning = TRUE
)
```

[`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
suit le même pipeline que
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
: vérification de la connexion GitHub, initialisation de la branche
`gh-pages`, copie des gabarits (`_quarto.yml`, `index.qmd`,
`annexes.qmd`, `news.qmd`) et des assets OFCE, installation/mise à jour
des extensions Quarto OFCE, mise à jour forcée des workflows GitHub
Actions.

Différence notable : `pb` n’est **pas un argument** de
[`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
(contrairement à `wp`/`annee` pour
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md))
: il est toujours lu depuis `_quarto.yml`, ou écrasé par une entrée
confirmée du registre central. Un dépôt sans `_quarto.yml` et sans
entrée de registre reste un brouillon (`pb` absent) — pour obtenir un
numéro, voir la [section 5](#passer-de-brouillon-a-publie) ci-dessous.
Le champ `annee` n’est jamais utilisé pour les PB.

Après
[`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md),
éditez `_quarto.yml` et `index.qmd` pour les métadonnées définitives
(auteurs, résumé, date) et le contenu avant de commiter.

------------------------------------------------------------------------

## 2. Vérifier la structure avant rendu

``` r

check_pb()
```

[`check_pb()`](https://ofceweb.github.io/ofceweb/reference/check_pb.md)
vérifie les mêmes catégories de champs que
[`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md)
(`_quarto.yml` obligatoires, `index.qmd` déclarant `pb-html` et
`pb-pdf`/`pb-typst`, `references.bib`, `news.qmd`, unicité des
`output-file` PDF, `.qmd` référencés dans `website.other-links`), avec
deux contrôles spécifiques aux PB :

- cohérence `version` / dernier segment de `site-path` au format `N` ou
  `N/vX` (sans segment année, `annee` n’intervenant pas dans la
  structure) ;
- convention de nommage du dépôt `pb-{initiale}-{nom court}` (warning
  non bloquant, org GitHub `ofce` uniquement).

Elle retourne un data frame de diagnostics et est appelée
automatiquement par
[`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md).
[`complete_pb_yaml()`](https://ofceweb.github.io/ofceweb/reference/complete_pb_yaml.md)
(équivalent de
[`complete_wp()`](https://ofceweb.github.io/ofceweb/reference/complete_wp.md))
peut compléter automatiquement les champs obligatoires manquants
(`date`, `author`, `citation`).

------------------------------------------------------------------------

## 3. Rendre le PB

``` r

render_pb(
  path        = ".",
  check       = TRUE,   # appeler check_pb() avant rendu
  render_site = TRUE,   # lancer un serveur local après rendu
  site2branch = FALSE   # pousser vers la branche de déploiement
)
```

Pipeline identique à
[`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md)
(vidage de `_site/`, rendu HTML + PDF via
[`quarto::quarto_render()`](https://quarto-dev.github.io/quarto-r/reference/quarto_render.html),
reconstruction du sitemap, écriture de `manifest.json`, synchronisation
de `FTP_SERVER_DIR`, réécriture des liens absolus en relatifs,
prévisualisation locale via
[`servr::httw()`](https://rdrr.io/pkg/servr/man/httd.html)), à une
différence près :
**[`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md)
ne consulte plus le registre central** — cette consultation a lieu en
amont, dans
[`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
(et à nouveau dans
[`publish_pb()`](https://ofceweb.github.io/ofceweb/reference/publish_pb.md)).
[`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md)
suppose que `draft`/`pb` sont déjà synchronisés dans `_quarto.yml` et se
contente de les lire, sans accès réseau.

------------------------------------------------------------------------

## 4. Déployer le PB

``` r

deploy_pb()
```

Le comportement dépend de l’état `stage` (lu depuis `manifest.json`,
écrit par
[`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md))
et, avant publication, de `stage-target` dans `_quarto.yml` :

- **Publié** (`stage: FALSE`) → toujours vers FTP production
  (`ftp_deploy.yml`), quelle que soit la valeur de `stage-target` — vers
  `www.ofce.fr/pb/{N}/{version}/`. Une redirection stable est aussi
  poussée
  ([`push_pb_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_pb_redirect.md)).
- **Non encore publié** (`stage: TRUE` ou absent) → destination lue
  depuis `stage-target` : `"auto"` (réévalué à chaque appel selon le
  propriétaire GitHub actuel — `"ftp"` pour l’organisation `ofce`,
  `"gh-pages"` sinon), ou forcée via `"ftp"` / `"gh-pages"`.

------------------------------------------------------------------------

## 5. Passer de brouillon à publié

Comme pour les WP, le numéro (`pb`) est la propriété du **registre
central**, pas de l’auteur·e. La différence : les PB et les WP partagent
le **même dépôt** registre (`ofceweb/wp-registry`), mais dans des
sous-dossiers distincts — `pb/` pour les PB (fichier plat unique
`pb/pb.json`, numérotation strictement séquentielle depuis l’origine),
`wp/{annee}.json` pour les WP (sharded par année).

1.  Demander un numéro :

``` r

pb_registry_request()
```

    Ouvre une pull request contre `ofceweb/wp-registry` proposant
    d'ajouter l'entrée dans `pb/pb.json`. Contrairement au flux WP (fork
    + PR cross-repo), le dépôt `ofce/wp-registry` autorise les membres de
    l'organisation `ofce` à pousser directement une branche et ouvrir une
    PR intra-dépôt sans être collaborateur·rice avec droit d'écriture —
    seule la **fusion** reste protégée (branch protection +
    `CODEOWNERS`). La branche créée est nommée `request/pb/{pb}` — le
    préfixe `pb/` évite toute collision avec les branches WP
    `request/{annee}/{wp}` du même dépôt partagé. La fonction n'attend
    pas la fusion (fire-and-forget) ; un·e admin OFCE doit approuver
    manuellement.

2.  Une fois la PR fusionnée, relancer
    [`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
    pour synchroniser `pb`/`draft`/`site-path`/`citation.*`
    (`citation.url` : `https://www.ofce.fr/pb/{N}/`, `citation.issue`:
    `"{N}"`) et les variables FTP :

``` r

setup_pb()
```

3.  Rendre et déployer :

``` r

render_pb()
deploy_pb()
```

[`publish_pb()`](https://ofceweb.github.io/ofceweb/reference/publish_pb.md)
(qui enchaîne
[`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md)
et
[`deploy_pb()`](https://ofceweb.github.io/ofceweb/reference/deploy_pb.md))
refait cette consultation du registre juste avant le rendu, pour
rattraper un enregistrement survenu depuis le dernier
[`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
— mais ne recalcule que `draft`/`pb`, pas `site-path`/`citation.*` : si
le numéro change à cette étape, relancer
[`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
avant de publier à nouveau.

------------------------------------------------------------------------

## 6. Chiffrement (optionnel)

Identique aux WP : géré exclusivement en CI, activé/désactivé via le
secret `STATICRYPT_PASSWORD` sur le dépôt (voir la vignette *Documents
de travail (Working Papers)*, section 6).

------------------------------------------------------------------------

## 7. Incrémenter la version après une révision

``` r

pb_version_up()                              # v0 -> v1, v1 -> v2, etc.
pb_version_up(custom_version = "v1_corr")    # version personnalisée
```

Met à jour en cascade `version` et le dernier segment de
`website.site-path` dans `_quarto.yml`, les variables GitHub
`FTP_SERVER_DIR`/`FTP_REDIRECT_DIR`, et régénère `manifest.json`. Ne
fonctionne que pour un PB déjà publié (`pb` non `NULL`).

``` r

render_pb()
deploy_pb()
```

------------------------------------------------------------------------

## 8. Manifeste JSON

[`pb_manifest()`](https://ofceweb.github.io/ofceweb/reference/pb_manifest.md)
(appelée automatiquement par
[`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md))
génère `manifest.json`, collecté par `webhome` pour construire l’index
des PB de l’OFCE :

``` json
{
  "title": "Mon policy brief",
  "authors": [{"name": "Prénom Nom", "affiliation": "OFCE, Sciences Po Paris"}],
  "abstract": "Résumé...",
  "pb": 153,
  "version": "v0",
  "stage": false,
  "date": "2026-05-19",
  "date_modified": "2026-05-31",
  "url": "https://www.ofce.fr/pb/153/v0/",
  "pdf": "OFCEPB153.pdf",
  "repo": "https://github.com/ofce/pb-gaxt-relance/",
  "lang": "fr",
  "source-repo": "ofce/pb-gaxt-relance"
}
```

Le champ `source-repo` (`"owner/repo"`) permet au workflow
`ftp_deploy.yml` de détecter qu’un autre dépôt tenterait de publier sous
le même numéro `pb` et de bloquer ce déploiement avant d’écraser le PB
existant — c’est la « vérification anti-collision » mentionnée dans les
workflows.

------------------------------------------------------------------------

## Structure d’un dépôt PB

    mon-pb/
    ├── _quarto.yml          # métadonnées PB (pb, version, auteurs, …) — pas de champ annee
    ├── index.qmd            # corps du document
    ├── annexes.qmd          # annexes (optionnel)
    ├── news.qmd             # historique des révisions
    ├── references.bib       # bibliographie
    ├── manifest.json        # manifeste JSON (généré par render_pb)
    ├── www/                 # assets OFCE (logos, icônes)
    ├── _extensions/ofce/      # extension Quarto ofce
    └── .github/workflows/
        ├── ftp_deploy.yml   # déploiement FTP (PB publié)
        ├── ftp_stage.yml    # déploiement FTP staging (brouillon)
        └── gh-pages.yml     # déploiement GitHub Pages (brouillon)
