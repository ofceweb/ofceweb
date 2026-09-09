# Détecte le type d'un dépôt et lance le bon déploiement

Inspecte le dépôt situé à \`path\` (via \[detect_repo_type()\], la même
détection que \[render()\]/\[publish()\]) et appelle automatiquement la
fonction de déploiement interne correspondante : pousse le contenu déjà
rendu (\`\_site/\` ou équivalent) vers la destination appropriée
(branche git + FTP, GitHub Pages...), sans relancer le rendu Quarto.

## Usage

``` r
deploy(path = ".", type = NULL, ...)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- type:

  Force le type de dépôt (\`"wp"\`, \`"site"\`, \`"prev"\`, \`"pb"\`,
  \`"ife"\` ou \`"home"\`) plutôt que de le détecter automatiquement.
  Défaut \`NULL\` (détection automatique). \`"blog"\` est un type valide
  mais n'a pas de déploiement disponible (voir Détails).

- ...:

  Arguments supplémentaires transmis à la fonction de déploiement
  choisie. Ces fonctions n'ont pas toutes la même signature ; passer un
  argument non reconnu par la fonction cible provoquera une erreur R
  standard ("unused argument").

## Value

La valeur de retour de la fonction de déploiement appelée.

## Details

Le déploiement n'est pas disponible pour tous les types : \`blog\` n'a
pas d'entrée \`deploy\` dans ce round (la publication d'un post de blog
passe par \[publish_blog()\], pas par un déploiement séparé) —
\`deploy(type = "blog")\` (ou auto-détection dans un dépôt blog) échoue
avec un message explicite plutôt que de tenter quelque chose d'inadapté.

## See also

\[render()\], \[publish()\], \[check()\], \[registry_request()\],
\[detect_repo_type()\]
