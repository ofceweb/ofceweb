# Notifie par mail la publication de nouveaux billets du blog

Compare la base des posts (sortie de \[posts_db()\]) au registre des
billets déjà notifiés (\`posts_notified.txt\`, un \`postID\` par ligne,
commité dans le dépôt) et envoie un mail par nouveau billet, avec
blastula, à la liste de destinataires déclarée dans \`\_notify.yml\`.
Chaque mail porte en pièce jointe un fichier texte avec les métadonnées
du billet (titre, auteurs, date, catégories, description, URL). Appelée
par \[render_blog()\] après le déploiement quand \`notify = TRUE\` (par
défaut avec \[publish_blog()\]).

## Usage

``` r
notify_new_posts(posts, root = ".", commit = TRUE)
```

## Arguments

- posts:

  Tibble des posts, sortie de \[posts_db()\].

- root:

  Racine du blog. Défaut \`"."\`.

- commit:

  Logique. Si \`TRUE\` (défaut), commite le registre mis à jour.

## Value

Les \`postID\` notifiés, invisiblement.

## Details

Fichier \`\_notify.yml\` (à la racine du blog) : “\`yaml from:
blog.ofce@gmail.com sender_name: Blog de l'OFCE \# optionnel to: -
prenom.nom@sciencespo.fr cc: \[\] \# optionnel bcc: \[\] \# optionnel
subject: "Nouveau billet : title" \# optionnel smtp: provider: gmail \#
ou host/port/use_ssl user: blog.ofce@gmail.com creds_file: gmail_creds
\# optionnel, usage local body: \| \# optionnel (ou body_file: ...)
Bonjour,

\*\*title\*\* par authors vient de paraître : url “\` Sans
\`\_notify.yml\`, rien n'est fait.

Le corps du mail est un gabarit Markdown interprété par
\[glue::glue()\], donné dans \`body\` ou dans un fichier
(\`body_file\`), à défaut le gabarit par défaut de \[mail_new_post()\].
Champs disponibles : \`title\`, \`title_en\`, \`authors\`, \`date\`,
\`categories\`, \`description\`, \`description_en\`, \`url\`,
\`url_en\`, \`postID\`.

Identifiants SMTP, dans l'ordre : - la variable d'environnement
\`OFCE_SMTP_PASSWORD\` (secret du dépôt en CI, \`~/.Renviron\` en
local), avec \`smtp\$user\` et \`smtp\$provider\` ou
\`smtp\$host\`/\`smtp\$port\`/\`smtp\$use_ssl\` ; - le fichier
\`smtp\$creds_file\`, créé une fois avec
\[blastula::create_smtp_creds_file()\] (à ne pas commiter).

Si le registre n'existe pas, il est initialisé avec tous les billets
existants sans envoyer de mail (pour éviter de notifier tout
l'historique). Un billet dont l'envoi a échoué (ou si le SMTP n'est pas
configuré) n'est pas inscrit au registre et sera notifié à la
publication suivante. Les billets \`draft: true\` sont ignorés.
