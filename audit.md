# Audit : PB multi-séries (ofce / ife / cepii)

*Audit réalisé le 2026-10-26. Aucune modification de code à ce stade.*

## Contexte

Les PB ne forment plus une seule liste. Il y a désormais une série par institut d'origine : `ofce`, `ife` et éventuellement `cepii`. Les séries `ofce` et `cepii` s'arrêtent ; elles sont remplacées par la série `ife`, dont la numérotation repart de 1.

## Résumé

Le changement est plus large que `pb_registry_request()`. Le numéro PB ne sert pas qu'au registre : il construit aussi les URL, le `site-path`, le dossier FTP, le nom du PDF, la citation et le contrôle anti-collision. Tout ce code suppose aujourd'hui une seule série numérotée sous `www.ofce.fr/pb/{N}/`. Une fois que la série IFE repartira de 1, **IFE n°1 et OFCE n°1 se disputeront le même chemin**.

## 0. État du registre (`web/wp-registry`)

- Les commits « creation instituts dans pb » et « mise à jour » sont sur la branche locale `new_pb`, qui a un commit d'avance sur `origin/new_pb`. Ils ne sont pas sur `main`. Or le package lit toujours `raw.githubusercontent.com/.../main/pb/...`.
- `pb/pb.json` existe toujours. `pb/ofce.json` en est une copie (140 à 157) avec un champ `institut` en plus. `pb/ife.json` est vide. Il n'y a pas de `cepii.json`.
- **`pb/registry.schema.json` rejette le nouveau champ** : il est en `additionalProperties: false` et `institut` n'y est pas déclaré. Une validation échouerait sur `ofce.json`.
- La CI `validate-registry.yml` ne vérifie que `wp/**`, et `CODEOWNERS` ne protège pas `/pb/`. Ce manque existait déjà, il devient plus gênant avec plusieurs fichiers.
- **Risque de transition** : un auteur qui garde l'ancienne version d'ofceweb continuera d'écrire dans `pb/pb.json` et prendra le n°158. Si on supprime `pb.json`, c'est pire : `fetch_pb_registry()` renvoie `NULL`, et l'ancien code propose le n°1 en recréant `pb.json`.

## 1. Code d'ofceweb touché

| Fichier | Ce qui est codé en dur aujourd'hui | Ce qu'il faut changer |
|---|---|---|
| `R/pb_registry_sync.R` | `fetch_pb_registry()` lit `pb/pb.json` | Lire `pb/{serie}.json` pour chaque série, fusionner et marquer chaque entrée avec sa série |
| `R/pb_registry_request.R` | `max(pb)+1` sur tout le fichier, écriture dans `pb.json`, branche `request/pb/{N}` | Calcul `max+1` **par série** ; écriture dans `pb/{serie}.json` avec le champ `institut` ; branche `request/pb/{serie}/{N}` ; collision vérifiée dans la série ; refus si la série est close ; refus si le dépôt est déjà enregistré (ce contrôle manque aujourd'hui) ; mettre à jour le titre et le corps de la PR |
| `sync_pb_registry_state()` (`R/pb_registry_sync.R`) | Ne compare que `source-repo` | Avertir si la série de l'entrée du registre diffère de l'`institut` local |
| `registry_diag_rows()` (`R/git_utils.R`) | Compare l'id seul (avec l'année pour les WP) | Pour les PB, comparer le couple (série, numéro) |
| `R/setup_pb.R` | `site-path = "{N}"`, `OFCEPB{N}.pdf`, `ofce-draft-…pdf`, `https://www.ofce.fr/pb/{N}/` pour la citation et `stable_url`, favicon `fofce-wp.png` | Tout dériver de la série. Pour un dépôt existant sans clé `institut` : écrire `ofce` par défaut, comme le fait l'extension Typst |
| `R/pb_manifest.R` | URL `www.ofce.fr/pb/%d/`, `pdf-path` `pb/%d/…` | Préfixer par la série et ajouter les champs `institut` / `serie` au manifeste |
| `R/deploy_pb.R` | `stable_url` / `final_url` | Même chose |
| `R/check_pb.R` | Structure du `site-path` `N[/vX]` | Nouvelle structure ; valider `institut` parmi les valeurs de l'extension ; signaler une série close |
| `R/complete_pb_yaml.R` | `container-title` « Policy Brief de l'OFCE », affiliation OFCE | Dériver de la série |
| `R/pb_redirect.R` | Rien en dur (part du `site-path`) | Seulement le titre HTML, « PB {N} » à remplacer par « PB IFE {N} » |
| `inst/setup_pb/workflows/ftp_deploy.yml` | Anti-collision sur `https://www.ofce.fr/pb/${FTP_SERVER_DIR}manifest.json` | Juste si le préfixe de série est dans `site-path` ; à revoir si la série IFE vit sur un autre domaine |
| `inst/setup_pb/_quarto.yml` | Le commentaire au-dessus de `institut:` parle de `draft` ; la citation donne en exemple `https://www.ofce.fr/pb/153/` | Mettre à jour |
| `vignettes/policy-briefs.Rmd`, `NEWS.md`, roxygen | « fichier plat unique `pb/pb.json` », « numérotation séquentielle depuis l'origine » | Réécrire |
| Tests (`test-pb_registry_request`, `test-pb_registry_sync`, `test-check_pb`, `test-pb_manifest`, `test-deploy_pb`, `test-pb_redirect`) | Simulent un registre plat | Fixtures multi-séries |

