# Valider un manifeste

## Ce qu’est un manifeste

Chaque contenu publié (document de travail, policy brief, post du blog,
prévision…) est décrit par un fichier `manifest.json`, écrit par son
dépôt source. La base des contenus est construite à partir de ces
manifestes.
[`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md)
et
[`pb_manifest()`](https://ofceweb.github.io/ofceweb/reference/pb_manifest.md)
les produisent pour les documents de travail et les policy briefs ;
d’autres producteurs (le blog, l’outil de saisie des PDF, la migration
de l’existant) écrivent le même format.

Le format v1 est fixé par un schéma [JSON
Schema](https://json-schema.org/) (draft-07), qui fait foi pour la liste
des champs, leur caractère obligatoire et leurs valeurs admises. Chaque
champ y porte une description. L’explication du modèle (pourquoi ces
champs, cycle de vie d’un contenu) se trouve dans `webdocs`,
`architecture-base-contenus.qmd` §3.1.

| Fichier | Contenu | Adresse publiée |
|----|----|----|
| `manifest-1.0.json` | un manifeste (un objet JSON) | <https://raw.githubusercontent.com/ofceweb/ofceweb/main/inst/schema/manifest-1.0.json> |
| `manifest-collectif-1.0.json` | un manifeste collectif (un tableau de manifestes) | <https://raw.githubusercontent.com/ofceweb/ofceweb/main/inst/schema/manifest-collectif-1.0.json> |

Les deux fichiers sont aussi livrés avec le package :

``` r

system.file("schema", package = "ofceweb")
```

Quelques règles à connaître :

- un manifeste de brouillon, dont l’`id` vaut `null`, n’est pas conforme
  : le format v1 ne s’applique qu’aux contenus publiés ;
- un champ inconnu est accepté, ce qui couvre les champs historiques de
  [`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md)
  (`wp`, `annee`, `version`, `stage`, `pdf-path`, `source-repo`,
  `ofceweb-version`…) ;
- les champs `author_ids`, `children`, `status`, `manifest_url` et
  `collected_at` sont réservés à l’agrégateur et interdits dans un
  manifeste source ;
- pour `categories` et `region`, seule la forme est contrôlée ; les
  valeurs hors des listes fermées sont signalées par le rapport de
  collecte, sans écarter le contenu.

## Valider en R

