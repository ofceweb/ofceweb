## ofceweb v0.10.8

### `stage-target: auto` persiste désormais tel quel dans `_quarto.yml`

* Corrige un bug dans `setup_wp()` : `stage-target: auto` était résolu une
  fois pour toutes en `"gh-pages"` ou `"ftp"` selon le propriétaire GitHub
  *au moment de l'appel de `setup_wp()`*, puis cette valeur concrète était
  réécrite dans `_quarto.yml` — `"auto"` ne persistait donc jamais. Un
  transfert ultérieur du dépôt vers (ou hors de) l'organisation `ofce`
  n'était alors plus pris en compte sans relancer `setup_wp()`.
* `setup_wp()` écrit désormais `"auto"` littéralement dans `_quarto.yml`
  lorsque c'est la valeur effective (par défaut pour un nouveau dépôt, ou
  déjà présente telle quelle dans un `_quarto.yml` existant) ; les valeurs
  explicites `"gh-pages"`/`"ftp"`/`"ofce"` restent, elles, écrites telles
  quelles (`"ofce"` normalisé en `"ftp"`).
* `deploy_wp()` réévalue maintenant `"auto"` à **chaque déploiement**, selon
  le propriétaire GitHub actuel du dépôt (nouvelle fonction interne
  partagée `detect_gh_owner()`) — au lieu de le lire comme une valeur déjà
  figée. Un transfert de propriété vers `ofce` (ou une fork/duplication
  vers un compte personnel) change donc la destination du déploiement dès
  le prochain `deploy_wp()`, sans repasser par `setup_wp()` et sans
  modifier les workflows GitHub Actions.
* `setup_wp()` continue de calculer une valeur résolue concrète
  (`gh-pages`/`ftp`) pour ses propres besoins internes (URL de brouillon
  `website.site-url`, résumé affiché en console), mais celle-ci n'est
  jamais celle persistée dans `_quarto.yml` quand la valeur effective est
  `"auto"`.

### `setup_wp()` : correction de l'URL GitHub Pages / `stage-target` sans remote

* Corrige un bug dans `setup_wp()` : en l'absence de remote git `origin`
  (nouveau dépôt local, pas encore poussé), la fonction présumait
  silencieusement que le dépôt appartiendrait à l'organisation `ofce`. Deux
  conséquences erronées en découlaient :
  - `stage-target: auto` se résolvait à tort en `"ftp"` (staging OFCE) au
    lieu de `"gh-pages"`, pour n'importe quel nouveau dépôt local sans
    remote, qu'il soit destiné à `ofce` ou non ;
  - l'URL de brouillon `website.site-url` calculée pour `gh-pages` était
    fixée à `https://ofce.github.io/{repo}/`, ce qui est faux dès que le
    dépôt n'appartient pas à l'organisation OFCE.
* La résolution de repli utilise désormais le compte `gh` authentifié
  (`check_gh_login()`) comme meilleure estimation du propriétaire GitHub —
  au lieu de présumer `ofce`. Si ni remote ni compte `gh` authentifié ne
  sont disponibles, `website.site-url` n'est plus fabriquée à tort :
  `setup_wp()` laisse le champ inchangé et affiche un avertissement
  invitant à relancer la fonction une fois un remote `origin` ajouté (ou
  `gh auth login` effectué).
