# Vérifie que la CLI Quarto installée satisfait la version minimale requise

Les gabarits et extensions OFCE (voir \[ofce::setup_quarto()\])
supposent une CLI Quarto récente. Cette fonction se contente de
\*\*signaler\*\* — jamais d'interrompre — un écart de version via
\[cli::cli_alert_warning()\], pour laisser les fonctions \`setup\_\*()\`
continuer au mieux.

## Usage

``` r
check_quarto_version(min = "1.9.38")
```

## Arguments

- min:

  Version minimale requise (chaîne comparable, ex. \`"1.9.38"\`).

## Value

Invisible, \`TRUE\` si la version installée satisfait \`min\` (ou
\`FALSE\` sinon, y compris si la CLI Quarto est introuvable).
