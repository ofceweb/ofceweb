# Push a rendered site folder to a Git branch, set for publish

Commits the contents of \`\_site_publish/\` into an orphan-style commit
and force-pushes it to the \`site-publish\` branch of the \`origin\`
remote. Triggers a downstream GitHub Actions workflow (e.g. an FTP
deploy) via the \`workflow_dispatch\` API (check your default branch is
\`main\`).

## Usage

``` r
site2publish(path = ".", progress = TRUE, trigger = TRUE, full_deploy = FALSE)
```

## Arguments

- path:

  \`\[character(1)\]\`  
  Path to the root of the local Git repository. Defaults to
  \[here::here()\].

- progress:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default), git output is forwarded to the console.

- trigger:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default to \`FALSE\`), calls \[trigger_ftp_deploy()\]
  after a successful push to dispatch the FTP deploy workflow. Failures
  are caught and reported as warnings so the overall push is not rolled
  back. Usually, a push on site-deploy is going to trigger the deploy.

- full_deploy:

  \`\[logical(1)\]\`  
  Passed to \[site2branch()\]. Set to \`TRUE\` to force a complete
  re-upload.

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
} # }
```
