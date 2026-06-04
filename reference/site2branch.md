# Push a rendered site folder to a Git branch

Commits the contents of \`\_site/\` (or another folder produced by a
static site generator) into an orphan-style commit and force-pushes it
to the \`site-deploy\` branch (or what is spefiied in \`branch\`) of the
\`origin\` remote. Optionally triggers a downstream GitHub Actions
workflow (e.g. an FTP deploy) via the \`workflow_dispatch\` API (check
your default branch is \`main\`).

## Usage

``` r
site2branch(
  path = ".",
  branch = "site-deploy",
  source = "_site",
  progress = TRUE,
  trigger = TRUE,
  workflow = "ftp_deploy.yml",
  full_deploy = FALSE
)
```

## Arguments

- path:

  \`\[character(1)\]\`  
  Path to the root of the local Git repository. Defaults to
  \[here::here()\].

- branch:

  \`\[character(1)\]\`  
  name of the branch targeted ("site-deploy")

- source:

  \`\[character(1)\]\`  
  path to the folder to deploy ("\_site")

- progress:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default), git output is forwarded to the console.

- trigger:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default to \`TRUE\`), calls \[trigger_ftp_deploy()\]
  after a successful push to dispatch the FTP deploy workflow. Failures
  are caught and reported as warnings so the overall push is not rolled
  back. Usually, a push on site-deploy is going to trigger the deploy.

- workflow:

  \`\[character(1)\]\`  
  name of the workflow to trigger

- full_deploy:

  \`\[logical(1)\]\`  
  If \`FALSE\` (default), the \`.ftp-deploy-sync-state.json\` file is
  carried forward from the remote branch so the FTP upload remains
  incremental. Set to \`TRUE\` to zero out every hash in the state file
  before pushing, which causes ftp-deploy to re-upload every file
  without deleting anything unrelated on the FTP server.

## Value

Invisibly returns \`NULL\`. Called for its side effects.

## Details

Credentials are resolved in the following order: 1. The \`DEPLOY_PAT\`
environment variable (recommended on CI). 2. The OS credential store
(macOS Keychain, Windows GCM, Linux libsecret) via the credentials
package — suitable for interactive local use.

SSH remote URLs are automatically converted to HTTPS before pushing
because libgit2 cannot use the system SSH agent.

## Examples

``` r
if (FALSE) { # \dontrun{
# Push _site/ and trigger the FTP workflow
site2branch()

# Push only, without triggering the downstream workflow
site2branch(trigger = FALSE)

# Force a full re-upload (ignore incremental state)
site2branch(full_deploy = TRUE)
} # }
```