## 2. Problèmes déjà présents, mis en évidence par l'audit

1. **Le numéro n'arrive jamais dans le PDF.** L'extension `pb` (`ofce-quarto-extensions/_extensions/pb/typst/typst-show.typ`, `html/toc.html`) lit la variable `nb`, mais ofceweb n'écrit que `pb` et `citation.issue`. Le PDF publié affiche donc « Policy Brief IFE nº ?? ». Le `toc.html` affiche aussi encore l'ancien format `n°$annee$-$nb$`.
2. **`pb_version_up()` peut écraser le numéro.** Si le `site-path` n'a pas de segment de version (`"153"`), la fonction remplace le dernier segment et donne `"v1"`. Avec un préfixe de série, `"ife/12"` deviendrait `"ife/v1"`.
3. **Utilisateur FTP à vérifier.** `ftp_deploy.yml` côté PB se connecte avec `secrets.WP_USER`. Il faut confirmer vers quel dossier ce compte est chrooté, d'autant plus si l'on ajoute un sous-dossier `ife/`.

## 3. Décisions à prendre avant d'implémenter

1. **Schéma d'URL de la série IFE** (point bloquant).
   - Recommandation : `www.ofce.fr/pb/ife/{N}/`. Le `site-path` devient `ife/{N}[/vX]`, et le reste du pipeline (redirection, `FTP_SERVER_DIR`, anti-collision) suit tout seul.
   - On laisse `ofce` sans préfixe pour ne pas casser les URL déjà publiées.
   - L'autre option serait un domaine `ife.eco/pb/{N}/`, mais elle demande un autre FTP, d'autres secrets et un autre workflow.
2. **Lien entre `institut` et série.** L'extension accepte `ofce`, `ife`, `ife-ofce`, `ife-cepii` et `ife-ofce-cepii`, c'est-à-dire des co-marquages de logo.
   - Proposition : un helper `pb_series(institut)`. Toute valeur `ife*` donne la série `ife`, `ofce` donne `ofce`, `cepii` donne `cepii`.
   - L'autre option est une clé YAML séparée `pb_serie`. À trancher.
3. **Où déclarer la liste des séries et leur statut.**
   - Recommandation : un fichier `pb/index.json` dans le registre, sur le modèle de `wp/index.json`, par exemple `{"series": {"ofce": {"open": false}, "cepii": {"open": false}, "ife": {"open": true}}}`.
   - Avantages : fermer une série ne demande pas de nouvelle version du package, et la CI peut vérifier ce fichier.
   - L'alternative est une liste codée en dur dans ofceweb.
4. **Sort de `pb/pb.json`.** Recommandation : le **garder figé** et ajouter une règle CI qui refuse toute PR qui le modifie. Ça neutralise les anciennes versions du package. On le supprimera plus tard.
5. **Sigle du PDF publié.** `IFEPB{N}.pdf`, ou `PB-IFE-{N}.pdf` ? Et le sigle du PDF brouillon ?

### Décisions retenues (2026-10-26)

