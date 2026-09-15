# Détecte le type d'un dépôt et incrémente sa version

Inspecte le dépôt situé à \`path\` (via \[detect_repo_type()\], la même
détection que \[render()\]/\[publish()\]/\[deploy()\]/\[check()\]) et
appelle automatiquement la fonction d'incrémentation de version interne
correspondante.

## Usage

``` r
version_up(path = ".", type = NULL, ...)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- type:

  Force le type de dépôt (\`"wp"\`, \`"site"\`, \`"prev"\`, \`"pb"\`,
  \`"ife"\`, \`"home"\` ou \`"blog"\`) plutôt que de le détecter
  automatiquement. Défaut \`NULL\` (détection automatique).

- ...:

  Arguments supplémentaires transmis à la fonction d'incrémentation de
  version choisie (typiquement \`custom_version\`).

## Value

La valeur de retour de la fonction d'incrémentation de version appelée
(généralement \`NULL\`, invisible).

## Details

L'incrémentation de version n'est disponible que pour \`wp\`, \`pb\`,
\`prev\` et \`site\` : \`version_up(type = "ife"\|"home"\|"blog")\` (ou
auto-détection dans un de ces dépôts) échoue avec un message explicite
plutôt que de tenter quelque chose d'inadapté. Pour un site générique,
la fonction cible (\[site_version_up()\]) ne fonctionne que si
\`ofce_host: true\` est présent dans \`\_quarto.yml\`.

## See also

\[render()\], \[publish()\], \[deploy()\], \[check()\],
\[registry_request()\], \[detect_repo_type()\]
