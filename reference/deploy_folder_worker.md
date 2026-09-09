# Worker function for deploy_folder (internal synchronous implementation)

Worker function for deploy_folder (internal synchronous implementation)

## Usage

``` r
deploy_folder_worker(path, slug, encrypt, progress, trigger, full_deploy)
```

## Arguments

- path:

  \`\[character(1)\]\`  
  Folder to deploy (relative or absolute). Defaults to \`"."\`.

- slug:

  \`\[character(1)\]\`  
  Deployment identifier (must match the slug used in
  \[render_folder()\]). If \`NULL\` (default), read from
  \`\_site/.adhoc-meta.json\` or recomputed from the folder's path.

- encrypt:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default), the deployed site is encrypted via staticrypt
  (if \`STATICRYPT_PASSWORD\` is configured). Set to \`FALSE\` to
  publish unencrypted even if the password is set (via a
  \`.no-staticrypt\` marker file; requires the updated
  \`ftp_deploy_profile.yml\` workflow).

- progress:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default), progress is reported to the console.

- trigger:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default), triggers the FTP deployment workflow via
  \`workflow_dispatch\` after the git push. Set to \`FALSE\` to push
  only.

- full_deploy:

  \`\[logical(1)\]\`  
  If \`TRUE\`, forces the FTP workflow to re-upload all files (ignores
  incremental upload state). Defaults to \`FALSE\`.

## Value

Invisibly returns the resulting URL (character string).