* Pour rappel, la résolution `stage-target: "auto"` (`"ftp"` pour
  l'organisation `ofce`, `"gh-pages"` sinon), ainsi que l'alias hérité
  `"ofce"` pour `"ftp"`, existaient déjà (`resolve_stage_target()`) — ce
  correctif ne fait que réparer leur résolution en l'absence de remote,
  qui n'avait jusqu'ici aucune couverture de tests.

### `wp_registry_request()` : ouverture de PR via fork personnel

* `wp_registry_request()` n'exige plus que l'auteur·e soit
  collaborateur·rice avec droit d'écriture sur `ofceweb/wp-registry` :
  la fonction crée (ou réutilise) désormais un **fork personnel** du
  registre sous le compte GitHub associé au token utilisé, y pousse la
  branche `request/{annee}/{wp}`, puis ouvre une pull request
  **cross-repo** (`head = "{login}:{branche}"`) contre
  `ofceweb/wp-registry`. Auparavant, la fonction poussait directement sur
  `ofceweb/wp-registry`, ce qui échouait (`git push`, code 128 — *not
  allowed to push*) pour tout·e auteur·e membre de l'organisation `ofce`
  mais non ajouté·e comme collaborateur·rice sur le dépôt registre.
* Ce changement aligne le comportement de la fonction sur le modèle de
  gouvernance documenté (`note-equipe-publication-wp.md`) : seule la
  **fusion** d'une PR dans `wp-registry` doit être protégée (branch
  protection + `CODEOWNERS`), pas l'ouverture d'une PR.
* Le login GitHub associé au token (`DEPLOY_PAT` ou identifiants
  `gitcreds`) devient obligatoire pour ouvrir une PR (le fork vit sous ce
  compte) ; il reste optionnel en mode `dry_run`, qui ne fait aucun appel
  réseau vers le fork.
* La sortie (`stdout`/`stderr`) de l'étape `git push` est désormais
  capturée et affichée en cas d'échec, au lieu d'être silencieusement
  ignorée — pour diagnostiquer plus facilement une future erreur de push.
* Documentation : nouvelle section `@details` dans `wp_registry_request()`
  décrivant le flux fork → push → PR cross-repo, et paragraphe
  correspondant ajouté à la vignette `working-papers.Rmd`.

## ofceweb v0.10.7

### Compteur de déploiement dans le bandeau « Version préliminaire »

* Les workflows de staging (`ftp_deploy_staging.yml` pour les prévisions,
  `ftp_stage.yml` pour les WPs) écrivent désormais `push-count.json`
  (`{"count": <github.run_number>, ...}`) à la racine du site déployé, à
  chaque exécution.
