# Détecte le type d'un dépôt et lance la bonne demande d'enregistrement

Inspecte le dépôt situé à \`path\` (via \[detect_repo_type()\], la même
détection que \[render()\]/\[publish()\]/\[deploy()\]/\[check()\]) et
appelle automatiquement la fonction de demande de registre interne
correspondante.

## Usage

``` r
registry_request(path = ".", type = NULL, ...)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- type:

  Force le type de dépôt (\`"wp"\` ou \`"pb"\`, les deux seuls types
  avec un registre aujourd'hui) plutôt que de le détecter
  automatiquement. Défaut \`NULL\` (détection automatique).

- ...:

  Arguments supplémentaires transmis à la fonction de demande de
  registre choisie.

## Value

La valeur de retour de la fonction de registre appelée.

## Details

Seuls \`wp\` et \`pb\` ont un registre central (\`ofce/wp-registry\`)
aujourd'hui : \`registry_request(type =
"prev"\|"ife"\|"home"\|"blog"\|"site")\` (ou auto-détection dans l'un de
ces dépôts) échoue avec un message explicite plutôt que de tenter un
accès réseau inadapté. Ajouter un futur registre pour un autre type se
fait en complétant la colonne \`registry\` de la table de dispatch
interne (\`.ofce_repo_types()\`), pas en ajoutant une nouvelle fonction
exportée.

## See also

\[render()\], \[publish()\], \[deploy()\], \[check()\],
\[detect_repo_type()\]
