# Copie les fichiers de police et, sous Windows, les enregistre pour tous les utilisateurs

L'inscription passe par la ruche machine \`HKLM\` : les fichiers vivant
dans \`C:/Windows/Fonts\`, un simple nom de fichier suffit comme valeur.

## Usage

``` r
copy_font_files(files, dest_dir)
```