1. **URL** : `www.ofce.fr/pb/ife/{N}/`, avec `site-path` = `ife/{N}[/vX]`. La série `ofce` garde ses URL sans préfixe. Le domaine `ife.eco` n'est pas faisable pour le moment.
2. **Série** : une clé YAML séparée **`pb_series`** dans `_quarto.yml`, indépendante de `institut`. `institut` ne sert plus qu'au logo (extension), `pb_series` qu'à la numérotation et aux chemins. Pas de déduction de l'une à partir de l'autre. Dans le registre, le champ `institut` de `pb/ofce.json` devient `pb_series`.
3. **Liste et statut des séries** : `pb/index.json` dans le registre ; aucune série codée en dur dans ofceweb.
4. **`pb/pb.json`** : gardé figé, et toute PR qui le modifie est refusée par la CI.
5. **PDF** : `IFEPB{N}.pdf` une fois publié. Le brouillon s'appelle `ife-draft-{repo}-{vX}.pdf`, où `{repo}` suit la convention `pb-{initiales auteurs}-{thème court}` (ex. `ife-draft-pb-csskvv-chn-v1.pdf`). C'est le schéma actuel `ofce-draft-{repo}-{version}.pdf`, avec un préfixe tiré de la série.

## 4. Plan d'action proposé (dans l'ordre)

### Étape A — registre (`wp-registry`, avant tout le reste)

> **Fait le 2026-10-26** (points 1 et 2, branche `new_pb`, non commité). Elliot ouvre la PR lui-même.
> `pb/index.json` porte aussi, par série, les paramètres dérivés : `label`, `path-prefix` (`""` pour ofce, `"ife/"` pour ife), `pdf-prefix` (`OFCEPB`/`IFEPB`), `draft-prefix` (`ofce-draft`/`ife-draft`) et `container-title`. Son schéma est `pb/index.schema.json`. À l'étape C, `pb_paths()` lira ces valeurs dans l'index au lieu de les coder en dur dans ofceweb (décision 3).

1. Renommer le champ `institut` en `pb_series` dans `pb/ofce.json`. Ajouter `pb_series` au schéma, avec un `enum` des séries. Ajouter `pb/index.json`.
2. Étendre `validate-registry.yml` à `pb/**` :
   - JSON valide et conformité au schéma ;
   - cohérence entre le nom de fichier et `pb_series` ;
   - cohérence entre `pb/index.json` et les fichiers `pb/{serie}.json` présents ;
   - unicité de `pb` dans chaque fichier ;
   - unicité de `source-repo` entre tous les fichiers ;
   - refus des modifications de `pb.json`.

   Ajouter aussi `/pb/` à `CODEOWNERS`.
3. Fusionner `new_pb` dans `main`.

### Étape B — couche registre d'ofceweb

4. Ajouter un helper `pb_series()`, qui lit la clé `pb_series` de `_quarto.yml` (`ofce` par défaut pour les dépôts existants), et `fetch_pb_series_index()`. Réécrire `fetch_pb_registry()` et `fetch_pb_entries()` en mode multi-fichiers. Le registre est indisponible si l'index est inaccessible ; un fichier de série absent compte comme une liste vide.
5. Réécrire `pb_registry_request()` : lire la série depuis `_quarto.yml`, refuser si elle est close ou si le dépôt est déjà enregistré, puis appliquer `max+1` dans la série.
6. Adapter `sync_pb_registry_state()` et `registry_diag_rows(kind = "pb")` pour comparer le couple (série, numéro).

### Étape C — chemins dérivés

> **Fait le 2026-10-26** (non commité), avec une précision d'Elliot qui a changé le plan : **seul un brouillon est versionné**. Un PB publié (numéro attribué par le registre) n'a plus de version : `setup_pb()` supprime la clé `version`, le `site-path` est `{path-prefix}{N}` sans version, et une correction se fait en redéployant à la même adresse.
> - Helpers dans `R/pb_paths.R` (`pb_series_params()`, `pb_site_path()`, `pb_public_url()`, `pb_pdf_name()`), alimentés par `pb/index.json`. Sans index, `setup_pb()` ne recalcule pas les champs qui en dépendent et le signale.
> - Point 8 : au lieu de corriger `pb_version_up()` pour les PB publiés, elle refuse désormais de tourner sur un PB publié.
> - Redirection de production des PB supprimée : `push_pb_redirect()`, ses tests, l'appel dans `deploy_pb()`, `FTP_REDIRECT_DIR` et le gabarit `inst/setup_pb/workflows/ftp_redirect.yml`. La redirection de staging des brouillons est conservée.
> - Point 9 : `setup_pb()` écrit `nb` pour un PB publié et le retire pour un brouillon. Sans `nb`, l'extension affichait tout PB publié comme un brouillon. **Reste à faire dans `ofce-quarto-extensions`** : `_extensions/pb/html/toc.html` affiche `n°$annee$-$nb$` (donc « n°-12 ») avec le logo OFCE en dur.
> - `pb_series: ife` ajouté au gabarit `_quarto.yml` (prévu à l'étape D). `setup_pb()` écrit aussi `pb_series` explicitement (`ofce` pour un dépôt qui n'a pas la clé).
> - Reporté à plus tard, à la demande d'Elliot : le PB 158 (`pb-mb-stem`). Il n'a en fait jamais été publié en production : voir section 6.

