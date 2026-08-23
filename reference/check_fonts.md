# Vérifie (et installe) les polices Google utilisées par les thèmes OFCE

Regarde si les familles \`Open Sans\`, \`Arimo\` et \`Merriweather\`
sont disponibles pour le système (via \[systemfonts::system_fonts()\])
et, le cas échéant, installe celles qui manquent avec
\[install_fonts()\].

## Usage

``` r
check_fonts(fonts = ofce_fonts(), install = TRUE, quiet = FALSE, ...)
```

## Arguments

- fonts:

  Familles à vérifier. Défaut : \`c("Open Sans", "Arimo",
  "Merriweather")\`.

- install:

  Si \`TRUE\` (défaut), installe les polices manquantes. Si \`FALSE\`,
  se contente de signaler ce qui manque.

- quiet:

  Si \`TRUE\`, n'affiche aucun message.

- ...:

  Passé à \[install_fonts()\] (notamment \`method\`).

## Value

Invisible, un vecteur logique nommé indiquant, pour chaque famille, si
elle est installée \*\*après\*\* l'éventuelle installation.
