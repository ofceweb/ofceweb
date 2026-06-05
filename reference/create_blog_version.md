# Créer une version blog d'un article EcoGaphe

Transforme un fichier .qmd du dossier \`relecture/\` en une version blog
prête à publier. La fonction extrait le YAML et le corps du document,
adapte les métadonnées pour le format blog (ajout du numéro, de l'URL,
du thumbnail), puis copie l'ensemble des fichiers nécessaires (images,
données) dans un nouveau répertoire au niveau parent.

## Usage

``` r
create_blog_version(issue = 9, year = 2026)
```

## Arguments

- issue:

  Numéro du GOW (entier). Sera complété avec un zéro si un seul chiffre
  (par ex. 9 devient "09").

- year:

  Année de publication (entier, par défaut 2026).

## Value

NULL (appelée pour ses effets de bord : création de fichiers).

## Details

Le fichier source doit se trouver dans \`relecture/\` et suivre la
convention de nommage \`year_issue\_\*.qmd\`. Le thumbnail correspondant
doit être dans \`relecture/thumbnails/\` et les données éventuelles dans
\`relecture/data/\`.

## Webblog Users