7. Ajouter un helper unique, par exemple `pb_paths(serie, pb, version)`, qui renvoie `site_path`, `stable_url`, `final_url`, `pdf_name` et `container_title`. Pour `ife`, il produit `ife/{N}`, `IFEPB{N}.pdf` et `ife-draft-{repo}-{vX}.pdf` ; pour `ofce`, il garde `{N}`, `OFCEPB{N}.pdf` et `ofce-draft-…`. L'utiliser dans `setup_pb`, `pb_manifest`, `deploy_pb`, `check_pb`, `complete_pb_yaml` et `pb_redirect`, au lieu de répéter les `sprintf` à six endroits.
8. Corriger `pb_version_up()` pour un `site-path` sans segment de version.
9. Faire écrire `nb` par `setup_pb()`, ou faire lire `pb` par l'extension. Mettre à jour le `toc.html` de l'extension (dépôt `ofce-quarto-extensions`).

### Étape D — gabarits, docs, tests, version

> **Fait le 2026-10-26** (non commité).
> - Vignette `policy-briefs.Rmd` réécrite (séries, absence de version une fois publié, plus de redirection de production, manifeste non collecté). `NEWS.md` : entrée 1.0.6. `DESCRIPTION` passe en 1.0.6.
> - Point 12, comme demandé par Elliot, uniquement dans `check_pb()` pour ne pas toucher au workflow des WP. `pb/index.json` déclare `min-ofceweb-version` (1.0.6). En dessous, `check_pb()` renvoie une erreur `ofceweb:version`, ce qui bloque `render_pb()` et donc `publish()`. Ce point ajoute une modification au registre (branche `new_pb`, non commitée) : `pb/index.json`, `pb/index.schema.json` et `README.md`.
> - Limite : une installation antérieure à 1.0.6 n'a pas ce contrôle. Contre elle, c'est le gel de `pb/pb.json` par la CI du registre qui protège (étape A). Le contrôle sert pour les montées de version suivantes.

10. Ajouter `pb_series: ife` au gabarit `_quarto.yml`, à côté de `institut`. Mettre à jour la vignette `policy-briefs.Rmd` et corriger l'affirmation selon laquelle webhome collecte `manifest.json` (voir section 5). Ajouter à `NEWS.md` une entrée « PB multi-séries ».
11. Tests :
    - un registre multi-séries simulé ;
    - une série close ;
    - la reprise de la numérotation à 1 ;
    - la collision d'URL entre séries ;
    - `pb_series` absent qui retombe sur `ofce` (série close, donc demande refusée avec un message explicite).
12. Monter la version minimale d'ofceweb exigée, via `check_gh_setup()` ou `check_pb()`, pour que les anciennes installations ne puissent plus faire de demande.

## 5. Compatibilité avec webhome et ife_webhome

*Vérifié le 2026-10-26 sur `web/webhome` (`main`, à jour avec `origin/main`) et `web/ife_webhome`.*

Le plan est compatible avec les workflows en place : rien ne casse. L'affichage public des PB IFE restera simplement manuel, comme celui des PB OFCE.

### Constats

1. **Pas de conflit de dossiers FTP avec webhome.** `webhome/.github/workflows/ftp_deploy.yml` envoie `_site/` à la racine du serveur (`server-dir: ./`). L'option `dangerous-clean-slate` est à `false`, et le fichier d'état de l'action ne suit que ce que webhome a lui-même déposé. Comme `_site/` ne contient pas de dossier `pb/`, un futur `/pb/ife/{N}/` déposé par un dépôt PB ne sera jamais écrasé ni supprimé.
   - Règle à garder : webhome ne doit jamais créer de page sous `/pb/`.
