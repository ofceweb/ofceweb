# Trigger a GitHub Actions workflow via \`workflow_dispatch\`

Sends a \`workflow_dispatch\` event to the GitHub Actions API to
manually start a workflow (typically an FTP deploy job). This is called
automatically by \[site2branch()\] unless \`trigger = FALSE\`.

## Usage

``` r
trigger_action(
  root = ".",
  workflow = "ftp_deploy.yml",
  branch = NULL,
  inputs = list()
)
```

## Arguments

- root:

  \`\[character(1)\]\`  
  Path to the local Git repository used to resolve the GitHub owner and
  repository name from the \`origin\` remote URL. Defaults to
  \[here::here()\].

- workflow:

  \`\[character(1)\]\`  
  File name of the workflow to dispatch (e.g. \`"ftp_deploy.yml"\`).

- branch:

  \`\[character(1)\]\`  
  Branch on which the workflow will be run. Defaults to \`NULL\`, which
  auto-detects the repository's default branch via the GitHub API.

- inputs:

  \`\[list()\]\`  
  Named list of workflow inputs passed to the \`workflow_dispatch\`
  event (e.g. \`list(profile = "review")\`). Defaults to an empty list
  (no inputs).

## Value

Invisibly returns \`NULL\`. Called for its side effects.

## Details

The GitHub token is resolved in the following order: 1. The
\`DEPLOY_PAT\` environment variable — \*\*required on CI\*\* because the
built-in \`GITHUB_TOKEN\` cannot dispatch other workflows (GitHub blocks
it to prevent recursive runs). 2. The OS credential store via gitcreds —
suitable for interactive local use.

## Other

## Examples

``` r
if (FALSE) { # \dontrun{
trigger_action()
trigger_action(workflow = "deploy.yml")
} # }
```
