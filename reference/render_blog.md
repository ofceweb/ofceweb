# Rend le blog bilingue

Orchestre un build complet du blog Quarto en français et en anglais.
Reconstruit la base des posts, rend chaque version de langue en
parallèle, met à jour l'index de recherche Algolia et le sitemap, patche
les hash CSS Bootstrap, commite les changements de cache dans git et, en
option, déploie le site ou lance un serveur de prévisualisation local.

## Usage

``` r
render_blog(
  path = ".",
  force_freeze = TRUE,
  workers = 8L,
  check_repo = TRUE,
  progress = TRUE,
  render_site = TRUE,
  check_freeze = FALSE,
  site2branch = FALSE,
  trigger = site2branch,
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

- site2branch:

  Logique. Paramètre réservé (actuellement inutilisé dans le corps de la
  fonction ; le déploiement est contrôlé par la variable d'environnement
  \`push_site_deploy\`). Défaut \`FALSE\`.

- trigger:

  Logique. Transmis à \[site2branch()\] pour déclencher en option un
  workflow GitHub Actions après le déploiement. Défaut \`FALSE\`.

- freeze:

  Logique. Si \`TRUE\` (défaut), transmis à \[copy_files()\] pour
  activer le mode freeze de Quarto lors de la copie de l'ossature du
  projet.

## Value

Un data frame des changements git préparés (sortie de
\[gert::git_status()\]), renvoyé invisiblement.

## Details

La fonction doit être exécutée depuis un projet RStudio contenant un
répertoire \`posts/\`. Elle s'attend aussi à ce que le projet se trouve
dans un répertoire nommé \`webblog\` et demande confirmation dans le cas
contraire.

Deux variables sont lues depuis l'environnement appelant (pas des
arguments de la fonction) : - \`typst\` : transmise à \[copy_post()\]
pour contrôler le rendu PDF Typst. - \`push_site_deploy\` : si \`TRUE\`,
appelle \[site2branch()\] pour pousser \`\_site\` vers la branche de
déploiement ; sinon affiche les instructions pour le faire manuellement.

## See also

\[site2branch()\]

## Examples

``` r
if (FALSE) { # \dontrun{
render_blog()
} # }
```
