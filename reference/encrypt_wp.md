# Active le chiffrement statique d'un document de travail

Wrapper autour de \[encrypt_site()\] pour les dépôts WP. Le comportement
est identique.

## Usage

``` r
encrypt_wp(path = ".", password = NULL)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- password:

  Chaîne ou \`NULL\` (défaut). Si \`NULL\`, l'utilisateur est invité à
  saisir le mot de passe (masqué si \`askpass\` est disponible).
