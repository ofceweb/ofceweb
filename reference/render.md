# Détecte le type d'un dépôt et lance le bon rendu

Inspecte le dépôt situé à \`path\` (via \[detect_repo_type()\]) et
appelle automatiquement la fonction de rendu interne correspondante (WP,
site générique, prévision, policy brief, site IFE, homepage ou blog)
selon ce qui est détecté, plutôt que de devoir se souvenir de la bonne
fonction à utiliser.

## Usage

``` r
render(path = ".", type = NULL, ...)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- type:

  Force le type de dépôt (\`"wp"\`, \`"site"\`, \`"prev"\`, \`"pb"\`,
  \`"ife"\`, \`"home"\` ou \`"blog"\`) plutôt que de le détecter
  automatiquement. Défaut \`NULL\` (détection automatique).

- ...:

  Arguments supplémentaires transmis à la fonction de rendu choisie. Ces
  fonctions n'ont pas toutes la même signature ; passer un argument non
  reconnu par la fonction cible provoquera une erreur R standard
  ("unused argument").

## Value

La valeur de retour de la fonction de rendu appelée.

## Details

La détection se fait, dans l'ordre :

1.  \`ofce_prev: true\` dans \`\_quarto.yml\` → prévision

2.  \`ofce_wp: true\` dans \`\_quarto.yml\` → document de travail

3.  \`ofce_pb: true\` dans \`\_quarto.yml\` → policy brief

4.  \`ofce_home: true\` dans \`\_quarto.yml\` → homepage OFCE

5.  \`project: type: ife-website\` dans \`\_quarto.yml\` → site IFE

6.  présence d'un dossier \`posts/\` → blog (\[render_blog()\])

7.  présence d'un \`\_quarto.yml\` (sans marqueur ci-dessus) → site
    générique

Si rien de tout cela n'est détecté, la fonction s'arrête avec un message
invitant à lancer \[setup_wp()\] ou \[setup_site()\].

Pour \`blog\`/\`ife\`/\`home\`, le nom du dossier local est vérifié
(\`webblog\`/\`ife_webhome\`/\`webhome\` respectivement) : un dépôt mal
nommé provoque un arrêt explicite plutôt qu'un rendu silencieux au
mauvais endroit.

## See also

\[publish()\], \[deploy()\], \[check()\], \[registry_request()\],
\[render_blog()\], \[detect_repo_type()\]
