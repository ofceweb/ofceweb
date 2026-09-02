# Demande d'enregistrement d'un WP dans le registre central

Calcule le triplet \`annee, wp, source-repo\` pour le dépôt WP local et
ouvre une pull request contre \`ofceweb/wp-registry\` proposant
d'ajouter l'entrée correspondante à \`wp/annee.json\` (et, si c'est la
première demande pour cette année, crée ce fichier et met à jour
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
  registry_repo = "ofceweb/wp-registry",
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
  \`"ofceweb/wp-registry"\`.

- dry_run:

  Si \`TRUE\`, calcule et affiche l'entrée proposée sans ouvrir de pull
  request. Défaut \`FALSE\`.

## Value

Invisiblement, une liste avec \`entry\` (l'entrée proposée) et
\`pr_url\` (URL de la PR ouverte, \`NULL\` en mode \`dry_run\`).

## Details

\# Flux : push direct si possible, sinon fork

L'ouverture de la PR se fait, selon les droits du token utilisé, soit
par un push direct d'une branche sur \`ofceweb/wp-registry\` (PR
intra-dépôt), soit — pour l'immense majorité des appelant·e·s, qui n'ont
aucun accès en écriture sur ce dépôt — via un \*\*fork personnel\*\*,
créé (ou réutilisé s'il existe déjà) sous le compte GitHub associé au
token :

1\. Résolution du login GitHub (\`GET /user\`) associé au token
(\`DEPLOY_PAT\` ou identifiants \`gitcreds\`). 2. Vérification des
droits sur \`ofceweb/wp-registry\` (\`GET /repos/ofceweb/wp-registry\`,
champ \`permissions.push\`). - Si le token a un accès en écriture (ex.
compte admin/maintainer du registre) : pas de fork — on travaille
directement sur \`ofceweb/wp-registry\`. C'est nécessaire car GitHub
refuse silencieusement de forker un dépôt vers un compte qui y a déjà
accès en écriture (aucune erreur immediate, mais le fork n'apparaît
jamais). - Sinon : vérification de l'existence d'un fork sous ce login
(\`GET /repos/login/wp-registry\`) ; sinon, création (\`POST
/repos/ofceweb/wp-registry/forks\`) et attente (jusqu'à 20 s) que GitHub
le rende clonable. 3. Clonage (du fork, ou de \`ofceweb/wp-registry\`
directement). Pour un fork, resynchronisation avec \`upstream/main\` (le
fork peut avoir pris du retard depuis sa création). Puis création de la
branche \`request/annee/wp\` avec l'entrée proposée. 4. Push de cette
branche vers le fork, ou vers \`ofceweb/wp-registry\` selon le cas. 5.
Ouverture d'une pull request : \*\*cross-repo\*\* (\`head =
"login:branche"\`) depuis un fork, ou \*\*intra-dépôt\*\* (\`head =
"branche"\`) en cas de push direct.

Le flux par fork reste le défaut car il est déterminé par le modèle de
gouvernance du registre (voir la note d'équipe
\`note-equipe-publication-wp.md\`) : seule la \*\*fusion\*\* d'une PR
dans \`wp-registry\` doit être protégée (branch protection +
\`CODEOWNERS\` côté GitHub), pas l'ouverture d'une PR — n'importe
quel·le auteur·e de l'organisation \`ofce\` doit pouvoir demander un
numéro sans être collaborateur·rice avec droit d'écriture sur
\`wp-registry\`. Le fork suit le flux standard de contribution externe
sur GitHub : n'importe quel compte authentifié peut forker un dépôt
public, sans droit d'écriture préalable sur celui-ci.

Conséquence pratique : le token utilisé (\`DEPLOY_PAT\` ou identifiants
\`gitcreds\`) doit au minimum permettre de résoudre \`GET /user\` et de
forker un dépôt public — ce que n'importe quel PAT
\`repo\`/\`public_repo\` d'un compte authentifié satisfait, sans
configuration particulière côté \`ofceweb/wp-registry\`.

## See also

\[setup_wp()\], \[render_wp()\], \[deploy_wp()\]
