# Construire un site avec ofceweb

Ce vignette décrit le cycle complet d’un site générique propulsé par
`ofceweb` : initialisation depuis un dépôt vierge, chiffrement
optionnel, rendu, puis déploiement. Trois fonctions structurent ce cycle
:

- [`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)
  — pose les gabarits et configure le `_quarto.yml`,
- [`render_site()`](https://ofceweb.github.io/ofceweb/reference/render_site.md)
  — construit `_site/`,
- [`deploy_site()`](https://ofceweb.github.io/ofceweb/reference/deploy_site.md)
  — publie le résultat.

Les helpers
[`rescan_site()`](https://ofceweb.github.io/ofceweb/reference/rescan_site.md)
et
[`site_version_up()`](https://ofceweb.github.io/ofceweb/reference/site_version_up.md)
viennent en complément.

**Pré-requis.** Ce vignette suppose que vous avez déjà configuré un PAT
GitHub (`GITHUB_PAT` et `DEPLOY_PAT`) et installé `gh` puis lancé
`gh auth login`. Si ce n’est pas le cas, voir d’abord [*Pré-requis : PAT
GitHub, gh CLI, variables
d’environnement*](https://ofceweb.github.io/ofceweb/articles/prerequisites.md).

## 1. Choisir le type de site

Avant de lancer quoi que ce soit, deux questions sont à trancher : où le
site est-il hébergé, et le dépôt est-il public ou privé ?

### Hébergement OFCE ou GitHub Pages

| Choix | `setup_site(ofce_host = …)` | Publication | Dépôt sous l’organisation OFCE ? |
|----|----|----|----|
| Serveurs OFCE (FTP) | `TRUE` (défaut) | `_site` → branche `site-deploy` → workflow GitHub Actions `ftp_deploy.yml` → FTP `www.ofce.fr` | Recommandé. Sinon contacter Xavier T. ou Anissa pour l’accès au serveur. |
| GitHub Pages | `FALSE` | `quarto publish gh-pages` (branche orpheline `gh-pages` créée par [`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)) | Indifférent. |

L’hébergement OFCE est le défaut historique :
`site-url = https://www.ofce.fr/` et
`site-path = <ofce_server_location>/<repo>[/v0]` (par défaut
`staging/<repo>/v0`). Le workflow FTP est patché pour pointer sur les
bons secrets (`STAGING_USER`/`STAGING_PASSWORD` pour `staging`,
`WP_USER`/`WP_PASSWORD` pour `wp`, `THREEME_USER`/`THREEME_PASSWORD`
pour `threeme`).

GitHub Pages est plus simple côté infra : pas de secrets FTP à
configurer, juste une branche `gh-pages` que Quarto alimente.

### Dépôt public ou privé

- **Public** : aucun réglage spécifique. C’est le cas le plus courant.
- **Privé hébergé OFCE** : fonctionne tel quel — la publication passe
  par FTP, donc la visibilité du dépôt n’a pas d’incidence sur le site
  rendu.
- **Privé hébergé GitHub Pages** : GitHub Pages sur dépôt privé exige un
  plan GitHub Enterprise / Pro. En pratique : soit rendre le dépôt
  public, soit basculer sur l’hébergement OFCE, soit activer le
  chiffrement via le secret `STATICRYPT_PASSWORD` (voir §3).

## 2. Préparer un dépôt minimal

Le strict nécessaire avant d’appeler
[`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)
:

1.  Créer un dépôt GitHub vide (avec ou sans README — peu importe).
2.  Le cloner localement.
3.  Ouvrir une session R à la racine du dépôt.

Aucun fichier `.qmd` n’est obligatoire : si aucun `index.qmd` n’est
trouvé,
[`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)
en copie un par défaut. Si des `.qmd` existent déjà, ils seront détectés
et listés dans `other-links`.

``` r

# depuis la racine du dépôt fraîchement cloné
ofceweb::setup_site()
```