* Le bandeau « Version préliminaire ($version$) » (extensions `ofce` et
  `wp` de `ofce-quarto-extensions`) lit ce fichier côté client et complète
  le bandeau avec « · déploiement n°N » — sans changer le numéro de
  `version` ni le `site-path` (l'URL staging reste stable). Absent du
  fichier (ex. pages publiées, pas de bandeau), le bandeau reste inchangé.
* Nécessite une mise à jour des extensions Quarto OFCE
  (`ofce::setup_quarto()` / relancer `setup_prev()`/`setup_wp()`) et un
  nouveau rendu pour prendre effet.

### Redirection stable pour les prévisions en staging

* Nouvelle fonction `push_prev_staging_redirect()` : génère et déploie une page
  de redirection stable pour les prévisions en staging (`staging.ofce.fr/{prev_id}/`),
  analogues aux redirections existantes pour les WP en publication
  (`www.ofce.fr/wp/{annee}/{wp}/`) et les prévisions publiées
  (`www.ofce.fr/prev/derniere/`). Cela permet une URL stable quand plusieurs
  versions de la prévision existent en staging (v0, v1, v2, …), toujours
  pointant vers la dernière.
* Nouveau workflow `ftp_redirect_staging.yml` : déploie la redirection
  staging via FTP sur la branche `site-staging-redirect` (séparée du contenu
  en `site-staging`).
* `stage_prev()` appelle automatiquement `push_prev_staging_redirect()` après
  déploiement (paramètre `trigger_staging_redirect = TRUE`), sauf si l'utilisateur
  passe `FALSE`. Cela maintient l'URL stable à jour sans manipulation manuelle.
* Mise à jour de `AGENTS.md` : documentation de `FTP_STAGING_REDIRECT_DIR`,
  branche `site-staging-redirect` et architecture des redirections staging.

### Correctif : redirection staging auto-référente + URL doublée sur dépôts non migrés

* `push_prev_staging_redirect()` générait une page de redirection
  auto-référente : la cible du méta-refresh/lien était calculée comme le
  répertoire **parent** (`/prev2609/`), identique à l'emplacement de la page
  de redirection elle-même — la redirection ne menait donc jamais à la
  version publiée. Corrigé pour utiliser une cible **relative** vers le
  sous-dossier de version (`v{N}/`, comme pour les WP via
  `push_wp_redirect()`), l'URL canonique restant absolue
  (`https://staging.ofce.fr/{prev_id}/v{N}/`).
* `push_prev_staging_redirect()` et le message affiché par `stage_prev()`
  tolèrent désormais un préfixe `staging/` périmé dans `site-path` de
  `_quarto-staging.yml` (dépôts non re-migrés depuis le renommage de domaine
  en v0.10.5, cf. plus bas) : le préfixe est ignoré pour le calcul de l'URL
  (au lieu de produire `staging.ofce.fr/staging/{prev_id}/...`), avec un
  avertissement invitant à relancer `setup_prev()` pour corriger le fichier
  de façon permanente. `check_prev()` continue de signaler ce préfixe comme
  une erreur bloquante (`staging/site-path`).

## ofceweb v0.10.5

### Domaine de staging OFCE renommé en `staging.ofce.fr`

* L'URL publique de l'espace de staging FTP OFCE change de
  `www.ofce.fr/staging/{repo}/{version}/` à
  `staging.ofce.fr/{repo}/{version}/` (le segment `staging/` est absorbé par
  le sous-domaine). Impacte les WP en brouillon avec `stage-target: "ftp"`
  (`setup_wp()`, `deploy_wp()`, `wp_manifest()`) et les prévisions en
  staging (`setup_prev()`, `render_prev()`/`stage_prev()`,
  `prev_version_up()`).
* Pour les prévisions, `website.site-path` de `_quarto-staging.yml` perd son
  préfixe `staging/` (`prev{YYMM}/v{N}` au lieu de `staging/prev{YYMM}/v{N}`)
  et `website.site-url` est désormais explicitement fixé à
  `https://staging.ofce.fr/` (auparavant hérité du `site-url` partagé avec
  le profil `publish`). `check_prev()` valide ces deux champs en
  conséquence (nouvelle vérification `staging/site-url`, regex `site-path`
  mise à jour). Le chemin FTP effectif (`FTP_STAGING_DIR`, chroot
  `www/staging/{repo}/{version}/`) est inchangé — seule l'URL publique
  bouge.
* correction incidente de `wp_manifest()` : l'URL de staging calculée pour
  le `manifest.json` utilisait par erreur `www.ofce.fr/stage/wp/{repo}/`
  (incohérent avec le reste du package) — désormais alignée sur
  `staging.ofce.fr/{repo}/{version}/`.

## ofceweb v0.10.4

### `render_site()` / `render_wp()` — suppression du patch des hashes Bootstrap

* Suppression de l'étape `patch_sitelibs_hashes()` (renommage des fichiers
  hashés de `_site/site_libs/` vers des noms stables et réécriture des
  références HTML correspondantes) dans `render_site()` et `render_wp()` :
  ce patch provoquait un bug pernicieux et n'est plus nécessaire.
  `render_prev()` n'a jamais eu cette étape. La vignette
  `build-a-site.Rmd`/`working-papers.Rmd` et `work/setup_site.md` sont mis
  à jour en conséquence.

### `setup_wp()` — suppression des arguments `wp`/`annee`/`website_title`

* `wp` et `annee` ne sont plus des arguments de `setup_wp()` : ils sont
  désormais toujours lus depuis un `_quarto.yml` existant, ou écrasés par
  une entrée confirmée du registre central (`ofceweb/wp-registry`), jamais
  choisis librement par l'appelant. Pour changer le numéro d'un WP déjà
  publié, éditer directement `_quarto.yml` (ou passer par le registre).
* `website_title` disparaît également : le titre affiché dans le résumé de
  fin d'appel est toujours déduit de `index.qmd` (ou du nom du dépôt
  GitHub), comme c'était déjà le cas par défaut.

## ofceweb v0.10.3

