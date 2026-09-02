# Idée : durcir `sync_wp_registry_state()` contre un échec d'écriture silencieux

Status: **non planifié** — noté pour référence future, pas de travail en cours.

## Contexte

`sync_wp_registry_state()` (`R/wp_registry_sync.R`) a été corrigée pour que,
lorsque la consultation du registre central échoue (réseau,
`wp/index.json` inaccessible), la fonction efface `wp`/`annee` de
`_quarto.yml` et force `draft: true`, au lieu de les laisser inchangés
(ancien comportement *fail-soft*). L'objectif : une vérification impossible
ne doit jamais être traitée comme une confirmation implicite d'un WP déjà
publié (voir NEWS.md, section `sync_wp_registry_state()` de la v0.10.8).

## Faille résiduelle identifiée

L'écriture effective du fichier, dans la branche "registre inaccessible",
est elle-même entourée d'un `tryCatch` qui se contente d'avertir en cas
d'échec :

```r
tryCatch({
  lines <- readLines(qyml_path, warn = FALSE)
  lines <- yaml_patch_scalar(lines, "draft", TRUE)
  lines <- yaml_patch_delete(lines, "annee")
  lines <- yaml_patch_delete(lines, "wp")
  writeLines(lines, qyml_path)
}, error = function(e)
  warn("Clés draft/wp/annee non écrites dans _quarto.yml : ..."))
return(list(stage = TRUE, registry_entry = NULL,
            source_repo = source_repo, network_error = TRUE))
```

Si cette écriture échoue (permissions, disque plein, fichier verrouillé...)
sur un dépôt **déjà confirmé** (`draft: false`, `wp`/`annee` déjà corrects
sur disque), la fonction renvoie quand même `network_error = TRUE`, mais le
fichier sur disque garde son ancien état non revalidé (`draft: false`,
`wp`/`annee` présents). `render_wp()` lit `draft` directement depuis le
disque (pas depuis la valeur de retour de `sync_wp_registry_state()`) : il
traiterait donc ce WP comme confirmé et le publierait en production — le
scénario exact que la correction visait à empêcher, déclenché cette fois par
un second mode de défaillance (écriture disque) plutôt que par le réseau.

C'est un cas limite (l'écriture échoue rarement en pratique), mais le
fallback "pas de clé `draft`" de `render_wp()` (ligne ~91-99) ne peut pas
rattraper ce cas puisque `draft` resterait présent (avec une valeur périmée),
pas absent.

## Piste de durcissement

Faire échouer (`stop()`/`cli::cli_abort()`) plutôt qu'avertir quand
l'écriture échoue dans cette branche, afin que l'appelant·e
(`tryCatch(sync_wp_registry_state(root), error = ...)` dans `setup_wp()` et
`publish_wp()`) traite l'échec comme si le registre n'avait pas du tout été
consulté (`registry_state`/`reg` deviennent `NULL`), plutôt que de laisser
penser que la synchronisation a réussi.

À évaluer avant implémentation :

- Est-ce cohérent avec le principe "fail-soft" pour les autres échecs
  d'écriture de la fonction (branche de succès, ligne ~95-109), qui ont le
  même défaut mais un enjeu moindre (le pire cas y est de garder l'ancien
  état, pas de créer un faux sentiment de sécurité) ?
- Ajouter un test de régression simulant un échec d'écriture (`writeLines`
  mocké pour lever une erreur) dans la branche "registre inaccessible", pour
  verrouiller le comportement voulu une fois corrigé.
