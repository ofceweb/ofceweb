# Demande d'enregistrement d'un WP dans le registre central

Calcule le triplet \`annee, wp, source-repo\` pour le dépôt WP local et
ouvre une pull request contre \`ofce/wp-registry\` proposant d'ajouter
l'entrée correspondante à \`wp/annee.json\` (et, si c'est la première
demande pour cette année, crée ce fichier et met à jour
\`wp/index.json\` dans le même commit). N'attend pas la fusion
(fire-and-forget) — un·e admin doit approuver manuellement. Relancer
\[setup_wp()\] une fois la PR fusionnée : c'est \`setup_wp()\` (pas
\`render_wp()\`, qui ne consulte plus le registre) qui synchronise
\`wp\`/\`annee\`/\`draft\` et recalcule \`site-path\`/\`citation.\*\`
depuis l'entrée confirmée, pour basculer du mode staging au mode
publication.

## Usage

``` r
wp_registry_request(
  path = ".",
  annee = NULL,
  wp = NULL,
  contact = NULL,
  registry_repo = "ofce/wp-registry",
  dry_run = FALSE
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt WP local. Défaut \`"."\`.

- annee:

  Entier. Année du WP. Défaut : \`annee\` dans \`\_quarto.yml\` si
  présent, sinon l'année courante.

- wp:

  Entier ou \`NULL\`. Numéro de WP souhaité. Si \`NULL\` (défaut),
  calculé automatiquement comme \`max(wp existants pour cette annee) +
  1\` d'après \`wp/annee.json\` au moment de l'appel (tous types
  confondus ; \`1\` si le fichier n'existe pas encore). Si fourni
  explicitement, la fonction vérifie l'absence de collision avant
  d'ouvrir la PR et échoue localement en cas de conflit.

- contact:

  Adresse de contact de l'auteur·e. Défaut : valeur de \`git config
  user.email\` pour ce dépôt (config locale avec repli sur la globale).
  La fonction échoue si aucune valeur ne peut être résolue.

- registry_repo:

  Slug \`"owner/repo"\` du dépôt registre. Défaut
  \`"ofce/wp-registry"\`.

- dry_run:

  Si \`TRUE\`, calcule et affiche l'entrée proposée sans ouvrir de pull
  request. Défaut \`FALSE\`.

## Value

Invisiblement, une liste avec \`entry\` (l'entrée proposée) et
\`pr_url\` (URL de la PR ouverte, \`NULL\` en mode \`dry_run\`).

## Details

\# Flux : push d'une branche puis PR intra-dépôt

Le dépôt \`ofce/wp-registry\` est configuré pour autoriser les membres
de l'organisation \`ofce\` à pousser des branches et ouvrir des pull
requests sans être collaborateur·rice avec droit d'écriture (seule la
\*\*fusion\*\* reste protégée : branch protection + \`CODEOWNERS\`). La
fonction exploite cette configuration — pas de fork personnel :

1\. Résolution du login GitHub (\`GET /user\`) associé au token
(\`DEPLOY_PAT\` ou identifiants \`gitcreds\`). 2. Clonage de
\`ofce/wp-registry\`, création de la branche \`request/annee/wp\` avec
l'entrée proposée. 3. Push de cette branche vers \`ofce/wp-registry\`.
4. Ouverture d'une pull request intra-dépôt (\`head = "branche"\`,
\`base = "main"\`).

Si le push échoue (droits insuffisants ou token non membre de
l'organisation \`ofce\`), la fonction s'arrête avec une erreur
explicite.

Le token utilisé (\`DEPLOY_PAT\` ou identifiants \`gitcreds\`) doit
permettre de résoudre \`GET /user\` et de pousser une branche sur
\`ofce/wp-registry\` — un PAT classique avec la portée \`repo\` (ou
\`public_repo\`) d'un compte membre de l'organisation \`ofce\` convient.

## See also

\[setup_wp()\], \[render_wp()\], \[deploy_wp()\]
