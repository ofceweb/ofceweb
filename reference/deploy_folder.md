# Deploy a rendered ad-hoc folder site to staging

Pushes the \`\_site/\` folder (previously rendered by
\[render_folder()\]) to a git branch and triggers FTP deployment to
\`staging.ofce.fr\`. The slug is read from the persisted metadata
(\`\_site/.adhoc-meta.json\`) if not supplied.

## Usage

``` r
deploy_folder(
  path = ".",
  slug = NULL,
  encrypt = TRUE,
  progress = TRUE,
  trigger = TRUE,
  full_deploy = FALSE,
  as_job = FALSE
)
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

- as_job:

  \`\[logical(1)\]\`  
  If \`TRUE\` and RStudio is available, runs as a background job.
  Defaults to \`FALSE\` (push+trigger is usually fast enough).

## Value

Invisibly returns \`NULL\`. Prints the resulting URL on success.

## Details

\## Pre-flight checks

\- Verifies that \`\<path\>/\_site/\` exists (must have been created by
\[render_folder()\] or manually). - If \`encrypt = FALSE\` is requested,
checks whether the installed \`ftp_deploy_profile.yml\` workflow
supports the \`.no-staticrypt\` marker (added in recent versions). If
not, warns and proceeds with encryption.

\## Workflow auto-install

The first time \`deploy_folder()\` is called on a repo, it auto-installs
\`.github/workflows/ftp_deploy_profile.yml\` from the package if
missing. This is an idempotent, additive operation:

\- On unprotected default branches, the workflow is committed
directly. - On protected default branches, a PR is opened and you're
asked to merge it (one-time per repo). After merge, subsequent calls
proceed normally.

## See also

\[render_folder()\], \[publish_folder()\], \[preview_folder()\],
\[deploy_prev()\]
