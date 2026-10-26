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

## 4. Plan d'action proposé (dans l'ordre)

### Étape A — registre (`wp-registry`, avant tout le reste)

1. Ajouter `institut` au schéma, avec un `enum` des séries. Ajouter `pb/index.json`.
2. Étendre `validate-registry.yml` à `pb/**` :
   - JSON valide et conformité au schéma ;
   - cohérence entre le nom de fichier et `institut` ;
   - unicité de `pb` dans chaque fichier ;
   - unicité de `source-repo` entre tous les fichiers ;
   - refus des modifications de `pb.json`.

   Ajouter aussi `/pb/` à `CODEOWNERS`.
3. Fusionner `new_pb` dans `main`.

### Étape B — couche registre d'ofceweb

4. Ajouter `pb_series()` et `fetch_pb_series_index()`. Réécrire `fetch_pb_registry()` et `fetch_pb_entries()` en mode multi-fichiers. Le registre est indisponible si l'index est inaccessible ; un fichier de série absent compte comme une liste vide.
5. Réécrire `pb_registry_request()` : lire la série depuis `_quarto.yml`, refuser si elle est close ou si le dépôt est déjà enregistré, puis appliquer `max+1` dans la série.
6. Adapter `sync_pb_registry_state()` et `registry_diag_rows(kind = "pb")` pour comparer le couple (série, numéro).

### Étape C — chemins dérivés

7. Ajouter un helper unique, par exemple `pb_paths(serie, pb, version)`, qui renvoie `site_path`, `stable_url`, `final_url`, `pdf_name` et `container_title`. L'utiliser dans `setup_pb`, `pb_manifest`, `deploy_pb`, `check_pb`, `complete_pb_yaml` et `pb_redirect`, au lieu de répéter les `sprintf` à six endroits.
8. Corriger `pb_version_up()` pour un `site-path` sans segment de version.
9. Faire écrire `nb` par `setup_pb()`, ou faire lire `pb` par l'extension. Mettre à jour le `toc.html` de l'extension (dépôt `ofce-quarto-extensions`).

### Étape D — gabarits, docs, tests, version

10. Gabarit `_quarto.yml` et vignette `policy-briefs.Rmd`. Ajouter à `NEWS.md` une entrée « PB multi-séries ».
11. Tests :
    - un registre multi-séries simulé ;
    - une série close ;
    - la reprise de la numérotation à 1 ;
    - la collision d'URL entre séries ;
    - `institut` absent qui retombe sur `ofce`.
12. Monter la version minimale d'ofceweb exigée, via `check_gh_setup()` ou `check_pb()`, pour que les anciennes installations ne puissent plus faire de demande.