Ce que fait
[`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)
:

- Scanne les `*.qmd` (en ignorant ceux qui commencent par `_`) et
  récupère le `title` de leur front matter (sinon le nom de fichier).
- Copie depuis `inst/setup_site/` du package :
  - `_quarto.yml` à la racine,
  - `index.qmd` à la racine (uniquement s’il n’en existe pas déjà un),
  - le dossier `www/` (assets : logos, CSS, …),
  - les workflows GitHub vers `.github/workflows/`.
- Installe/met à jour les extensions Quarto OFCE (`_extensions/`) via
  `ofce::setup_quarto()`, qui les récupère depuis le dépôt GitHub
  `OFCE/ofce-quarto-extensions` (accès réseau nécessaire).
- Renseigne le `_quarto.yml` : `title`, `site-url`, `site-path`,
  `repo-url`, la section `other-links` (une entrée par `qmd`,
  `index.qmd` en tête), et les commentaires `hypothesis` si demandé.
- Ajoute `_site` au `.gitignore`.
- Si `ofce_host = FALSE` : crée la branche orpheline `gh-pages` et la
  pousse sur `origin` (no-op si elle existe déjà ou si le working tree
  n’est pas propre).

Arguments principaux :

| Argument | Défaut | Effet |
|----|----|----|
| `ofce_host` | `TRUE` | Hébergement OFCE vs GitHub Pages. |
| `ofce_server_location` | `"staging"` | `"staging"`, `"wp"` ou `"threeme"`. Détermine le préfixe du `site-path` et les secrets FTP utilisés. |
| `website_code` | `NULL` | Code court (lettres/chiffres/`_`) utilisé comme `site-path` à la place du nom du dépôt. Ignoré si `ofce_host = FALSE`. |
| `website_title` | `NULL` | Force le titre. Sinon : titre de `index.qmd`, sinon nom du dépôt. |
| `hypothesis` | `TRUE` | Active les commentaires Hypothesis. |
| `versionning` | `TRUE` | Ajoute `/v0` au `site-path` (OFCE uniquement). Voir [`site_version_up()`](https://ofceweb.github.io/ofceweb/reference/site_version_up.md) pour incrémenter. |

Commiter le résultat avant d’aller plus loin —
[`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)
peut être relancé pour ajuster, mais la suite suppose un working tree
propre.

## 3. Chiffrer le site (optionnel)

Le chiffrement est géré **exclusivement en CI** (GitHub Actions), juste
avant le transfert FTP. Aucune manipulation locale n’est requise.

