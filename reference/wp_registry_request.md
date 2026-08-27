# Demande d'enregistrement d'un WP dans le registre central

Calcule le triplet \`annee, wp, source-repo\` pour le dépôt WP local et
ouvre une pull request contre \`ofceweb/wp-registry\` proposant
d'ajouter l'entrée correspondante à \`wp/annee.json\` (et, si c'est la
première demande pour cette année, crée ce fichier et met à jour
\`wp/index.json\` dans le même commit). N'attend pas la fusion
(fire-and-forget) — un·e admin doit approuver manuellement. Relancer
\[render_wp()\] une fois la PR fusionnée pour basculer du mode staging
au mode publication.

## Usage

``` r
wp_registry_request(
  path = ".",
  annee = NULL,
  wp = NULL,
  contact = NULL,
  registry_repo = "ofceweb/wp-registry",
  dry_run = FALSE
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt WP local. Défaut \`"."\`.

- annee:

  Entier. Année du WP. Défaut : \`annee\` dans \`\_quarto.yml\` si
  présent, sinon l'année courante.

- wp:

  Entier ou \`NULL\`. Numéro de WP souhaité. Si \`NULL\` (défaut),
  calculé automatiquement comme \`max(wp existants pour cette annee) +
  1\` d'après \`wp/annee.json\` au moment de l'appel (tous types
  confondus ; \`1\` si le fichier n'existe pas encore). Si fourni
  explicitement, la fonction vérifie l'absence de collision avant
  d'ouvrir la PR et échoue localement en cas de conflit.

- contact:

  Adresse de contact de l'auteur·e. Défaut : valeur de \`git config
  user.email\` pour ce dépôt (config locale avec repli sur la globale).
  La fonction échoue si aucune valeur ne peut être résolue.

- registry_repo:

  Slug \`"owner/repo"\` du dépôt registre. Défaut
  \`"ofceweb/wp-registry"\`.

- dry_run:

  Si \`TRUE\`, calcule et affiche l'entrée proposée sans ouvrir de pull
  request. Défaut \`FALSE\`.

## Value

Invisiblement, une liste avec \`entry\` (l'entrée proposée) et
\`pr_url\` (URL de la PR ouverte, \`NULL\` en mode \`dry_run\`).

## See also

\[setup_wp()\], \[render_wp()\], \[deploy_wp()\]
