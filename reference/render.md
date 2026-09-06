# Détecte le type d'un dépôt et lance le bon rendu

Inspecte le dépôt situé à \`path\` (via \[detect_repo_type()\]) et
appelle automatiquement \[render_wp()\], \[render_site()\],
\[render_prev()\] ou \[render_blog()\] selon ce qui est détecté, plutôt
que de devoir se souvenir de la bonne fonction à utiliser.

## Usage

``` r
render(path = ".", type = NULL, ...)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- type:

  Force le type de dépôt (\`"wp"\`, \`"site"\`, \`"prev"\`, \`"pb"\` ou
  \`"blog"\`) plutôt que de le détecter automatiquement. Défaut \`NULL\`
  (détection automatique).

- ...:

  Arguments supplémentaires transmis à la fonction de rendu choisie
  (\[render_wp()\], \[render_site()\], \[render_prev()\],
  \[render_pb()\] ou \[render_blog()\]). Ces fonctions n'ont pas toutes
  la même signature ; passer un argument non reconnu par la fonction
  cible provoquera une erreur R standard ("unused argument").

## Value

La valeur de retour de la fonction de rendu appelée.

## Details

La détection se fait, dans l'ordre :

1.  \`ofce_prev: true\` dans \`\_quarto.yml\` → prévision
    (\`render_prev()\`)

2.  \`ofce_wp: true\` dans \`\_quarto.yml\` → document de travail
    (\`render_wp()\`)

3.  \`ofce_pb: true\` dans \`\_quarto.yml\` → policy brief
    (\`render_pb()\`)

4.  présence d'un dossier \`posts/\` → blog (\`render_blog()\`)

5.  présence d'un \`\_quarto.yml\` (sans marqueur ci-dessus) → site
    générique (\`render_site()\`)

Si rien de tout cela n'est détecté, la fonction s'arrête avec un message
invitant à lancer \[setup_wp()\] ou \[setup_site()\].

## See also

\[render_wp()\], \[render_site()\], \[render_prev()\], \[render_pb()\],
\[render_blog()\], \[detect_repo_type()\]
