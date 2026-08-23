# Soumet un post de blog pour relecture dans ofce/Blog_relecture

Orchestre la soumission d'un post de blog Quarto :

1.  Vérifie la structure du post via \[check_blog()\].

2.  Scanne le \`.qmd\` pour identifier toutes ses dépendances fichier
    via \[scan_qmd_deps()\].

3.  Met à jour le clone local de \`blog_relecture\`.

4.  Crée une branche \`relecture/\<slug\>\`.

5.  Copie le \`.qmd\` et ses dépendances dans \`relecture/\<slug\>/\`.

6.  Teste la compilation dans l'environnement renv de \`blog_relecture\`
    via \[callr::r()\] ; installe les packages manquants et met à jour
    le lockfile si nécessaire.

7.  Committe et pousse la branche.

8.  Ouvre une pull request vers \`main\`.

## Usage

``` r
submit_blog(
  path = ".",
  slug = NULL,
  blog_relecture_path = "~/Documents/GitHub/blog_relecture",
  open_pr = TRUE,
  check = TRUE
)
```

## Arguments

- path:

  Chemin vers le dossier du post ou vers le \`.qmd\` directement. Défaut
  \`"."\`.

- slug:

  Identifiant du post (nom du sous-dossier créé dans \`relecture/\`).
  Dérivé automatiquement du nom du \`.qmd\` si \`NULL\`.

- blog_relecture_path:

  Chemin local vers le clone de \`ofce/Blog_relecture\`. Défaut
  \`"~/Documents/GitHub/blog_relecture"\`.

- open_pr:

  Logique. Ouvre une pull request GitHub après le push. Défaut \`TRUE\`.

- check:

  Logique. Lance \[check_blog()\] avant la soumission et bloque sur les
  erreurs. Défaut \`TRUE\`.

## Value

Invisible : URL de la PR créée, ou \`NULL\` si \`open_pr = FALSE\`.

## Details

En cas d'échec de la compilation, la branche et les fichiers copiés sont
supprimés — \`blog_relecture\` n'est pas modifié.

## See also

\[check_blog()\], \[scan_qmd_deps()\]
