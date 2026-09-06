# Détecte le type d'un dépôt et lance la bonne publication

Inspecte le dépôt situé à \`path\` (via \[detect_repo_type()\], la même
détection que celle utilisée par \[render()\]) et appelle
automatiquement \[publish_wp()\], \[publish_prev()\], \[publish_blog()\]
ou \[stage_site()\] selon ce qui est détecté.

## Usage

``` r
publish(path = ".", type = NULL, ...)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- type:

  Force le type de dépôt (\`"wp"\`, \`"site"\`, \`"prev"\`, \`"pb"\` ou
  \`"blog"\`) plutôt que de le détecter automatiquement. Défaut \`NULL\`
  (détection automatique).

- ...:

  Arguments supplémentaires transmis à la fonction de publication
  choisie (\[publish_wp()\], \[publish_prev()\], \[publish_pb()\],
  \[publish_blog()\] ou \[stage_site()\]). Ces fonctions n'ont pas
  toutes la même signature ; passer un argument non reconnu par la
  fonction cible provoquera une erreur R standard ("unused argument").

## Value

La valeur de retour de la fonction de publication appelée.

## Details

La détection se fait, dans l'ordre :

1.  \`ofce_prev: true\` dans \`\_quarto.yml\` → prévision
    (\[publish_prev()\])

2.  \`ofce_wp: true\` dans \`\_quarto.yml\` → document de travail
    (\[publish_wp()\])

3.  \`ofce_pb: true\` dans \`\_quarto.yml\` → policy brief
    (\[publish_pb()\])

4.  présence d'un dossier \`posts/\` → blog (\[publish_blog()\])

5.  présence d'un \`\_quarto.yml\` (sans marqueur ci-dessus) → site
    générique (\[stage_site()\])

Si rien de tout cela n'est détecté, la fonction s'arrête avec un message
invitant à lancer \[setup_wp()\] ou \[setup_site()\].

Pour un site générique, il n'existe pas de fonction \`publish_site()\`
dédiée : les sites génériques n'ont pas de distinction staging/publish
comme les prévisions, donc \[stage_site()\] (rendu + déploiement) en
tient lieu.

## See also

\[publish_wp()\], \[publish_prev()\], \[publish_pb()\],
\[publish_blog()\], \[stage_site()\], \[render()\],
\[detect_repo_type()\]
