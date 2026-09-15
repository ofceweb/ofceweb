# Vérifie que le package ofce installé satisfait la version minimale requise

Les extensions Quarto OFCE posées par \[ofce::setup_quarto()\] dépendent
de la version du package \*\*ofce\*\* lui-même (gabarits, logique
d'installation). Contrairement à \[check_quarto_version()\] (qui se
contente d'avertir), cette vérification est \*\*bloquante\*\* : à la
différence de la CLI Quarto, un package ofce trop ancien ou absent fait
typiquement échouer ou corrompre silencieusement l'installation des
extensions, il est donc préférable d'interrompre immédiatement plutôt
que de laisser \`setup\_\*()\` continuer dans un état incohérent.

## Usage

``` r
check_ofce_version(min = "1.3.39")
```

## Arguments

- min:

  Version minimale requise (chaîne comparable, ex. \`"1.3.39"\`).

## Value

Invisible \`TRUE\` si la version installée satisfait \`min\`. N'a jamais
d'autre retour : soit la condition est remplie, soit la fonction
interrompt l'exécution via \[cli::cli_abort()\].
