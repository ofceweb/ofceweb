# Écrit la base des contenus dans \`contents.json\`

Écrit la base rendue par \[collect_contents()\] en tableau JSON, UTF-8,
un enregistrement par contenu, dans l'ordre de la base (trié par
\`id\`). Les champs tableaux restent des tableaux JSON même avec un seul
élément, et les valeurs absentes s'écrivent \`null\`.

## Usage

``` r
write_contents(x, path = "contents.json")
```

## Arguments

- x:

  Résultat de \[collect_contents()\], ou liste d'enregistrements.

- path:

  Chemin du fichier à écrire.

## Value

\`path\`, invisible.

## Examples

``` r
if (FALSE) { # \dontrun{
res <- collect_contents(".", previous = "contents.json")
write_contents(res, "contents.json")
} # }
```
