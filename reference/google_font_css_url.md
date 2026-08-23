# URL de la feuille de style Google Fonts pour une famille

On passe par l'API CSS (\`css2\`) plutôt que par le bouton « download »
du site (qui ne sert plus d'archive zip directement) : avec un
\`User-Agent\` ancien, Google renvoie des \`@font-face\` pointant sur
des fichiers \`.ttf\`.

## Usage

``` r
google_font_css_url(font, spec = "ital,wght@0,400;0,700;1,400;1,700")
```