[`validate_manifest()`](https://ofceweb.github.io/ofceweb/reference/validate_manifest.md)
accepte un chemin de fichier, une URL ou une liste R, et rend toutes les
erreurs trouvées, en français :

``` r

library(ofceweb)

validate_manifest("manifest.json")
validate_manifest("https://www.ofce.fr/wp/2025/23/v1/manifest.json")
```

Elle s’appuie sur le package `jsonvalidate`, qui n’est pas installé avec
ofceweb : elle propose de l’installer au premier appel.

Le résultat contient le verdict et un tableau des erreurs :

``` r

res <- validate_manifest("manifest.json")
res$valid
#> [1] FALSE
res$errors
#> # A tibble: 2 × 4
#>   entry id                field message
#>   <int> <chr>             <chr> <chr>
#> 1    NA ofce-wp-2026-6-fr jel   champ obligatoire manquant.
#> 2    NA ofce-wp-2026-6-fr lang  valeur "de" non admise ; valeurs admises : fr, en.
```

La fonction ne lève pas d’erreur R sur un manifeste invalide ou sur un
fichier illisible : une boucle sur plusieurs manifestes continue
jusqu’au bout.

En plus du schéma,
[`validate_manifest()`](https://ofceweb.github.io/ofceweb/reference/validate_manifest.md)
vérifie deux règles qui relient plusieurs champs :

- `date_modified` est postérieure ou égale à `date_published` ;
- l’`id` commence par la valeur d’`institution` suivie d’un tiret
  (`ofce-…` pour `institution: ofce`).

Pour une liste R, les champs tableaux (`authors`, `categories`,
`keywords`, `jel`, `department`) s’écrivent avec
[`list()`](https://rdrr.io/r/base/list.html), comme dans
[`wp_manifest()`](https://ofceweb.github.io/ofceweb/reference/wp_manifest.md),
pour rester des tableaux JSON même avec un seul élément.

## Le manifeste collectif

Un pipeline qui publie de nombreux contenus d’un coup, comme le blog,
écrit un seul manifeste : un tableau JSON dont la première entrée décrit
l’ensemble (`id: ofce-blog`, `type: blog`) et dont les suivantes
décrivent chaque contenu (`parent: "ofce-blog"`). Chaque entrée suit le
schéma unitaire.

[`validate_manifest()`](https://ofceweb.github.io/ofceweb/reference/validate_manifest.md)
reconnaît un tableau JSON et contrôle chaque entrée. La colonne `entry`
donne la position de l’entrée fautive, et la colonne `id` son
identifiant quand elle en a un.

## Le manifeste du blog

[`render_blog()`](https://ofceweb.github.io/ofceweb/reference/render_blog.md)
écrit le manifeste collectif du blog dans `_site/manifest.json`, publié
à <https://www.ofce.fr/blog2024/manifest.json> à chaque déploiement. Il
est déclaré une seule fois dans `contentdb`, sous l’identifiant
`ofce-blog` : un nouveau post entre dans la base au rendu suivant, sans
nouvelle déclaration, et un post retiré du blog en sort.

La première entrée décrit le blog : `id: ofce-blog`, `type: blog`,
`media: site`, titre « Le blog de l’OFCE », `url` de la page d’accueil,
et pour `date_published` la date du plus ancien post. Viennent ensuite
une entrée par post publié, version française et traduction anglaise
chacune la sienne ; les brouillons (`draft: true`) n’y figurent pas.

| Post                                  | `type` | `institution` |
|---------------------------------------|--------|---------------|
| billet                                | `post` | `ofce`        |
| graphique de la semaine (`gow: true`) | `gow`  | `ofce`        |
| Écographe (`ecograph: true`)          | `gow`  | `ife`         |

L’`id` vient du dossier du post, en minuscules, `_` remplacé par `-` :
`{institution}-{type}-{annee}-{dossier}-{lang}`. Par exemple,
l’Écographe n°9, rangé dans `posts/2026/20261124_DG_eg/`, a pour `id`
`ife-gow-2026-20261124-dg-eg-fr`. Une traduction partage avec sa version
française le même `translation_id`, l’`id` sans la langue. La langue
vient du nom du fichier (`.en.qmd`), pas de l’en-tête.

Les autres champs viennent de l’en-tête du post : `title`, `subtitle`,
`authors` (les noms de `author`), `abstract` (`description`),
`categories`, `date_published` (`date`) et `image`. `url` et `pdf` sont
les adresses publiées du post et de son PDF. `keywords` et `jel` sont
vides. Pour un `gow`, les libellés de série « Écographe » et « EcoGraph
» sont retirés des catégories, et le numéro `nb` est recopié ; la
collecte ne le garde pas, car il n’est pas dans le schéma.

Chaque entrée est contrôlée au rendu. Une entrée invalide est écartée du
manifeste, avec un avertissement qui nomme le fichier du post et
l’erreur : un post fautif ne bloque pas la mise à jour des autres dans
la base. Sans le package `jsonvalidate`, le manifeste est écrit sans
contrôle, avec un avertissement.

## Valider hors de R

N’importe quel validateur JSON Schema compatible draft-07 peut contrôler
un manifeste avec le schéma publié, par exemple
[`ajv-cli`](https://github.com/ajv-validator/ajv-cli) :

``` bash
# Manifeste unitaire
npx ajv-cli validate --spec=draft7 --strict=false \
  -s manifest-1.0.json -d manifest.json

# Manifeste collectif : le schéma unitaire est passé en référence
npx ajv-cli validate --spec=draft7 --strict=false \
  -s manifest-collectif-1.0.json -r manifest-1.0.json -d manifest.json
```

Le verdict est le même qu’en R, sauf pour les deux règles qui relient
plusieurs champs (ordre des dates, préfixe de l’`id`), que seule
[`validate_manifest()`](https://ofceweb.github.io/ofceweb/reference/validate_manifest.md)
vérifie. Les messages d’erreur sont ceux de l’outil, en anglais.

## Exemples

Des exemples valides et invalides accompagnent le schéma :

``` r

system.file("schema", "exemples", package = "ofceweb")
```

- `valides/` : un manifeste minimal, un manifeste complet, un manifeste
  de PDF, le manifeste réel d’un document de travail en ligne et le
  manifeste collectif d’un blog ;
- `invalides/` : un fichier par règle ;
- `invalides.yml` : pour chaque fichier invalide, le champ et l’erreur
  attendus.

## Déclarer un contenu

Un manifeste publié n’entre dans la base des contenus qu’une fois
**déclaré** dans le journal du dépôt
[`ofceweb/contentdb`](https://github.com/ofceweb/contentdb) : un fichier
`registry/{annee}/{id}.json` par contenu, qui donne l’adresse du
manifeste, celle du PDF, la date, l’auteur et l’état de la dernière
déclaration (`published` ou `retired`). Le README de `contentdb`
explique comment déclarer, retirer ou republier un contenu.

Le format d’une déclaration est fixé par le schéma
`declaration-1.0.json`, livré avec le package et publié à
<https://raw.githubusercontent.com/ofceweb/ofceweb/main/inst/schema/declaration-1.0.json>.
[`check_registry()`](https://ofceweb.github.io/ofceweb/reference/check_registry.md)
contrôle tout le journal : le schéma de chaque déclaration, son
rangement (année sur quatre chiffres, `id` égal au nom du fichier, un
seul fichier par `id`) et, si on lui passe la liste des fichiers
supprimés, l’absence de suppression. La CI de `contentdb` lance ce
contrôle à chaque push et à chaque pull request ; on peut le lancer en
local depuis un clone du dépôt :

``` r

check_registry(".")
```

Lancé ailleurs qu’à la racine d’un clone, le contrôle s’arrête par une
erreur qui nomme le dossier où il attendait `registry/`. Un `registry/`
vide est accepté : « Journal vide : aucune déclaration. »

Des exemples de déclarations valides et invalides se trouvent dans
`system.file("schema", "exemples-declaration", package = "ofceweb")`.

## Collecter la base

[`collect_contents()`](https://ofceweb.github.io/ofceweb/reference/collect_contents.md)
construit la base des contenus depuis un clone de `contentdb` : elle lit
le journal, écarte les déclarations refusées par
[`check_registry()`](https://ofceweb.github.io/ofceweb/reference/check_registry.md),
télécharge chaque manifeste à son `manifest_url`, le valide comme
[`validate_manifest()`](https://ofceweb.github.io/ofceweb/reference/validate_manifest.md),
puis rend la base et la liste des anomalies.
[`write_contents()`](https://ofceweb.github.io/ofceweb/reference/write_contents.md)
écrit la base dans `contents.json` :

``` r

res <- collect_contents(".", previous = "contents.json")
res
#> ✔ Base collectée : 5 enregistrements, aucune anomalie.
write_contents(res, "contents.json")
```

La collecte est complète à chaque appel : tout le journal est relu et
tous les manifestes sont retéléchargés. Un contenu retiré (`retired`)
est collecté comme un contenu publié, et garde ce statut dans la base.

### Ce que contient un enregistrement

La base est un tableau JSON trié par `id`, où chaque `id` apparaît une
seule fois. Un enregistrement reprend les champs v1 de son manifeste,
dans l’ordre du schéma ; les champs historiques ou inconnus (`wp`,
`stage`, `source-repo`…) ne passent pas. Il ajoute cinq champs :

| Champ | Contenu |
|----|----|
| `author_ids` | une liste de `null`, de la longueur de `authors` : le rapprochement avec le référentiel des auteurs n’est pas encore fait |
| `children` | les `id` des contenus dont le `parent` désigne celui-ci, triés par `date_published` puis par `id` ; `[]` si aucun |
| `status` | `published` ou `retired`, celui de la déclaration (celle d’`ofce-blog` pour un post du blog) |
| `manifest_url` | l’adresse du manifeste qui a produit l’enregistrement |
| `collected_at` | la date et l’heure UTC du dernier téléchargement réussi |

Un manifeste collectif, comme celui du blog, donne un enregistrement par
entrée. À chaque collecte réussie, tous les enregistrements issus de ce
manifeste sont remplacés : un post absent du nouveau manifeste disparaît
de la base.

### Quand un manifeste échoue

Un manifeste qui ne répond pas, qui est invalide ou qui ne porte pas
l’`id` de sa déclaration n’arrête pas la collecte. Si la base précédente
est fournie (`previous`), les enregistrements qui venaient de ce
manifeste sont repris tels quels, avec leur ancien `collected_at` et
leur ancienne `manifest_url`, mais avec le `status` de la déclaration en
cours : un retrait déclaré prend effet même si le manifeste a disparu du
site. Sans base précédente, le contenu est absent. Pour un manifeste
collectif, une seule entrée invalide suffit à reprendre tout l’ensemble.
Un enregistrement qui a sa propre déclaration n’est jamais repris au nom
d’une autre : un post du blog déclaré à part dont le manifeste échoue
reprend son seul enregistrement, et le reste du blog vient du manifeste
du blog. Une entrée téléchargée passe toujours avant une entrée reprise,
et un manifeste téléchargé remplace tout ce qui venait de lui.

### Lire les anomalies

`res$anomalies` est un tableau à une ligne par anomalie : `type`, `id`
du contenu, `file` (le fichier de déclaration) et `message`, en
français.

| Type | Signification |
|----|----|
| `declaration_invalid` | déclaration refusée par [`check_registry()`](https://ofceweb.github.io/ofceweb/reference/check_registry.md), ignorée |
| `manifest_unreachable` | manifeste qui ne répond pas (404, erreur du serveur, délai de 30 secondes dépassé) |
| `manifest_invalid` | manifeste illisible ou refusé par la validation |
| `id_mismatch` | manifeste qui ne porte pas l’`id` de sa déclaration |
| `duplicate_id` | entrée d’un manifeste collectif écartée : son `id` est déjà pris par un contenu déclaré ou par une entrée précédente |
| `parent_unresolved` | `parent` qui ne désigne aucun contenu de la base ; l’enregistrement est gardé |
| `previous_invalid` | base précédente illisible : la collecte s’est faite sans elle |

Le message des trois types qui portent sur un manifeste dit si
l’enregistrement précédent a été repris.
