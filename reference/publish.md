# Détecte le type d'un dépôt et lance la bonne publication

Inspecte le dépôt situé à \`path\` (via \[detect_repo_type()\], la même
détection que celle utilisée par \[render()\]) et appelle
automatiquement la fonction de publication interne correspondante.

## Usage

``` r
publish(path = ".", type = NULL, ...)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- type:

  Force le type de dépôt (\`"wp"\`, \`"site"\`, \`"prev"\`, \`"pb"\`,
  \`"ife"\`, \`"home"\` ou \`"blog"\`) plutôt que de le détecter
  automatiquement. Défaut \`NULL\` (détection automatique).

- ...:

  Arguments supplémentaires transmis à la fonction de publication
  choisie. Ces fonctions n'ont pas toutes la même signature ; passer un
  argument non reconnu par la fonction cible provoquera une erreur R
  standard ("unused argument").

## Value

La valeur de retour de la fonction de publication appelée.

## Details

La détection se fait, dans l'ordre :

1.  \`ofce_prev: true\` dans \`\_quarto.yml\` → prévision

2.  \`ofce_wp: true\` dans \`\_quarto.yml\` → document de travail

3.  \`ofce_pb: true\` dans \`\_quarto.yml\` → policy brief

4.  \`ofce_home: true\` dans \`\_quarto.yml\` → homepage OFCE

5.  \`project: type: ife-website\` dans \`\_quarto.yml\` → site IFE

6.  présence d'un dossier \`posts/\` → blog (\[publish_blog()\])

7.  présence d'un \`\_quarto.yml\` (sans marqueur ci-dessus) → site
    générique

Si rien de tout cela n'est détecté, la fonction s'arrête avec un message
invitant à lancer \[setup_wp()\] ou \[setup_site()\].

Pour un site générique, il n'existe pas de fonction \`publish_site()\`
dédiée à part entière avec une sémantique différente de \`render +
deploy\` : les sites génériques n'ont pas de distinction staging/publish
comme les prévisions, donc \`publish_site()\` (rendu + déploiement) en
tient lieu.

## See also

\[render()\], \[deploy()\], \[check()\], \[registry_request()\],
\[publish_blog()\], \[detect_repo_type()\]
