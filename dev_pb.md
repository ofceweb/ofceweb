# Proposition (Claude) — analyse du workflow WP et plan d’action PB

L’objectif est de construire un pipeline de fonctions pour construire et
déployer les policy briefs OFCE à l’instar de ce qui est fait
aujourd’hui pour les documents de travail.

Je décris en détail le fonctionnement du workflow pour les documents de
travail (working paper, wp)

La fonction ofceweb/setup_wp() permet d’initialiser un dépôt quelconque
avec les options permettant de render le document de travail.

La fonction ofceweb/wp_registry_request() effectue une pull request
auprès du dépôt github ofce/wp_registry.

La fonction ofceweb/wp_manifest() donne les métadonnées du json
nécessaire au registry

La fonction wp_registry_sync() permet de s’assurer du bon fonctionnement
du registre.

Le format html du WP est normalisé. ce format est défini dans le dépot
ofce-quarto-extensions, dans le dossier \_extensions.

Tu peux trouver ces dépôts en local sous github/web/wp-registry et
github/web/ofce-quarto-extenions.

L’idée serait

1.  de créer un format PB dans ofce-quarto-extensions sur le modèle du
    format wp qu’on pourra adapter ensuite.

2.  de créer un dépôt pb-registry sur le github de l’OFCE sur le modèle
    de wp_registry

3.  de créer des fonctions setup_pb(), pb_registry_request(),
    pb_manifest() dan sle package ofceweb qui me semblent indispensables

Là ou je suis au moins clair, c’est dans quelle mesure, il faut créer
des fonctions pb_registry_sync(), check_pb(),complete_pb_yaml(),
deploy_pb(),encrypt_pb() ou render_pb(). Toutes ces fonctions ont leur
équivalent pour les wp qui sont dans ofceweb. En revanche, je ne suis
pas sur de comprendre leur rôle dans le workflow actuel pour les wp,
s’il faut faire une fonction équivalente pour les pb ou si il faut
adpater les fonctions existantes pour les wp en les étendant à un
nouveau format.

------------------------------------------------------------------------

## 1. Ce que je pense de ton plan (i)(ii)(iii)

Ton plan est **le bon** dans ses grandes lignes : les trois briques
(format Quarto, dépôt registre, fonctions `ofceweb`) sont exactement les
trois piliers du workflow WP. Deux remarques de fond avant d’entrer dans
le détail :

