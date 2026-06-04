# Active le chiffrement statique du site

Configure le site courant pour qu'il soit chiffré au moment du render
via \`staticrypt\` (étape gérée directement par \[render_site()\]
lorsque la variable \`encrypt_site\` du \`\_quarto.yml\` vaut \`true\`).
Concrètement :

1.  Bascule la variable \`encrypt_site\` à \`true\` dans le
    \`\_quarto.yml\` (idempotent ; ajoutée si absente).

2.  Ajoute la variable d'environnement \`STATICRYPT_PASSWORD\` au job
    \`.github/workflows/ftp_deploy.yml\` (idempotent).

3.  Demande un mot de passe à l'utilisateur et le stocke comme secret
    GitHub du dépôt sous le nom \`STATICRYPT_PASSWORD\` via \`gh\`.

4.  Enregistre \`STATICRYPT_PASSWORD\` dans le \`.Renviron\` à la racine
    du dépôt (et l'ajoute au \`.gitignore\`) afin que les renders locaux
    disposent du mot de passe sans configuration shell.

## Usage

``` r
encrypt_site(path = ".", password = NULL)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- password:

  Chaîne ou \`NULL\` (défaut). Si \`NULL\`, l'utilisateur est invité à
  saisir le mot de passe (masqué si \`askpass\` est disponible).

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Pré-requis : l'outil \`gh\` doit être installé et authentifié (\`gh auth
login\`) avec les droits d'administration sur le dépôt.

## See also

\[setup_site()\], \[deploy_site()\]