### Consultation du registre central déplacée de `render_wp()` vers `setup_wp()`/`publish_wp()`

* La consultation d'`ofceweb/wp-registry` et la synchronisation de
  `draft`/`wp`/`annee` dans `_quarto.yml` (auparavant faites dans
  `render_wp()`, juste avant le rendu) sont désormais faites par
  `setup_wp()` — `_quarto.yml` est donc déjà correct et cohérent
  (`draft`, `wp`, `annee`, `site-path`, `citation.*`) juste après
  `setup_wp()`, sans attendre un rendu. Logique extraite dans le helper
  interne partagé `sync_wp_registry_state()`
  (`R/wp_registry_sync.R`).

* `publish_wp()` rafraîchit à nouveau l'état du registre juste avant
  d'appeler `render_wp()`, pour rattraper un enregistrement survenu
  depuis le dernier `setup_wp()` (PR `wp-registry` fusionnée). Ce
  rafraîchissement ne recalcule que `draft`/`wp`/`annee` ; si le numéro
  WP change à cette étape, un avertissement invite à relancer
  `setup_wp()` pour recalculer les champs dérivés (`site-path`,
  `citation.*`, `FTP_SERVER_DIR`).

* `render_wp()` ne consulte plus le registre : il lit `draft`
  directement dans `_quarto.yml` (déjà synchronisé par `setup_wp()`/
  `publish_wp()`), ce qui le rend plus rapide et indépendant du
  réseau — mais un `render_wp()` isolé (sans `setup_wp()`/
  `publish_wp()` récent) ne détecte plus un changement d'état du
  registre.

* **Priorité** : quand le dépôt a une entrée confirmée dans le
  registre, celle-ci l'emporte toujours sur les arguments
  `wp=`/`annee=` passés à `setup_wp()`. Ces arguments ne restent
  utiles que pour un dépôt pas encore enregistré.

* **Comportement changé en cas d'échec réseau** : auparavant, un
  registre inaccessible forçait `draft: true` et effaçait `wp`/`annee`
  — même pour un WP déjà publié. La consultation est désormais
  fail-soft : en cas d'échec, `draft`/`wp`/`annee` restent inchangés
  dans `_quarto.yml`, avec un avertissement invitant à réessayer.

### `render_prev()` / `setup_prev()` — alignement sur le pattern `wp`

* Paramètre `check_repo` supprimé de `render_prev()`, `stage_prev()`,
  `publish_prev()` et `render_prev_publish()` (et l'appel à
  `check_repo_status()`) : le rendu Quarto ne dépend pas de l'état du dépôt
  git, comme pour `render_wp()`.

* Nouveau diagnostic de connexion GitHub (`gh::gh("GET /user")`, factorisé
  dans le helper interne `check_gh_login()` partagé avec `check_wp()`) :
  appelé désormais par `setup_prev()`, `stage_prev()` et `publish_prev()`
  pour avertir tôt si l'utilisateur n'est pas authentifié auprès de GitHub
  (opérations staging/registry indisponibles sans connexion).

* `check_prev()` : même diagnostic `gh:login` que `check_wp()` (même
  helper `check_gh_login()`), pour une parité complète des vérifications
  wp / prev.

### Bandeau « Version provisoire » — persistance de `draft`

* `render_wp()` : l'état `stage` déterminé depuis le registre central
  n'est plus injecté comme métadonnée éphémère à
  `quarto::quarto_render(metadata = list(stage = stage))`, mais persisté
  comme clé `draft` dans `_quarto.yml` avant le rendu — lue comme
  n'importe quelle autre métadonnée par les extensions
  `ofce-quarto-extensions` pour afficher le bandeau « Version provisoire —
  non publiée » dans le HTML, le PDF et le Typst produits. Le gabarit
  `inst/setup_wp/_quarto.yml` déclare désormais `draft: true` par défaut.

