# Désactive le chiffrement statique du site

Annule les effets de \[encrypt_site()\] :

1.  Bascule la variable \`encrypt_site\` à \`false\` dans le
    \`\_quarto.yml\`.

2.  Retire le bloc \`env: STATICRYPT_PASSWORD\` du job
    \`.github/workflows/ftp_deploy.yml\`.

3.  Supprime le secret GitHub \`STATICRYPT_PASSWORD\` du dépôt via
    \`gh\` (si \`gh\` est installé et que le dépôt a un remote
    \`origin\`).

## Usage

``` r
remove_encrypt(path = ".", delete_secret = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- delete_secret:

  Logique. Si \`TRUE\` (défaut), tente de supprimer le secret GitHub
  \`STATICRYPT_PASSWORD\` via \`gh secret delete\`.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Toutes les étapes sont idempotentes : si un élément n'existe pas,
l'étape est simplement ignorée.

## See also

\[encrypt_site()\]