- **Le codebase a déjà un précédent décisif.** Il n’existe pas seulement
  la famille `wp_*` : il existe aussi une famille complète `prev_*` pour
  les **prévisions**
  ([`setup_prev()`](https://ofceweb.github.io/ofceweb/reference/setup_prev.md),
  [`render_prev()`](https://ofceweb.github.io/ofceweb/reference/render_prev.md),
  [`deploy_prev()`](https://ofceweb.github.io/ofceweb/reference/deploy_prev.md),
  [`check_prev()`](https://ofceweb.github.io/ofceweb/reference/check_prev.md),
  [`prev_version_up()`](https://ofceweb.github.io/ofceweb/reference/prev_version_up.md),
  `prev_redirect.R`, dossier `inst/setup_prev/`, extension dédiée). La
  convention établie du package pour ajouter un type de document est
  donc **la duplication préfixée** (`<kind>_*`) qui réutilise des
  helpers déjà génériques — *pas* la paramétrisation d’une fonction
  unique. Cela tranche ta question (iv) : on suit le patron `prev_*` et
  on crée une famille `pb_*`. C’est moins risqué que de refactorer les
  ~800 lignes très subtiles de
  [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md).

- **Il manque une brique (0) en amont de (i)(ii)(iii) : les conventions
  PB.** Avant d’écrire la moindre ligne, il faut figer 4 décisions (voir
  §4) qui pilotent *tout* le reste (URL publique, numérotation, chemin
  FTP, intégration webhome). Le format et les fonctions en découlent
  mécaniquement.

## 2. Comment marche réellement le workflow WP (pour lever tes doutes)

Le cycle de vie d’un WP :

1.  **[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)**
    — initialise/répare le dépôt : copie les gabarits (`_quarto.yml`,
    `index.qmd`, `news.qmd`, `annexes.qmd`, `www/`), installe
    l’extension Quarto via `ofce::setup_quarto()`, **écrase toujours**
    les workflows `.github/workflows/`, pose le drapeau `ofce_wp: true`,
    calcule les valeurs dérivées (`site-url`, `site-path`, `citation.*`,
    variables GitHub `FTP_SERVER_DIR`, `FTP_STAGING_DIR`). C’est **la
    seule source de vérité** des champs dérivés. Consulte le registre
    central pour synchroniser `wp`/`annee`/`draft`.
2.  **[`wp_registry_request()`](https://ofceweb.github.io/ofceweb/reference/wp_registry_request.md)**
    — ouvre une PR sur `ofce/wp-registry` pour réserver un numéro
    `{annee}/{wp}`. Fire-and-forget ; un·e admin fusionne. Auto-numérote
    `max(wp)+1`.
3.  **`sync_wp_registry_state()`** (interne, = ton `pb_registry_sync`) —
    interroge le registre, écrit `draft`/`wp`/`annee` dans
    `_quarto.yml`. **Sécurité clé** : si le registre est injoignable,
    elle *efface* `wp`/`annee` et force `draft: true` — une vérification
    impossible n’est jamais traitée comme une confirmation. Appelée par
    [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
    et
    [`publish_wp()`](https://ofceweb.github.io/ofceweb/reference/publish_wp.md).
4.  **[`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md)**
    — diagnostics bloquants/avertissements avant rendu (présence
    `_quarto.yml`, formats `wp-html` + `wp-pdf`/`wp-typst`, unicité des
    `output-file`, cohérence `site-path`, etc.).
5.  **`complete_wp_yaml()`**
    ([`complete_wp()`](https://ofceweb.github.io/ofceweb/reference/complete_wp.md))
    — remplit *non destructivement* les champs obligatoires manquants
    (`date`, `annee`, `author`, `citation`, `ofce_wp`). Utilitaire de
    dépannage suggéré par
    [`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md).
6.  **[`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md)**
    — orchestration :
    [`check_wp()`](https://ofceweb.github.io/ofceweb/reference/check_wp.md)
    → vide `_site/` → `quarto render` (HTML+PDF) → sitemap →
    [`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md)
    → resync `FTP_SERVER_DIR` → (option)
    [`site2branch()`](https://ofceweb.github.io/ofceweb/reference/site2branch.md)
    → preview locale. Ne consulte plus le réseau ; lit `draft` déjà
    persistée.
7.  **[`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md)**
    — écrit `manifest.json` (racine + `_site/`). Contient `source-repo`,
    utilisé par le workflow FTP pour la **vérification anti-collision**
    (deux dépôts ne peuvent pas écraser le même numéro).
8.  **[`deploy_wp()`](https://ofceweb.github.io/ofceweb/reference/deploy_wp.md)**
    — route le déploiement selon `stage` (registre) et `stage-target` :
    publié → FTP production (`ftp_deploy.yml`) + redirection stable ;
    sinon → FTP staging (`ftp_stage.yml`) ou GitHub Pages.
    [`publish_wp()`](https://ofceweb.github.io/ofceweb/reference/publish_wp.md)
    = resync registre +
    [`render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md) +
    [`deploy_wp()`](https://ofceweb.github.io/ofceweb/reference/deploy_wp.md).
9.  **[`encrypt_wp()`](https://ofceweb.github.io/ofceweb/reference/encrypt_wp.md)**
    — **déprécié** : simple coquille qui pointe vers
    [`encrypt_site()`](https://ofceweb.github.io/ofceweb/reference/encrypt_site.md).
    Le chiffrement réel est fait en CI (staticrypt, secret
    `STATICRYPT_PASSWORD`).

**Helpers déjà génériques (aucune duplication nécessaire, réutilisables
tels quels) :**
[`site2branch()`](https://ofceweb.github.io/ofceweb/reference/site2branch.md),
[`site2staging()`](https://ofceweb.github.io/ofceweb/reference/site2staging.md),
[`encrypt_site()`](https://ofceweb.github.io/ofceweb/reference/encrypt_site.md),
`build_sitemap()`, `resolve_stage_target()`, `detect_gh_owner()`,
`gh_slug_from_remote()`, `set_gh_var()`, `check_gh_setup()`,
[`check_fonts()`](https://ofceweb.github.io/ofceweb/reference/check_fonts.md),
[`check_quarto_version()`](https://ofceweb.github.io/ofceweb/reference/check_quarto_version.md),
[`update_navbar()`](https://ofceweb.github.io/ofceweb/reference/update_navbar.md),
tous les `yaml_patch_*()`, `ofce::setup_quarto()`.

## 3. Réponse fonction par fonction à ta question (iv)

| Fonction envisagée | Verdict | Justification |
|----|----|----|
| [`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md) | **Créer** (copie de `setup_wp` adaptée) | Trop de conventions WP-spécifiques (flag, URL, numérotation, formats). Suit le patron `prev_*`. |
| [`pb_registry_request()`](https://ofceweb.github.io/ofceweb/reference/pb_registry_request.md) | **Créer** | Cible `ofce/pb-registry`, schéma et numérotation PB. |
| [`pb_manifest()`](https://ofceweb.github.io/ofceweb/reference/pb_manifest.md) | **Créer** | URL/chemin/PDF spécifiques PB ; garde `source-repo` pour l’anti-collision. |
| `pb_registry_sync()` (`sync_pb_registry_state`) | **Créer, interne** | Indispensable : même rôle et même filet de sécurité réseau que côté WP. |
| [`check_pb()`](https://ofceweb.github.io/ofceweb/reference/check_pb.md) | **Créer** | Vérifie `pb-html`/format PDF, `ofce_pb`, schéma d’URL PB, convention de nommage. |
| [`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md) | **Créer** (fin wrapper d’orchestration) | Même squelette que `render_wp` ; n’appelle que des helpers génériques + `check_pb`/`pb_manifest`. |
| [`deploy_pb()`](https://ofceweb.github.io/ofceweb/reference/deploy_pb.md) | **Créer** (fin wrapper) | Routage identique ; seuls diffèrent l’URL production et le workflow FTP ciblé. |
| [`complete_pb_yaml()`](https://ofceweb.github.io/ofceweb/reference/complete_pb_yaml.md) | **Optionnel / basse priorité** | Confort. Peut être un wrapper qui change juste `container-title`. À faire seulement si [`check_pb()`](https://ofceweb.github.io/ofceweb/reference/check_pb.md) en a besoin. |
| `encrypt_pb()` | **NE PAS créer** | Le chiffrement est déjà générique via [`encrypt_site()`](https://ofceweb.github.io/ofceweb/reference/encrypt_site.md) + CI staticrypt. Réutiliser tel quel. |
| [`pb_version_up()`](https://ofceweb.github.io/ofceweb/reference/pb_version_up.md) | **Créer** (voir §4.4) | Le workflow WP réel est versionné (`version: v1`) — on reprend le même schéma. |
| `pb_redirect` / [`push_pb_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_pb_redirect.md) | **Créer** (voir §4.1/4.4) | URL stable + segment de version comme les WP. |

**En résumé** : on duplique la logique *métier* (conventions), on
réutilise l’*infra* déjà factorisée. `encrypt_pb` tombe ;
`complete_pb_yaml` reste optionnel.

## 3bis. Ce que le workflow WP réel confirme (dépôt `OFCE/wp-pam-pmq`)

J’ai inspecté un vrai WP OFCE en cours (`wp/wp-pam-pmq`, en staging). Il
**fige concrètement** plusieurs conventions que je listais comme « à
décider » — elles se transposent mécaniquement aux PB :

- **Staging générique** : `stage-target: ftp`, `draft: true`,
  `wp: null`, `version: v1`,
  `site-url: https://staging.ofce.fr/wp-pam-pmq/v1/`. Le `manifest.json`
  (commité à la racine) porte `stage: true`,
  `url: https://staging.ofce.fr/wp-pam-pmq/v1/`,
  `pdf: OFCEWP-draft.pdf`, `source-repo: OFCE/wp-pam-pmq`. → Le staging
  n’a **rien de WP-spécifique** : `staging.ofce.fr/{repo}/{version}/`.
  Un PB en staging suivra exactement le même chemin.
- **Production** : `www.ofce.fr/wp/{annee}/{wp}/` (+ `/vN`),
  `citation.url` stable, PDF `OFCEWP{annee}-{wp}.pdf`. Versionnement
  **actif** (`v1`) → les PB seront versionnés de même.
- **Navbar entièrement inlinée** dans `_quarto.yml` par
  [`update_navbar()`](https://ofceweb.github.io/ofceweb/reference/update_navbar.md)
  (générique, partagée) — aucun besoin de version PB.
- **5 workflows** identiques au gabarit du package :
  `render_and_deploy.yml` (rendu CI via
  [`ofceweb::render_wp()`](https://ofceweb.github.io/ofceweb/reference/render_wp.md) +
  FTP différentiel via la branche `site-deploy`), `ftp_deploy.yml`
  (production + anti-collision), `ftp_stage.yml` (staging, branche
  `site-staging`, `FTP_STAGING_DIR`), `ftp_redirect.yml` (URL stable,
  `FTP_REDIRECT_DIR`), `gh-pages.yml`. → Pour les PB : mêmes 5
  workflows, seuls changent le **chemin FTP production** et l’**URL
  d’anti-collision**.

**Conclusion** : les questions §4.1 (URL/chemin), §4.2 (numérotation) et
§4.4 (versionnement) ne sont plus vraiment ouvertes — le patron WP les
fixe. Il ne reste qu’à **valider la transposition PB** (le préfixe
`pb/`) et à trancher §4.3 (intégration webhome), la seule brique
réellement non construite.

## 4. Décisions Phase 0

### 4.1 — Numérotation : **DÉCIDÉE ✅**

Entier annuel auto-incrémenté par `pb-registry` (comme les WP) ; PDF
`OFCEPB{annee}-{num}.pdf`, brouillon `OFCEPB-draft.pdf` ; types
d’entrées `repo` / `pdf-only` (schéma repris de `wp-registry`).

### 4.2 — Intégration webhome : **DÉCIDÉE ✅ → hors périmètre**

La collecte automatique (API GitHub sur registre/manifestes) est traitée
comme un **chantier séparé, commun WP+PB**, hors du périmètre de ce
plan. Le pipeline PB s’arrête donc au **déploiement FTP + manifeste** ;
l’apparition dans `publications/policy.qmd` reste, pour l’instant,
alimentée par le `policy.yml` statique existant (comme les WP via
`working_papers.yml`). Aucune fonction PB ne doit dépendre de webhome.

### 4.3 — URL publique + chemin FTP : **DÉCIDÉE ✅ (préfixe `pb/`)**

Par analogie stricte avec les WP : - Production :
`www.ofce.fr/pb/{annee}/{num}/` (+ `/vN`), `server-dir` FTP
`pb/{annee}/{num}/`. - Staging : `staging.ofce.fr/{repo}/{version}/`
(mécanisme générique, identique aux WP). - Anti-collision : le manifeste
PB déployé est comparé à
`https://www.ofce.fr/pb/{FTP_SERVER_DIR}manifest.json`.

**Coexistence avec le legacy `/pdf/pbrief/{annee}/` : conservée sans
contrainte.** Les deux espaces de noms sont **disjoints** — le pipeline
PB n’écrit **jamais** sous `/pdf/pbrief/` (PDF legacy servis tels
quels), uniquement sous `pb/{annee}/{num}/`. Aucune collision, aucune
redirection imposée. La **flexibilité est portée par le registre**
(comme `wp-registry`), qui accepte deux types d’entrées : - `repo` → PB
Quarto, déployé sur `pb/{annee}/{num}/` (avec `source-repo: OFCE/…`) ; -
`pdf-only` → simple PDF enregistré, `pdf-path: pdf/pbrief/…` (sans
dépôt).

On ne tranche donc **rien** sur le devenir du legacy : les deux voies
restent ouvertes. Toute unification/migration éventuelle (mirroring des
PDF, redirections) est une **décision éditoriale/ webhome hors
périmètre** de ce plan.

### 4.4 — Extension `pb` existante : **DÉCIDÉE ✅ → refaire depuis `wp`, greffer l’identité PB**

Comparaison faite entre `pb` (Blog_relecture, v0.2.0) et `wp`
(ofce-quarto-extensions, v0.6.0) : la `pb` existante est **insuffisante
et incompatible** avec notre architecture cible. C’est un design **plus
ancien et autonome** :

| Aspect | `wp` (cible) | `pb` (Blog_relecture) |
|----|----|----|
| Modèle | couche fine **sur la base partagée `ofce`** (`../ofce/sass`, `ofce.scss`, `csl`, `img`, `url-nav-active.html`, `encadre.js`) | **autonome** : polices/logos/filtres embarqués, ne référence jamais `../ofce/` |
| Thème HTML | `bootstrap` + sass OFCE | `cosmo` + `ofcepb.scss` local |
| Typst | template complet | **stub** (`typst: default`) |
| PDF LaTeX | 6 partials | 2 partials |
| CSL | `../ofce/csl/…` | **aucun** |
| Schéma Quarto | moderne `>=1.9.38`, `crossref:` nesté | ancien `>=1.8.26`, clés plates `crossref-*` |
| Valeurs en dur | aucune | `pdf.annee: 2023` (⚠️ métadonnée doc dans le format) |
| Layout partials | `html/`, `pdf/`, `typst/` | `html_template/`, `pdf_template/` |

Notre pipeline (`setup_pb` → `ofce::setup_quarto()` installe tout le
bundle sous `_extensions/ofce/*` avec base `ofce`) **suppose le modèle
couche-fine** qu’utilisent `wp`/`note`. La `pb` autonome perd la base
`ofce` (navbar-active JS, encadrés, sass/rules, CSL), a un Typst stub et
un PDF incomplet, et porte un schéma périmé.

**Décision : ne pas porter la `pb` en l’état.** Créer `_extensions/pb/`
**en repartant de `wp`** (architecture couche-fine, formats
`pb-html`/`pb-pdf`/`pb-typst`, base `../ofce/`, schéma moderne), puis
**greffer l’identité visuelle PB** récupérée du Blog_relecture — le
*design*, pas la *plomberie* : - `html_template/ofcepb.scss` → nouveau
`pb.scss` (adapté à `bootstrap` + sass OFCE partagé) ; -
`html_template/title-block.html` / `title-metadata.html` / `toc.html` →
partials `html/` PB ; - `pdf_template/title.tex` (+ `before-body.tex`) →
couverture PDF PB.

## 5. Réconciliation de l’existant (à ne pas rater)

- **Une extension `pb` existe déjà** en local
  (`web/Blog_relecture/_extensions/ofce/pb/`, aussi vue dans un ancien
  commit webhome) mais **pas** dans `ofce-quarto-extensions`. **Analyse
  faite (voir §4.4) : elle est insuffisante et incompatible** avec
  l’architecture cible (design autonome ancien, Typst stub, PDF
  incomplet, pas de base `ofce`). → **Décision : la refaire depuis
  `wp`** et n’en récupérer que l’identité visuelle (`ofcepb.scss`,
  partials de titre, couverture PDF).
- **`ofce::setup_quarto()` et le nom de format — RÉSOLU.** Vérifié sur
  webhome et le WP réel : une fois installée, l’extension apparaît sous
  `_extensions/ofce/{nom}` et le format se réfère `{nom}-html`. Ainsi
  `_extensions/ofce/wp` → `wp-html`
  (cf. [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  qui teste la présence de `_extensions/ofce/wp`, et `_quarto.yml` qui
  déclare `format: wp-html`). Donc pour un PB : `_extensions/ofce/pb` →
  `pb-html`/`pb-pdf`/`pb-typst`, et
  [`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
  testera la présence de `_extensions/ofce/pb`. Plus d’incertitude ici.
- **Garde-fous de type.**
  [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  refuse un dépôt `ofce_prev: true`.
  [`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
  devra refuser symétriquement `ofce_wp: true`/`ofce_prev: true`, et
  réciproquement.

## 6. Plan d’action détaillé (ordre d’exécution)

### Phase 0 — Décisions

Numérotation : entier annuel via `pb-registry`, PDF
`OFCEPB{annee}-{num}.pdf` (§4.1). ✅

webhome : collecte auto = chantier séparé, hors périmètre ; pipeline PB
s’arrête au FTP+manifeste (§4.2). ✅

Versionnement : PB versionnés comme les WP (`/vN`), confirmé par le
workflow WP réel. ✅

URL/chemin FTP : préfixe `pb/{annee}/{num}/` ; legacy `/pdf/pbrief/`
préservé sans contrainte (espaces disjoints + type registre `pdf-only`)
(§4.3). ✅

Extension `pb` existante : **refaire depuis `wp`** + greffer l’identité
PB (§4.4). ✅

> **Phase 0 close.** Toutes les décisions bloquantes sont prises ; le
> plan peut passer en exécution.

### Phase 1 — Format Quarto PB (ton point (i)) — ✅ TERMINÉE

Créé `ofce-quarto-extensions/_extensions/pb/` **en copiant
`_extensions/wp/`** (base couche-fine : formats
`pb-html`/`pb-pdf`/`pb-typst`, partials `html/`/`pdf/`/`typst/`,
référence `../ofce/` pour sass/csl/img/js). ✅

`_extension.yml` adapté : titre « Format Policy Brief OFCE », thème →
`pb.scss`, `version: 0.1.0`. ✅

Conversion des partials WP→PB (déléguée à Sonnet, vérifiée) : variable
de numéro `$wp$`→`$pb$`, libellés « Document de travail »/« Working
Paper »→« Policy Brief », classe `wp-toc-label`→`pb-toc-label`, dans
`html/toc.html`, `pdf/before-body.tex`, `pdf/before-title.tex`,
`typst/typst-show.typ`, `typst/typst-template.typ`, `pb.scss`. ✅

Périmètre PDF : **Typst complet, comme `wp`** (on conserve `typst/` et
les partials Typst). ✅

**Test de rendu** (quarto 1.9.38, binaire RStudio — le quarto du PATH
est 1.8.26, trop ancien) : `pb-html` rend correctement (format résolu,
sass partagé + `pb.scss`, filtre wordcount, métadonnée `pb:` prise en
compte). ✅

**Clé de métadonnée actée** : le numéro de PB portera `pb:` dans
`_quarto.yml` (analogue à `wp:`), c’est ce que référencent les partials
(`$pb$`).

Note : la migration `crossref-*`/`pdf.annee`/`quarto-required` est
**sans objet** — on part de `wp`, déjà au schéma moderne.

**Réserves connues (non bloquantes) :** - `pb-typst` n’a pu être rendu
**que** dans le dépôt de dev, où il échoue sur un chemin d’image codé en
dur `/_extensions/ofce/ofce/img/…` (chemin *installé*, double
`ofce/ofce`). **Vérifié : `wp-typst` échoue à l’identique** dans le même
contexte → artefact de test dans le dépôt source, pas un défaut PB. Sera
validé nativement en Phase 3 (rendu dans un vrai dépôt PB installé). -
**Identité visuelle PB** (`pb.scss`) : hérite pour l’instant du look
`wp` ; raffinement visuel PB distinctif (couleurs/title-block récupérés
de `ofcepb.scss`) **différé** — éditorial, non bloquant. - Les
modifications sont **non commitées** dans `ofce-quarto-extensions`
(répertoire `_extensions/pb/` en `untracked`) — à commiter/pousser quand
tu valides.

### Phase 2 — Registre PB (ton point (ii)) — ✅ TERMINÉE (délégué Sonnet, vérifié)

Dépôt `OFCE/pb-registry` **créé** (local : `web/pb-registry`). ✅

Rempli sur le modèle de `wp-registry` (**délégué Sonnet, vérifié par
moi**) : `pb/index.json` = `{"years": []}` ; `pb/registry.schema.json`
(racine `pb`, champ entrée `pb`, types `repo`/`pdf-only`, pattern pdf
`^pdf/pbrief/.+\.pdf$`, `source-repo` `^OFCE/.+`) ;
`.github/workflows/validate-registry.yml` (`pb/`, `.pb[]`) ;
`.github/CODEOWNERS` (`/pb/`) ; README PB. Contrôles JSON/schema OK,
aucune trace WP. **Non commité** (revue utilisateur). ✅

**\[admin GitHub, hors code\]** activer sur `pb-registry` branch
protection + required status check (job « Validate registry.json ») +
autorisation de push de branches pour les membres `ofce` — comme
`wp-registry`. Non automatisable ici.

Note : les `pb/{annee}.json` seront créés à la 1re demande par
[`pb_registry_request()`](https://ofceweb.github.io/ofceweb/reference/pb_registry_request.md)
(Phase 3).

### Phase 3 — Fonctions ofceweb (ton point (iii)) — ✅ TERMINÉE (code)

Répartition : **moi** = forte logique ; **Sonnet** = clones mécaniques
(fichiers disjoints). - \[x\] `inst/setup_pb/` gabarits +
`inst/setup_pb/workflows/` (5 workflows ; anti-collision `/pb/`,
`render_pb`, secrets FTP réutilisés). **\[Sonnet\]** ✅ - \[x\]
`R/pb_registry_sync.R` : `fetch_pb_index/year/entries` +
`sync_pb_registry_state()` (sous-dossier `pb/`, clé JSON `pb`, filet de
sécurité réseau). **\[moi\]** ✅ - \[x\]
[`pb_manifest()`](https://ofceweb.github.io/ofceweb/reference/pb_manifest.md)
— URL/chemin/PDF PB (`www.ofce.fr/pb/…`, `OFCEPB…`), `source-repo`.
**\[Sonnet\]** ✅ - \[x\]
[`pb_registry_request()`](https://ofceweb.github.io/ofceweb/reference/pb_registry_request.md)
— cible `ofce/pb-registry`, `pb/{annee}.json`, branche
`request/{annee}/{pb}`, réutilise
`.registry_gh_token()`/`fetch_pb_year()`. **\[Sonnet\]** ✅ - \[x\]
[`check_pb()`](https://ofceweb.github.io/ofceweb/reference/check_pb.md)
(+ `print_pb_diags`) — formats `pb-*`, `ofce_pb`, nommage
`pb-{initiale}-{court}`, site-path `{annee}/{pb}`. **\[Sonnet\]** ✅ -
\[x\]
[`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)
— clone de
[`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
: flag `ofce_pb`, garde-fous de type (refuse `ofce_wp`/`ofce_prev`),
valeurs dérivées PB, `sync_pb_registry_state()`, extension
`_extensions/ofce/pb`. **\[moi\]** ✅ - \[x\]
[`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md)
(+
[`publish_pb()`](https://ofceweb.github.io/ofceweb/reference/publish_pb.md))
— orchestration (helpers génériques + `check_pb`/`pb_manifest`), `...`
tolérant pour l’appel CI `render_pb(check_repo=FALSE)`. **\[moi\]** ✅ -
\[x\]
[`deploy_pb()`](https://ofceweb.github.io/ofceweb/reference/deploy_pb.md)
— routage identique, URL production `www.ofce.fr/pb/{annee}/{pb}`,
[`push_pb_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_pb_redirect.md).
**\[moi\]** ✅ - \[x\] Conditionnels :
[`complete_pb_yaml()`](https://ofceweb.github.io/ofceweb/reference/complete_pb_yaml.md),
[`pb_version_up()`](https://ofceweb.github.io/ofceweb/reference/pb_version_up.md),
[`push_pb_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_pb_redirect.md)
(`R/pb_redirect.R`). **\[moi\]** ✅ - \[x\] **PAS** de `encrypt_pb()` —
réutilise
[`encrypt_site()`](https://ofceweb.github.io/ofceweb/reference/encrypt_site.md).
✅ - \[x\] Exports ajoutés à `NAMESPACE` à la main (setup_pb, render_pb,
publish_pb, deploy_pb, check_pb, pb_registry_request, pb_version_up). ✅

**Validation (statique + assemblage) :** tous les fichiers parsent ;
**[`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html)
réussit** (assemblage complet du namespace) ; aucune fonction indéfinie,
aucun doublon (`%||%`, `.registry_gh_token`, `increment_version_str`
réutilisés, jamais redéfinis) ; toutes les fonctions PB
exportées/internes présentes dans le namespace.

**Réserves connues (non bloquantes) :** - **`gert` 2.3.1 installé \<
`>= 2.4.1` requis par DESCRIPTION** : bloque `roxygenise()`/`load_all()`
dans cet environnement (verrou d’env préexistant, sans rapport avec le
code PB — la validation ci-dessus a été faite en relâchant
*temporairement* la contrainte, DESCRIPTION restaurée). Idem roxygen2
8.0.0 \< 8.1.0. - **Doc roxygen non régénérée** : les pages `man/*.Rd`
des fonctions PB ne sont pas encore générées (roxygen n’a pas pu
tourner). → **à faire côté utilisateur** : mettre à jour `gert` (≥
2.4.1) et `roxygen2` (≥ 8.1.0) puis lancer `devtools::document()`
(régénère NAMESPACE — cohérent avec mes ajouts manuels — et crée les
`man/*.Rd`). - **Aucun test runtime réel** (exécuter
[`setup_pb()`](https://ofceweb.github.io/ofceweb/reference/setup_pb.md)/[`render_pb()`](https://ofceweb.github.io/ofceweb/reference/render_pb.md)
sur un dépôt) ni rendu `pb-typst` installé : relève de la Phase 4
(pilote). - Rien n’est commité dans `ofceweb` (nouveaux `R/*.R`,
`inst/setup_pb/`, `NAMESPACE` modifiés).

### Phase 4 — Intégration & doc

Mettre à jour `NAMESPACE`/`@export`, `_pkgdown.yml`, la doc roxygen
(`@seealso` croisés).

Tester le cycle complet sur un dépôt PB pilote (`setup_pb` →
`pb_registry_request` → merge → `setup_pb` → `render_pb` → `deploy_pb`).

**Hors périmètre** (§4.2) : collecte automatique webhome
(registre/manifestes → `policy.qmd`). À traiter comme un chantier séparé
commun WP+PB, ultérieurement.

## 7. Risques / points de vigilance

- Ne **pas** refactorer
  [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  en moteur générique dans un premier temps : trop de logique défensive
  subtile, risque de régression sur les WP en production. Dupliquer
  d’abord (comme `prev_*`), factoriser plus tard si la maintenance le
  justifie.
- Bien **isoler les URL/chemins FTP** WP vs PB : une collision de
  `server-dir` écraserait des publications. La vérification
  anti-collision du workflow FTP doit pointer sur le manifeste PB
  (`www.ofce.fr/pb/...` et non `/wp/...`).
- **Secrets/variables FTP GitHub** : les WP utilisent
  `WP_USER`/`WP_PASSWORD` (prod) et `STAGING_USER`/`STAGING_PASSWORD`
  (staging), plus les variables `FTP_SERVER_DIR`/
  `FTP_STAGING_DIR`/`FTP_REDIRECT_DIR`. Décider si les PB
  **réutilisent** les mêmes identifiants FTP (probable, même serveur) ou
  en ont de dédiés — impacte les gabarits de workflows `setup_pb`.
- Le mapping nom d’extension → format est **confirmé**
  (`_extensions/ofce/pb` → `pb-html`) : plus un risque.