**Principe :** si le secret `STATICRYPT_PASSWORD` est défini sur le
dépôt GitHub, le workflow de déploiement chiffre automatiquement tous
les fichiers HTML avec
[staticrypt](https://github.com/robinmoisson/staticrypt) avant l’envoi
au serveur. Si le secret est absent, le déploiement se fait sans
chiffrement.

Pour activer le chiffrement, définir le secret une fois sur le dépôt :

``` sh
gh secret set STATICRYPT_PASSWORD --repo owner/mon-depot
```

`gh` demandera le mot de passe de manière interactive (masqué). Vous
pouvez aussi le passer en argument :

``` sh
echo "mon-mot-de-passe" | gh secret set STATICRYPT_PASSWORD --repo owner/mon-depot
```

Pré-requis : `gh` (GitHub CLI) installé et authentifié
(`gh auth login`), avec droits admin sur le dépôt. Voir
[*Pré-requis*](https://ofceweb.github.io/ofceweb/articles/prerequisites.html#installer-gh-github-cli).

### Comment fonctionne le chiffrement CI

Lors du déploiement FTP, chaque workflow de déploiement
(`ftp_deploy.yml`, `render_and_stage.yml`, `render_and_publish.yml`) :

1.  Lit le secret `STATICRYPT_PASSWORD` (vide → aucune action).
2.  Si défini, installe staticrypt (`npm install -g staticrypt`),
    chiffre tous les fichiers HTML dans un répertoire temporaire, puis
    les recopie sur place avant le transfert.
3.  Lance le transfert FTP avec les fichiers chiffrés.

Le rendu local
([`render_site()`](https://ofceweb.github.io/ofceweb/reference/render_site.md))
produit toujours du HTML en clair — c’est le comportement attendu. La
prévisualisation locale n’est donc pas protégée par mot de passe.

### Désactiver le chiffrement

Supprimer le secret du dépôt :

``` sh
gh secret delete STATICRYPT_PASSWORD --repo owner/mon-depot
```

Le prochain déploiement s’effectuera sans chiffrement.

## 4. Rendre le site

``` r

ofceweb::render_site()
```

Pipeline :

- Vérifie que `_quarto.yml` existe (sinon renvoie vers
  [`setup_site()`](https://ofceweb.github.io/ofceweb/reference/setup_site.md)).
- Vide `_site/`.
- Lance `quarto::quarto_render(output_format = "all")`.
- Reconstruit `_site/sitemap.xml` à partir du contenu réel de `_site/`
  (Quarto ne couvre que les pages fraîchement rendues).
- Lance une prévisualisation locale via `servr::httw("_site")` (URLs
  absolues réécrites en relatif pour la navigation locale).

Arguments utiles :

| Argument | Défaut | Effet |
|----|----|----|
| `render_site` | `TRUE` | Démarre le serveur local. Mettre à `FALSE` pour un build “headless”. |
| `site2branch` | `FALSE` | Pousse directement vers la branche de déploiement (raccourci équivalent à enchaîner [`deploy_site()`](https://ofceweb.github.io/ofceweb/reference/deploy_site.md)). |
| `workers` | `8L` | Workers parallèles. |
| `check_repo` | `TRUE` | Vérifie l’état du dépôt git avant le rendu. |

## 5. Déployer

``` r

ofceweb::deploy_site()
```

[`deploy_site()`](https://ofceweb.github.io/ofceweb/reference/deploy_site.md)
lit la clé `ofce_host` du `_quarto.yml` et choisit :

- **OFCE** (`ofce_host: true`) → délègue à
  [`site2branch()`](https://ofceweb.github.io/ofceweb/reference/site2branch.md)
  : copie `_site/` dans un dépôt temporaire, fait un commit unique,
  force-push vers `origin/site-deploy`, puis déclenche le workflow
  GitHub Actions `ftp_deploy.yml` (qui chiffre si `STATICRYPT_PASSWORD`
  est défini, puis pousse en FTP). Les credentials sont lus dans
  `DEPLOY_PAT` (à défaut, le keystore OS) — voir
  [*Pré-requis*](https://ofceweb.github.io/ofceweb/articles/prerequisites.html#stocker-github_pat-et-deploy_pat-dans-lenvironnement)
  pour la configuration de cette variable. `GITHUB_TOKEN` ne suffit pas
  car il ne peut pas dispatcher d’autres workflows.
- **GitHub Pages** (`ofce_host: false`) → lance
  `quarto publish gh-pages --no-prompt --no-browser`.

L’URL finale est affichée sur succès.

Pour forcer un re-upload FTP complet (par exemple après nettoyage côté
serveur) sans purger le serveur :

``` r

ofceweb::deploy_site(full_deploy = TRUE)
```

## 6. Récapitulatif

``` r

# 1. dépôt cloné, session R à sa racine
ofceweb::setup_site(
  ofce_host = TRUE,                    # ou FALSE pour GitHub Pages
  ofce_server_location = "staging",    # ou "wp", "threeme"
  website_title = "Mon site"
)

# 2. (optionnel) activer le chiffrement — une seule fois par dépôt
# gh secret set STATICRYPT_PASSWORD --repo owner/mon-depot

# 3. rendu
ofceweb::render_site()

# 4. déploiement
ofceweb::deploy_site()
```

## Helpers à connaître

- [`rescan_site()`](https://ofceweb.github.io/ofceweb/reference/rescan_site.md)
  — rebalaye les `.qmd` et réécrit la section `other-links` du
  `_quarto.yml`. À lancer après ajout/suppression de pages.
- [`site_version_up()`](https://ofceweb.github.io/ofceweb/reference/site_version_up.md)
  — incrémente le segment de version du `site-path` (`v0` → `v1`, `v3_4`
  → `v3_5`, etc.). OFCE uniquement.
- [`push_site_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_site_redirect.md)
  — génère et pousse une page `index.html` de redirection vers la
  version courante (si le `site-path` contient un segment `/v\d+`).
  Appelée automatiquement par
  [`stage_site()`](https://ofceweb.github.io/ofceweb/reference/stage_site.md)
  et
  [`site_version_up()`](https://ofceweb.github.io/ofceweb/reference/site_version_up.md)
  ; utile à appeler manuellement après une correction d’urgence sans
  changement de version.
