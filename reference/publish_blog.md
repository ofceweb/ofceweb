# Publie le blog bilingue

Enveloppe pratique autour de \[render_blog()\] qui fixe \`site2branch =
TRUE\` pour déployer \`\_site\` vers la branche de déploiement après le
rendu.

## Usage

``` r
publish_blog(
  path = ".",
  force_freeze = TRUE,
  workers = 8L,
  check_repo = TRUE,
  progress = TRUE,
  render_site = FALSE,
  check_freeze = FALSE,
  trigger = TRUE,
  freeze = TRUE
)
```

## Arguments

- path:

  Chemin vers le dossier du blog. Défaut \`"."\`.

- force_freeze:

  Logique. Si \`TRUE\` (défaut), les posts sont re-rendus même si une
  version en cache existe. Mettre \`FALSE\` pour réutiliser le cache
  autant que possible.

- workers:

  Entier. Nombre de workers parallèles transmis à
  \[future.mirai::mirai_multisession()\]. Défaut \`8L\`.

- check_repo:

  Logique. Si \`TRUE\` (défaut), appelle \[check_repo_status()\] avant
  le rendu pour s'assurer que le dépôt git est dans un état propre.

- progress:

  Logique. Si \`TRUE\` (défaut), des barres de progression sont
  affichées pendant les étapes longues.

- render_site:

  Logique. Si \`TRUE\` (défaut), démarre un démon HTTP local via
  \[servr::httw()\] pour prévisualiser \`\_site\` une fois le build
  terminé.

- check_freeze:

  Logique. Si \`TRUE\`, la fonction s'arrête dès qu'un post est absent
  du cache (mode freeze strict). Défaut \`FALSE\`.

- trigger:

  Logique. Transmis à \[site2branch()\] pour déclencher en option un
  workflow GitHub Actions après le déploiement. Défaut \`FALSE\`.

- freeze:

  Logique. Si \`TRUE\` (défaut), transmis à \[copy_files()\] pour
  activer le mode freeze de Quarto lors de la copie de l'ossature du
  projet.

## Value

Un data frame des changements git préparés, renvoyé invisiblement.

## See also

\[render_blog()\], \[site2branch()\]

## Examples

``` r
if (FALSE) { # \dontrun{
publish_blog()
} # }
```
