# Active le chiffrement statique du site

\`r lifecycle::badge("deprecated")\`

Cette fonction est dépréciée. Le chiffrement est désormais géré
\*\*exclusivement en CI\*\* (GitHub Actions), juste avant le transfert
FTP, via le secret \`STATICRYPT_PASSWORD\` défini sur le dépôt GitHub.
Il n'est plus nécessaire de configurer quoi que ce soit localement.

Pour activer le chiffrement sur un dépôt, définir le secret GitHub
directement :

“\` gh secret set STATICRYPT_PASSWORD –repo owner/repo “\`

Si le secret est absent, le déploiement s'effectue sans chiffrement.

## Usage

``` r
encrypt_site(path = ".", password = NULL)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- password:

  Ignoré.

## Value

Invisible \`NULL\`.

## See also

\[remove_encrypt()\]
