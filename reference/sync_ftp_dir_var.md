# Resynchronise une variable GitHub de répertoire FTP juste avant déploiement

Pousse \`dir_value\` (normalisé avec un slash final) vers la variable
GitHub Actions \`name\` via \[set_gh_var()\]. No-op silencieux si
\`dir_value\` est \`NULL\`/vide (rien à synchroniser). Un échec
réseau/jeton produit un avertissement non bloquant – ne fait jamais
échouer l'appelant.

## Usage

``` r
sync_ftp_dir_var(root, name, dir_value)
```

## Arguments

- root:

  Chemin vers la racine du dépôt.

- name:

  Nom de la variable GitHub Actions (ex. \`"FTP_SERVER_DIR"\`).

- dir_value:

  Chaîne ou \`NULL\`. Chemin FTP cible ; \`NULL\`/vide = rien à faire.

## Value

Invisible \`NULL\`.

## Details

Centralise la resynchronisation appelée par
\[deploy_wp()\]/\[deploy_pb()\]/ \[deploy_prev()\] immédiatement avant
de déclencher le workflow FTP correspondant, pour rester correcte même
si \`\_quarto.yml\`/ \`\_quarto-staging.yml\`/\`\_quarto-publish.yml\` a
été modifié en dehors de \`setup\_\*()\`/\`\*\_version_up()\` (ces
derniers restent la source de vérité "proactive" ; ceci est un filet de
sécurité "au moment du déploiement").

## See also

\[set_gh_var()\], \[deploy_wp()\], \[deploy_pb()\], \[deploy_prev()\]
