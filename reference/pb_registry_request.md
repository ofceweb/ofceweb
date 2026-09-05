# Demande d'enregistrement d'un PB dans le registre central

Calcule le triplet \`annee, pb, source-repo\` pour le dépôt PB local et
ouvre une pull request contre \`ofce/wp-registry\` proposant d'ajouter
l'entrée correspondante à \`pb/annee.json\` (et, si c'est la première
demande pour cette année, crée ce fichier et met à jour
\`pb/index.json\` dans le même commit). Les PB partagent le même dépôt
registre que les WP (\`ofce/wp-registry\`) — sous le sous-dossier
\`pb/\`, distinct de \`wp/\` — il n'existe pas de dépôt \`pb-registry\`
séparé. N'attend pas la fusion (fire-and-forget) — un·e admin doit
approuver manuellement. Relancer \[setup_pb()\] une fois la PR fusionnée
: c'est \`setup_pb()\` (pas \`render_pb()\`, qui ne consulte plus le
registre) qui synchronise \`pb\`/\`annee\`/\`draft\` et recalcule
\`site-path\`/\`citation.\*\` depuis l'entrée confirmée, pour basculer
du mode staging au mode publication.

## Usage

``` r
pb_registry_request(
  path = ".",
  annee = NULL,
  pb = NULL,
  contact = NULL,
  registry_repo = "ofce/wp-registry",
  dry_run = FALSE
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt PB local. Défaut \`"."\`.

- annee:

  Entier. Année du PB. Défaut : \`annee\` dans \`\_quarto.yml\` si
  présent, sinon l'année courante.

- pb:

  Entier ou \`NULL\`. Numéro de PB souhaité. Si \`NULL\` (défaut),
  calculé automatiquement comme \`max(pb existants pour cette annee) +
  1\` d'après \`pb/annee.json\` au moment de l'appel (tous types
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
\`ofce/wp-registry\`, création de la branche \`request/pb/annee/pb\`
avec l'entrée proposée. Le préfixe \`pb/\` évite toute collision avec
les branches \`request/annee/wp\` ouvertes par \[wp_registry_request()\]
dans le même dépôt partagé. 3. Push de cette branche vers
\`ofce/wp-registry\`. 4. Ouverture d'une pull request intra-dépôt
(\`head = "branche"\`, \`base = "main"\`).

Si le push échoue (droits insuffisants ou token non membre de
l'organisation \`ofce\`), la fonction s'arrête avec une erreur
explicite.

Le token utilisé (\`DEPLOY_PAT\` ou identifiants \`gitcreds\`) doit
permettre de résoudre \`GET /user\` et de pousser une branche sur
\`ofce/wp-registry\` — un PAT classique avec la portée \`repo\` (ou
\`public_repo\`) d'un compte membre de l'organisation \`ofce\` convient.

## See also

\[setup_pb()\], \[render_pb()\], \[deploy_pb()\]