2. **ife_webhome n'est pas concerné.** Il se connecte avec un autre compte FTP, publie dans `./www/` (le site `ife.eco`) et ne liste aucun PB. Les PB IFE vivront sur `www.ofce.fr/pb/ife/{N}/`, et ife.eco pourra y renvoyer par des liens ajoutés à la main (par exemple dans `_index_jsons/actualite.json`).
3. **Personne ne lit encore `manifest.json`.** webhome n'a aucun script ni workflow qui le récupère. Les scripts `scripts/generate_pbrief_yaml.R` et `scripts/generate_working_papers_yaml.R` sont des migrations ponctuelles depuis l'ancienne base MySQL.
   - On peut donc ajouter `pb_series` au manifeste et changer les URL sans rien casser.
   - La vignette `policy-briefs.Rmd` affirme à tort que webhome collecte ce fichier (corrigé à l'étape D).
   - Un futur collecteur devra identifier un PB par le couple (`pb_series`, `pb`), pas par `pb` seul.
4. **Le sitemap des PB reste correct.** `render_pb()` appelle `build_sitemap(prefix = "pb/")`, qui ajoute le `site-path` à la suite. Avec `site-path: ife/12/v0`, les URL produites sont bien `www.ofce.fr/pb/ife/12/v0/`. Rien à modifier.

### Points éditoriaux côté webhome (hors ofceweb)

- `publications/policy.yml` est tenu à la main et ne distingue les PB que par `num`. Une fois la numérotation IFE lancée, il y aura de nouveau des n°1, 2, 3…
  - Conseil : y ajouter un champ `pb_series`, ou une catégorie « IFE ».
  - Rien ne casse : la page n'affiche pas `num` et trie par date.
  - Il faut décider si les PB IFE apparaissent sur `publications/policy.qmd`, aujourd'hui titrée « OFCE Policy Briefs ».
- `_index_jsons/parutions.json` affiche l'en-tête « Policy Brief de l'OFCE » écrit à la main : à adapter quand le premier PB IFE sortira.
- Les PDF des PB historiques (entrées `pdf-only` du registre) sont rangés sous `pdf/pbrief/{année}/OFCEpbriefNNN.pdf` dans webhome. Si un PB IFE est un jour publié en PDF seul, il faudra une convention, par exemple `pdf/pbrief/ife/…`. Le motif du schéma (`^pdf/pbrief/`) l'accepte déjà.

## 6. Points en suspens (après les étapes A à D)

*État au 2026-10-26.*

### 6.1 Table des matières HTML de l'extension `pb` (dépôt `ofce-quarto-extensions`)

`_extensions/pb/html/toc.html` affiche l'étiquette d'un PB publié avec deux défauts :

- le numéro est écrit `n°$annee$-$nb$`, un format hérité de l'ancienne numérotation annuelle. Les PB n'ont plus de clé `annee`, donc un PB IFE n°12 s'afficherait « n°-12 » ;
- le logo est celui de l'OFCE, en dur (`_extensions/ofce/ofce/img/ofce.png`), quel que soit `institut`.

Avant l'étape C, ce défaut restait invisible : ofceweb n'écrivait jamais `nb`, donc la page affichait toujours le badge « PB Préliminaire ». Depuis que `setup_pb()` écrit `nb` à la publication, l'étiquette apparaît.

À faire : afficher `n°$nb$` et choisir le logo selon `institut`, comme le fait déjà le gabarit Typst (`typst-template.typ`, table `instituts`). Ce changement concerne un autre dépôt, partagé par tous les sites : il n'a pas été fait ici.

### 6.2 Brouillons existants à faire entrer dans la série `ife`

`pb/pb-ceskvv-chn` (version `v1`) et `pb-gv-segregation` (version `v0`) sont des brouillons créés avant les séries. Ils doivent entrer dans la série `ife` (décision d'Elliot).

| Dépôt | `pb_series` | `institut` |
|---|---|---|
| `pb-ceskvv-chn` | `ofce`, déjà écrit par un `setup_pb()` récent | `ife`, dans `index.qmd` |
| `pb-gv-segregation` | absent | absent |

- `setup_pb()` ne change jamais une `pb_series` existante, et prend `ofce` quand elle est absente. Sans intervention, les deux dépôts seraient donc dans la série close, et `registry_request()` refuserait leur demande de numéro.
- `institut` : `setup_pb()` ajoute désormais `institut: ife` quand il n'est déclaré nulle part. `pb-gv-segregation` le recevra automatiquement ; `pb-ceskvv-chn` garde celui de son `index.qmd`.

À faire : mettre `pb_series: ife` dans leur `_quarto.yml` (remplacer `ofce` pour `pb-ceskvv-chn`, ajouter la ligne pour `pb-gv-segregation`), puis relancer `setup_pb()`. Le PDF brouillon prendra alors le nom `ife-draft-{repo}-{version}.pdf`, et `citation.container-title` deviendra « Policy Brief de l'IFE ». Un argument `setup_pb(pb_series = "ife")` qui évite l'édition à la main a été proposé, mais n'est pas implémenté.

### 6.3 Mise à jour du package chez les auteurs

- Une installation d'ofceweb antérieure à 1.0.6 ne contient pas le contrôle `min-ofceweb-version` (étape D). Contre ces installations, la seule protection est la CI du registre, qui refuse toute modification de `pb/pb.json`.
- Il faut fusionner la PR du registre (`new_pb` → `main`) **avant** de diffuser ofceweb 1.0.6. Sinon, `pb/index.json` est introuvable sur `main` : `setup_pb()` et `check_pb()` signalent un registre inaccessible, et `registry_request()` refuse toute demande.

### 6.4 Situation du PB 158 (`pb-mb-stem`)

**Registre :**

- Le n°158 a été attribué au dépôt `OFCE/pb-MB-stem` par la PR #24 (branche `request/pb/158`, 2026-10-07).
- Il a été retiré deux jours plus tard par la PR #26 (`annulation_pr`, 2026-10-09).
- Il ne figure ni dans `pb/pb.json` ni dans `pb/ofce.json`. Le dernier numéro de la série `ofce` est 157.

**Serveur :** le 2026-10-26, `https://www.ofce.fr/pb/158/` et `https://www.ofce.fr/pb/158/v0/` renvoient 404. Le PB n'est donc **pas en ligne en production**. La première version de ce document le décrivait à tort comme déjà publié en `158/v0`. Le dépôt n'a d'ailleurs pas de branche `site-deploy`, seulement `site-staging` et `site-staging-redirect`.

**Dépôt local (`GitHub/pb/pb-mb-stem`)** : il est resté dans l'état « publié » de l'ancien modèle, écrit le 2026-10-07, avant l'annulation.

| Clé | Valeur actuelle |
|---|---|
| `pb` | 158 |
| `draft` | `false` |
| `version` | `v0` |
| `website.site-path` | `158/v0` |
| `citation.url` / `stable_url` | `https://www.ofce.fr/pb/158/` |
| `citation.container-title` | Policy Brief de l'OFCE |
| `pb_series` | *(absente)* |

Son `manifest.json` (généré par ofceweb 1.0.4.9000) indique pourtant `stage: true` et une URL de staging (`https://staging.ofce.fr/pb-mb-stem/v0/`). Il a été déployé en staging, jamais en production.

**Ce qui se passera au prochain `setup_pb()` sur ce dépôt (ofceweb 1.0.6) :**

- Le registre ne connaît pas le dépôt : `sync_pb_registry_state()` remet `draft: true` et supprime `pb` de `_quarto.yml`.
- Le dépôt redevient un brouillon versionné. `site-path` est supprimé, l'URL de staging est recalculée, et `nb` est retiré s'il était présent.
- `pb_series` sera écrit à `ofce`, la série close.
- Résidus à vérifier à la main : `citation.url`, `citation.issue` et `stable_url` ne sont pas effacés par `setup_pb()` pour un brouillon. Ils resteraient à `158`. Ce comportement existait avant les séries ; on pourrait faire effacer ces trois clés par `setup_pb()` quand `pb` est absent.

**Options à trancher :**

- **(a) Le PB doit être publié dans la série IFE.** Passer `pb_series: ife` (et `institut`), relancer `setup_pb()`, nettoyer les résidus de citation, puis `registry_request()` : il recevra le n°1 de la série `ife`.
- **(b) Le PB est abandonné.** Rien à faire côté registre ni serveur. Éventuellement archiver le dépôt et nettoyer le staging.

## Annexe — réponses d'Elliot aux questions de la section 3

1) Ok pour les recommandations. L'option d'un domaine `ife.eco/pb/{N}/` n'est pas faisable pour le moment. On reste sur l'option 1.
2) En fait, je crois qu'il faut bien séparer l'institut qui a effectivement été utilisé pour décider du logo et l'aspect séries de PB. 
j'aurais donc tendance à choisir l'option 2, une clé yaml séparé pb_series. Il faut peut être adpaté ofce.json du coup
3) Ok pour la recommandation, pas de séries en dur dans ofceweb
4)ok pour la recommandation
5) On part sur `IFEPB{N}.pdf` et `ife-draft-pb-{auteurs}-{theme}-{vx}.pdf` Par convention, les repo github des wp/pb sont nommés pb-{auteurs}-{theme} avec les initiales pour les auteurs et une version condensée pour le theme. exemple "pb-csskvv-chn"