* `setup_prev()` : même bandeau pour les prévisions, mais porté
  statiquement par les profils plutôt que calculé dynamiquement — les
  gabarits `inst/setup_prev/_quarto-staging.yml` et `_quarto-publish.yml`
  déclarent respectivement `draft: true` et `draft: false`.

### `project.type` et registre central

* `setup_wp()` forçait `project.type: website` au lieu de `project.type:
  ofce-website` (gabarit `inst/setup_wp/_quarto.yml` inclus) — corrigé.
  `check_wp()` gagne un nouveau diagnostic `project.type` (warning si la
  valeur diffère de `ofce-website`, suggérant de relancer `setup_wp()`),
  identique à celui déjà présent dans `check_prev()`.

* `render_wp()` synchronise désormais automatiquement `wp`/`annee` dans
  `_quarto.yml` d'après l'entrée trouvée dans le registre central
  (`ofceweb/wp-registry`) : écrits depuis l'entrée quand le dépôt est
  enregistré, effacés sinon (registre inaccessible ou dépôt non enregistré).
  Ces clés ne sont plus jamais laissées à la charge de l'auteur·e — leur
  absence dans `_quarto.yml` signale sans ambiguïté l'état staging.
  Corrige au passage un contrôle de la synchronisation `FTP_SERVER_DIR` qui
  relisait la valeur de `wp` d'avant cette synchronisation.

* `wp_registry_request()` : le contrôle de l'organisation du dépôt (`ofce`)
  était sensible à la casse et rejetait un remote orthographié
  `OFCE/...` — comparaison désormais insensible à la casse (`tolower()`).
  L'entrée JSON proposée pour la pull request s'affichait aussi mal (les
  accolades littérales du JSON pretty-printé étaient interprétées comme
  des expressions glue par `cli::cli_text()`) — remplacé par
  `cli::cli_verbatim()`.

### `website.draft-mode` — toujours resynchronisé

* `setup_wp()`, `setup_prev()` et `setup_site()` forcent désormais
  `website.draft-mode` à chaque appel, même sur un `_quarto.yml` existant
  créé avant l'introduction de cette clé : `"visible"` pour les WPs et les
  prévisions, `"gone"` pour les sites génériques.

### `website.title` — clé supprimée

