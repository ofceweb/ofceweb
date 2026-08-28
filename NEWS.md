## ofceweb v0.10.2

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
