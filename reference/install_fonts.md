# Installe des polices Google

Sur un système Unix (macOS, Linux) où Homebrew est disponible,
l'installation passe par \`brew install –cask font-\<famille\>\`. Sinon
(ou en cas d'échec), les fichiers \`.ttf\` sont téléchargés depuis l'API
Google Fonts et copiés dans le dossier de polices de l'utilisateur :

## Usage

``` r
install_fonts(
  fonts = ofce_fonts(),
  method = c("auto", "brew", "download"),
  quiet = FALSE
)
```

## Arguments

- fonts:

  Familles à installer. Défaut : \`c("Open Sans", "Arimo",
  "Merriweather")\`.

- method:

  \`"auto"\` (défaut) essaie Homebrew puis le téléchargement ;
  \`"brew"\` force Homebrew ; \`"download"\` force le téléchargement.

- quiet:

  Si \`TRUE\`, n'affiche aucun message.

## Value

Invisible, un vecteur logique nommé : \`TRUE\` si l'installation de la
famille s'est déroulée sans erreur.

## Details

\* macOS : \`~/Library/Fonts\` \* Linux : \`~/.local/share/fonts\` (+
\`fc-cache -f\`) \* Windows : \` \`HKCU\\..\Fonts\`)