* `setup_wp()` et `setup_site()` n'écrivent plus jamais la clé
  `website.title` dans `_quarto.yml` (le titre calculé depuis
  `website_title`/`index.qmd`/nom du dépôt ne sert plus qu'au résumé affiché
  en fin d'appel). Le gabarit `inst/setup_prev/_quarto.yml` et
  `inst/setup_site/_quarto.yml`, qui la codaient en dur, sont aussi corrigés
  (`inst/setup_wp/_quarto.yml` ne l'avait jamais eue).

* `update_navbar()` supprime désormais `website.title` si la clé est encore
  présente (dépôt initialisé avant ce changement), en plus de synchroniser
  les menus depuis `navbar.yml`.

* `site_redirect.R` : la page de redirection utilisait `website.title` comme
  titre HTML ; retombe désormais sur la clé `title` de premier niveau en
  priorité (présente pour les WPs), avec `website.title` en second repli
  pour les dépôts pas encore nettoyés par `update_navbar()`.

### Workflows de staging — corrections

* `ftp_deploy_staging.yml` (gabarit `setup_prev`) : le secret GitHub Actions
  utilisé pour l'utilisateur FTP de staging était mal nommé
  (`STAGING_USERNAME` au lieu de `STAGING_USER`), provoquant l'échec de
  l'authentification FTP en CI. Corrigé.

* `ftp_deploy_staging.yml` (gabarit `setup_prev`) et `ftp_stage.yml`
  (gabarit `setup_wp`) : la commande `staticrypt` ciblait `./` (le dossier
  courant lui-même) au lieu de `./*` (son contenu). Corrigé.

### `setup_wp()` / `setup_prev()` — workflows toujours mis à jour

* Workflows GitHub Actions (`.github/workflows/`) : changement de politique.
  Auparavant, `setup_wp()` ne créait les workflows que s'ils n'existaient pas ;
  `setup_prev()` les remplaçait toujours. Désormais les deux fonctions
  **forcent la mise à jour** à chaque appel. Les workflows sont la source de
  vérité du package et ne doivent pas être modifiés manuellement. Cela
  garantit que les corrections et améliorations de templates (comme le fix
  `STAGING_USERNAME` → `STAGING_USER` ci-dessus) sont propagées
  automatiquement à l'appel suivant de `setup_wp()` ou `setup_prev()`.

* Docstring de `setup_wp()` clarifiée : explique désormais que les fichiers
  utilisateur (`.qmd`, YAML) sont non-destructifs, mais les workflows
  (gabarits du package) sont toujours remplacés.
  
### divers

* plus d'appel à `future::plan()` dans `render()`

## ofceweb v0.10.0

### Registre central — nouvelle disposition `wp/` (restructuration en 3 étapes)

`ofceweb/wp-registry` a été restructuré : `registry.json` (racine, un seul
fichier) devient `wp/index.json` (liste des années) + `wp/{annee}.json` (un
fichier par année), en préparation de futurs registres pour d'autres types
de documents (`prev/`, `rapports/`, ...). Cette version est l'**étape 2/3**
de la migration (voir PR [#7](https://github.com/ofceweb/wp-registry/pull/7)
pour l'étape 1) : `render_wp()` et `wp_registry_request()` lisent désormais
exclusivement `wp/*.json`.

* `render_wp()` : la consultation du registre télécharge `wp/index.json`,
  puis chaque `wp/{année}.json` listé, et fusionne les entrées obtenues
  (au lieu de télécharger un unique `registry.json`). Une année
  individuellement illisible est ignorée avec un avertissement, sans
  bloquer la recherche dans les autres années. Le repli sûr en cas de
  registre inaccessible (`stage = TRUE`) est inchangé.

* `wp_registry_request()` : l'auto-numérotation et la vérification de
  collision ne lisent plus que `wp/{annee}.json` (au lieu de tout le
  registre). Si c'est la première demande pour une année donnée (fichier
  absent), la fonction crée `wp/{annee}.json` **et** met à jour
  `wp/index.json` dans le même commit, pour que `render_wp()` sache
  immédiatement aller le chercher.

* Le champ `annee` est conservé dans chaque entrée malgré la redondance
  avec le nom de fichier (une entrée copiée ou affichée isolément reste
  ainsi auto-suffisante) ; la CI de `wp-registry` vérifie cette cohérence.

* **Avertissement pour les versions antérieures d'`ofceweb`** : à l'issue
  de l'étape 3 (suppression de `registry.json`/`registry.schema.json` à la
  racine de `wp-registry`), toute version d'`ofceweb` antérieure à
  `0.10.0` ne trouvera plus le registre et basculera silencieusement en
  `stage = TRUE` — un WP déjà publié réafficherait alors le bandeau
  « Version provisoire » (comportement de repli sûr mais inattendu pour un
  document déjà publié). Mettre à jour `ofceweb` avant que l'étape 3 ne
  soit fusionnée.

## ofceweb v0.9.4

### `setup_wp()` — refonte du routage et des URLs

* Nouveau paramètre `stage_target` (`"gh-pages"` ou `"ftp"`) et nouvelle clé
  YAML `stage-target` : source de vérité pour la destination de déploiement des
  WPs non encore publiés. Valeur par défaut `gh-pages` dans le gabarit.
  `setup_wp()` force-patche `stage-target` à chaque appel (comme `ofce_wp`).

* `website.site-url` désormais toujours recalculé selon la cible effective :
  `https://www.ofce.fr/` (WP publié), `https://{org}.github.io/{repo}/`
  (brouillon gh-pages), `https://www.ofce.fr/staging/{repo}/[{version}/]`
  (staging FTP). Le champ `website.site-path` est supprimé pour les brouillons.

* `website.repo-url` désormais toujours force-patché depuis le remote git
  (`gh_org`/`repo_name`), sans condition sur la présence du remote.

* `project.type: website` désormais toujours forcé (comme `ofce_wp: true`).

* Gabarit `_quarto.yml` : section `navbar` supprimée (gérée par
  `update_navbar()`) ; `stage-target: gh-pages` ajouté dans la section
  éditable.

### `check_wp()` — vérification de la connexion GitHub

* Nouveau diagnostic `gh:login` : appelle `gh::gh("GET /user")` et affiche le
  login GitHub de l'utilisateur (`ok`) ou un avertissement non bloquant si
  aucune authentification n'est détectée (`warning`). Les opérations staging et
  registry sont indisponibles sans connexion.

### `render_wp()` — simplification

* Paramètre `check_repo` supprimé (et l'appel à `check_repo_status()`) : le
  rendu Quarto ne dépend pas de l'état du dépôt git.

* Avertissement « dépôt sous {owner}, pas sous ofce » supprimé (couvert par
  `setup_wp()` et `check_wp()`).

* `git_status()` supprimé de la fin de la fonction ; retour `invisible(NULL)`
  à la place de `invisible(status)`.

### `deploy_wp()` — routage depuis le YAML

* Paramètre `target` supprimé. La cible effective est lue depuis
  `yml[["stage-target"]]` (avec fallback `"gh-pages"`). Le registre central
  reste prioritaire : `stage = FALSE` → FTP production quoi qu'il arrive.

* URL de staging corrigée : `https://www.ofce.fr/staging/{repo}/{version}/`
  (était `stage/wp/`, sans `index.html`).

* URL de production : `index.html` supprimé, zéro-padding (`%03d`) supprimé.

### FTP staging — chemin simplifié

* `FTP_STAGING_DIR` passe de `stage/wp/{repo}/{version}/` à `{repo}/{version}/`.
  L'utilisateur FTP de staging a un chroot sur `www/staging/` — chemin effectif
  inchangé sur le serveur (`www/staging/{repo}/{version}/`).

* Message de résumé `setup_wp()` : affiche désormais l'URL publique complète
  `https://www.ofce.fr/staging/{staging_dir}` plutôt que la variable brute.

## ofceweb v0.9.3

### Registre central WP (`ofceweb/wp-registry`) — nouveau

Nouveau mécanisme d'autorisation de publication : un dépôt doit être enregistré
dans le registre central avant de pouvoir publier sur le chemin FTP numéroté.
Cela ferme deux failles de sécurité de la Phase 1 (contournement via
`custom_version`, absence d'autorisation préalable).

* `wp_registry_request()` — nouvelle fonction exportée. Résout
  `{annee, wp, source-repo}` pour le dépôt local, vérifie l'organisation
  (`ofce` requis), auto-numérote le WP si `wp = NULL` (max existant + 1 pour
  l'année, tous types confondus), contrôle les collisions si `wp` est fourni
  explicitement, résout `contact` depuis `git config user.email`, clone
  `ofceweb/wp-registry`, pousse une branche `request/{annee}/{wp}` et ouvre une
  PR via l'API GitHub. Fire-and-forget : un·e admin fusionne la PR, puis
  `render_wp()` détecte automatiquement l'enregistrement. Paramètre `dry_run`
  pour inspecter l'entrée sans ouvrir de PR.

* `render_wp()` — nouvelle étape 2.5 : consultation du registre central avant
  le rendu Quarto. Détermine `stage = TRUE` (dépôt non encore enregistré →
  staging FTP) ou `stage = FALSE` (enregistré → publication numérotée).
  Injecte `stage` comme métadonnée Quarto (pour le banner « Version provisoire »
  dans les extensions `ofce-quarto-extensions`). Passe `stage` à
  `wp_manifest()`. Synchronise `FTP_SERVER_DIR` uniquement si `stage = FALSE`.
  Affiche une notice si le dépôt n'est pas sous l'organisation `ofce`.

* `wp_manifest()` — nouveau paramètre `stage` (défaut `NULL` pour la
  rétrocompatibilité). Écrit le champ `stage` dans `manifest.json`. Adapte le
  champ `url` : URL FTP production (`stage = FALSE`), URL FTP staging
  `stage/wp/{repo}/{version}/` (`stage = TRUE`), URL GitHub Pages
  (`stage = NULL` sans `wp`).

* `deploy_wp()` — routage à trois branches basé sur `manifest$stage` :
  `FALSE` → FTP production (`ftp_deploy.yml`, branche `site-deploy`, inchangé) ;
  `TRUE` → FTP staging (`ftp_stage.yml`, branche `site-staging`, nouveau) ;
  `NULL` → GitHub Pages (`quarto publish gh-pages`, inchangé). Affiche une
  suggestion `wp_registry_request()` si le manifeste est présent mais sans
  champ `stage`.

### Staging FTP versionnée (nouveau)

* `inst/setup_wp/workflows/ftp_stage.yml` — nouveau workflow copié par
  `setup_wp()`. Déclenché sur push vers `site-staging` ou `workflow_dispatch`.
  Utilise les secrets `STAGING_USERNAME` / `STAGING_PASSWORD` (chroot `stage/`
  côté serveur FTP — aucun risque d'écriture sur les chemins de production) et
  la variable `FTP_STAGING_DIR`. Chiffrement staticrypt optionnel. Conserve
  l'état FTP incrémental sur la branche `site-staging`.

* `setup_wp()` — nouvelle section 12b : positionne toujours la variable GitHub
  `FTP_STAGING_DIR` à `stage/wp/{repo}/{version}/`, indépendamment du numéro
  WP. Affiche une notice informative si le dépôt n'est pas sous l'organisation
  `ofce` (le rendu fonctionne, mais la publication FTP sera bloquée).

### Documentation

* La vignette `vignettes/working-papers.Rmd` doit être mise à jour pour
  décrire le nouveau flux de publication : `wp_registry_request()` →
  approbation admin → `render_wp()` (détecte l'enregistrement) →
  `deploy_wp()` (route automatiquement vers staging ou production).
  Le fonctionnement en deux temps (staging FTP avant numérotation définitive)
  et les URLs de staging (`stage/wp/{repo}/{version}/`) doivent y être
  documentés.

### Contrôles et diagnostics

* `check_wp()` — suppression du contrôle d'appartenance à l'organisation `ofce`
  (redondant : l'enregistrement dans le registre implique une vérification
  admin, et l'absence des secrets FTP bloque naturellement la publication hors
  `ofce`).
* `check_wp()` — le champ `citation` n'est plus un bloquant. En mode staging
  (`wp` absent), le contrôle est ignoré entièrement. Quand `wp` est présent,
  l'absence de `citation` génère un avertissement (relancer `setup_wp()`) mais
  ne bloque pas le rendu — `citation` est calculé automatiquement par
  `setup_wp()` dès que `annee`/`wp` sont fournis.
* `check_wp()` — tous les contrôles de `site-path` (absence, format incorrect,
  incohérence avec `annee`, incohérence avec `wp`, incohérence avec `version`)
  passent de `"error"` à `"warning"`. `site-path` est entièrement dérivé par
  `setup_wp()` à partir de `annee` et `wp` — toute incohérence se corrige en
  relançant `setup_wp()`, jamais en bloquant le rendu.
* `check_wp()` — `annee` et `wp` absents passent de `"error"` à `"warning"`.
  `annee` est calculé par `setup_wp()` (année courante par défaut) ; `wp` est
  attribué par le registre central après `wp_registry_request()` — son absence
  est le cas normal en phase de staging. Un WP sans numéro peut désormais se
  rendre sans blocage.
* `check_repo_status()` — nouveau paramètre `timeout` (défaut : 10 s). Le
  `git fetch` tourne désormais dans un sous-processus `callr` afin que le
  délai soit respecté sur toutes les plateformes (Windows inclus). Si GitHub
  ne répond pas dans le délai imparti, la vérification est silencieusement
  ignorée avec un avertissement plutôt que de bloquer indéfiniment le rendu.

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
