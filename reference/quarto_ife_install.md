# Installe une version de quarto-ife

\`quarto add\` charge le projet du dossier courant, et échoue sur un
projet de type \`ife-website\` dont l'extension manque. L'extension
s'installe donc dans un dossier vide, puis ses dossiers remplacent ceux
de \`\_extensions/ofceweb/\` dans le projet.

## Usage

``` r
quarto_ife_install(path, version)
```

## Arguments

- path:

  Racine du projet Quarto.

- version:

  Version à installer, sans le \`v\`.
