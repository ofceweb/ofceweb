# Déploie un profil personnalisé vers staging/repo/profile/

Wrapper de \[site2branch()\] pour les profils Quarto qui ne sont ni
\`"staging"\` ni \`"publish"\`. Pousse \`\_site_profile/\` vers la
branche \`site-profile\` et déclenche le workflow
\`ftp_deploy_profile.yml\` en lui passant le nom du profil en entrée. Le
FTP cible est \`staging/repo/profile/\` — sans numéro de version, le
profil jouant ce rôle.

## Usage

``` r
site2profile(
  path = ".",
  profile,
  progress = TRUE,
  trigger = TRUE,
  full_deploy = FALSE
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- profile:

  Nom du profil Quarto (doit correspondre à un fichier
  \`\_quarto-profile.yml\` dans le dépôt).

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- trigger:

  Logique. Déclenche \`ftp_deploy_profile.yml\` après le push. Défaut
  \`TRUE\`.

- full_deploy:

  Logique. Si \`TRUE\`, force la ré-émission complète vers le FTP.
  Défaut \`FALSE\`.

## Value

Invisible \`NULL\`.

## See also

\[deploy_prev()\], \[site2branch()\], \[site2staging()\]
