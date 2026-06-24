# Vérifie la structure d'un dépôt de prévision OFCE

Inspecte les fichiers de configuration (\`\_quarto.yml\`,
\`\_quarto-staging.yml\`, \`\_quarto-publish.yml\`), la structure de
dossiers, et les ressources GitHub Actions pour détecter les problèmes
bloquants avant un rendu ou un déploiement.

## Usage

``` r
check_prev(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- verbose:

  Logique. Si \`TRUE\` (défaut), affiche les diagnostics avec
  \[cli::cli_alert_success()\], \[cli::cli_alert_warning()\] et
  \[cli::cli_alert_danger()\].

## Value

Un data frame (invisible) à trois colonnes : \`field\` (chr), \`status\`
(\`"ok"\`, \`"warning"\`, \`"error"\`) et \`message\` (chr).

## Details

Contrôles effectués :

1.  Nom du dossier conforme à \`prevYY03\|9\` (ex. \`prev2603\`)

2.  Présence des sous-dossiers \`france/\`, \`inter/\`, \`fiches/\`,
    \`tableaux_comptes/\`, \`data_pays/\`

3.  \`\_quarto.yml\` présent et lisible

4.  Marqueur \`ofce_prev: true\` présent

5.  Champs \`prev\`, \`annee\`, \`mois\` présents dans \`\_quarto.yml\`

6.  \`project.type: ofce-website\` présent dans \`\_quarto.yml\`

7.  Section \`profile\` de \`\_quarto.yml\` : \`default: staging\` et
    groupe \`\[staging, publish\]\` (avertissements non bloquants si
    modifiés) ; vérifie que les fichiers \`\_quarto-profil.yml\`
    existent pour chaque profil déclaré

8.  \`\_quarto-staging.yml\` présent avec \`version\`, \`site-path\` de
    la forme \`staging/prevYYMM/vN\`, \`encrypt_site: true\`,
    \`comments.hypothesis: true\`, et \`project.output-dir:
    \_site_staging\`

9.  \`\_quarto-publish.yml\` présent avec \`site-path\` de la forme
    \`prev/prevYYMM\`, \`encrypt_site: false\`, \`comments.hypothesis:
    false\`, et \`project.output-dir: \_site_publish\`

10. Cohérence du \`prev\` id entre \`\_quarto.yml\` et les deux profils

11. \`.github/workflows/ftp_deploy_staging.yml\` présent

12. \`.github/workflows/ftp_deploy_publish.yml\` présent

13. \`.github/workflows/ftp_deploy_profile.yml\` présent

14. Variables GitHub \`FTP_STAGING_DIR\` et \`FTP_PUBLISH_DIR\` définies
    (vérification via \`gh\` CLI, avec fallback silencieux si absent)

15. Secret GitHub \`STATICRYPT_PASSWORD\` défini (warning non bloquant —
    le rendu local fonctionne sans lui, mais le workflow CI staging
    échouera)

## Prévision Users

## See also

\[setup_prev()\], \[render_prev()\]
