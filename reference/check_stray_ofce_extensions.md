# Détecte les extensions Quarto OFCE périmées dans \`\_extensions/\`

Depuis que les extensions Quarto OFCE sont installées et mises à jour
via \[ofce::setup_quarto()\] (qui les récupère depuis le dépôt GitHub
\`OFCE/ofce-quarto-extensions\`, sous \`\_extensions/ofce/...\`), toute
extension OFCE trouvée ailleurs — à plat directement sous
\`\_extensions/\` (ancienne convention), ou sous \`\_extensions/ofce/\`
mais absente du paquet canonique (ex. \`ofce/pb\`, retiré du paquet) —
est un résidu d'une installation antérieure à cette migration.

## Usage

``` r
check_stray_ofce_extensions(root = ".")
```

## Arguments

- root:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

## Value

Invisible, le vecteur (éventuellement vide) des chemins repérés comme
périmés.

## Details

Cette fonction ne fait que \*\*signaler\*\* ces dossiers via
\[cli::cli_alert_warning()\] ; elle ne supprime jamais rien
automatiquement.
