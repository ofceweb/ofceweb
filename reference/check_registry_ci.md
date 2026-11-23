# Point d'entrée de la CI de \`contentdb\`

Lance \[check_registry()\], affiche le résultat, et termine la session R
avec le code de sortie 1 si le journal n'est pas conforme. C'est la
seule fonction qu'appelle le workflow de \`ofceweb/contentdb\` : le
dépôt ne contient aucune logique.

## Usage

``` r
check_registry_ci(root = ".", deleted_file = NULL)
```

## Arguments

- root:

  Racine du dépôt, qui contient le dossier \`registry/\`.

- deleted_file:

  Fichier texte qui liste les fichiers supprimés, un chemin par ligne,
  relatif à la racine du dépôt. Un fichier absent ou vide, ou \`NULL\`,
  signifie qu'aucun fichier n'a été supprimé.

## Value

Le résultat de \[check_registry()\], invisible, quand le journal est
conforme.

## Examples

``` r
if (FALSE) { # \dontrun{
# Dans le workflow de contentdb, après
# git diff --no-renames --name-only --diff-filter=D <avant> <après> -- registry/ > deleted.txt
ofceweb::check_registry_ci(".", "deleted.txt")
} # }
```
