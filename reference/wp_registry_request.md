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

\# Flux via fork

L'ouverture de la PR passe par un \*\*fork personnel\*\* de
\`ofceweb/wp-registry\`, créé (ou réutilisé s'il existe déjà) sous le
compte GitHub associé au token utilisé — jamais par un push direct sur
\`ofceweb/wp-registry\` lui-même :

1\. Résolution du login GitHub (\`GET /user\`) associé au token
(\`DEPLOY_PAT\` ou identifiants \`gitcreds\`). 2. Vérification de
l'existence d'un fork sous ce login (\`GET /repos/login/wp-registry\`) ;
sinon, création (\`POST /repos/ofceweb/wp-registry/forks\`) et attente
(jusqu'à 20 s) que GitHub le rende clonable. 3. Clonage du fork,
resynchronisation avec \`upstream/main\` (le fork peut avoir pris du
retard depuis sa création), puis création de la branche
\`request/annee/wp\` avec l'entrée proposée. 4. Push de cette branche
vers le fork (pas vers \`ofceweb/wp-registry\`). 5. Ouverture d'une pull
request \*\*cross-repo\*\* (\`head = "login:branche"\`) contre
\`ofceweb/wp-registry\`.

Ce choix est déterminé par le modèle de gouvernance du registre (voir la
note d'équipe \`note-equipe-publication-wp.md\`) : seule la
\*\*fusion\*\* d'une PR dans \`wp-registry\` doit être protégée (branch
protection + \`CODEOWNERS\` côté GitHub), pas l'ouverture d'une PR —
n'importe quel·le auteur·e de l'organisation \`ofce\` doit pouvoir
demander un numéro sans être collaborateur·rice avec droit d'écriture
sur \`wp-registry\`. Un push direct exigerait ce droit d'écriture pour
chaque auteur·e, ce qui n'est ni souhaitable (élargit inutilement les
droits d'accès à l'infrastructure du registre) ni cohérent avec ce
modèle. Le fork suit le flux standard de contribution externe sur GitHub
: n'importe quel compte authentifié peut forker un dépôt public, sans
droit d'écriture préalable sur celui-ci.

Conséquence pratique : le token utilisé (\`DEPLOY_PAT\` ou identifiants
\`gitcreds\`) doit au minimum permettre de résoudre \`GET /user\` et de
forker un dépôt public — ce que n'importe quel PAT
\`repo\`/\`public_repo\` d'un compte authentifié satisfait, sans
configuration particulière côté \`ofceweb/wp-registry\`.

## See also

\[setup_wp()\], \[render_wp()\], \[deploy_wp()\]
