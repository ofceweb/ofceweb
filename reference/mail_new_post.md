# Compose le mail annonçant un billet

Équivalent pour le blog d'une fonction de type \`mail_xxx(id)\`
construisant un mail blastula : le gabarit Markdown est rempli avec les
champs du billet par \[glue::glue_data()\] puis passé à
\[blastula::compose_email()\].

## Usage

``` r
mail_new_post(post, template = .default_notify_template)
```

## Arguments

- post:

  Liste nommée des champs du billet (\`title\`, \`authors\`, \`date\`,
  \`categories\`, \`description\`, \`url\`, ... ; voir
  \[notify_new_posts()\]).

- template:

  Gabarit Markdown du corps du mail. Défaut : gabarit standard du blog.

## Value

Un objet \`blastula_message\`.
