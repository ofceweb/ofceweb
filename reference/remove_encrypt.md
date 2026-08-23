# Désactive le chiffrement statique du site

\`r lifecycle::badge("deprecated")\`

Cette fonction est dépréciée. Le chiffrement étant désormais piloté
\*\*exclusivement par le secret GitHub \`STATICRYPT_PASSWORD\`\*\*, pour
désactiver le chiffrement il suffit de supprimer ce secret :

“\` gh secret delete STATICRYPT_PASSWORD –repo owner/repo “\`

Si le secret est absent, le déploiement s'effectue sans chiffrement.

## Usage

``` r
remove_encrypt(path = ".", delete_secret = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- delete_secret:

  Ignoré.

## Value

Invisible \`NULL\`.

## See also

\[encrypt_site()\]
