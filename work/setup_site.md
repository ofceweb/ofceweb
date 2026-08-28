# build site functions

## Concept 

From a repository, we have a set of functions that help set up a website, render it, deploy it to a branch for publication either on the OFCE servers or on through gh-pages.

We have three main functions
- setup_site()
- render_site()
- deploy_site()

plus a few helpers: site_version_up(), rescan_site(), encrypt_site() / remove_encrypt().

## setup_site()

setup_site functions should have the follwing workflow : 

### initialization
- scan all qmds in the repo , ignore those that start with "_". get all the titles if there's one in the yaml, use the filename (without qmd otherwise)
- copy from the package files (located for now in inst/setup_site/) :
  - the _quarto.yaml at the root of the repo
  - if in the scanned qmds there is no index.qmd, copy the index.qmd at the root of the repo
  - the content of the folder called wwww needs to be put at the root of the repo in a folder called www
  - the workflow folder which should see the contents of the folder being put in a ".github/workflows/" folder (files with a `.html` suffix in the package source get that suffix stripped on copy, so e.g. `ftp_deploy.yml.html` lands as `ftp_deploy.yml`)
  - and the `_extensions` folder


### Editing the quarto.yaml
- replace the stuff in other-links with the titles from the extracted quartos and the approriate href (file_path.html, basically)

- add an argument in the function : `ofce_host` , if TRUE , the site-url in the yml remains "https://www.ofce.fr/". if FALSE then we can remove site-path and site-url

- For the site-path , add an argument called "ofce_server_location" that takes by default the value `"staging"` . then add an argument "website_code" thats by default NULL. this argument should be a string with only letters, numbers and underscores. If this check fails, the website_code reverts to NULL. When NULL, the new variable website_path takes the name of the github repo as obtained by gert::git_remote_list() , the last bit (ofceweb.git without the git) . the site-path variable thus takes whatever is determined for website_path . coherently if ofce_host is false, this doesnt apply
- for now the only site-paths possible for ofce_server_location are "staging" or "wp"

- we add a website_title argument that is NULL by defaul, If not NULLthe title variable in the yaml takes, website_title, otherwise it takes the value of the title in index.qmd if there is one, and otherwise, the name of the repo.

- add a hypothesis argument, takes by default TRUE , and adapts the quarto.yml accordingly

- add an argument in the yaml called ofce_host (that matches ofce_host.)

- add _site in the gitgnore 

- if ofce_host is false, : execute the following commands to setup gh_pages 

---
git checkout --orphan gh-pages
git reset --hard # make sure all changes are committed before running this!
git commit --allow-empty -m "Initialising gh-pages branch"
git push origin gh-pages
---
and go back to whatever github branch we were in previously

The ftp-deploy must also be adapted. The `server-dir:` line in the `with:` section is set to `<repo_name>/` (or `<repo_name>/v0/` if versioning is on). In addition, the references to `secrets.FTP_USER` / `secrets.FTP_PASSWORD` in `ftp_deploy.yml` are rewritten to `secrets.STAGING_USER` / `secrets.STAGING_PASSWORD` (or `WP_*` if `ofce_server_location = "wp"`). `site_version_up()` updates the `server-dir:` line in sync with the `site-path`.

### versionning

in setup_site() versionning is an argument that takes TRUE or FALSE. TRUE is by default. When activated , the site-path argument in the _quarto.yml is augmented with a "v0" path. ie "site-path: staging/repo_name/v0/"
This only works with ofce_host = TRUE .
A sister function is to be added called site_version_up() . It only works if ofce_host: true in the yaml , and it takes an argument called custom_version . custom version is NULL  by default. if not null then v0 in site-path of the _quarto.yml is replaced by the custom_version. If NULL then upgrading the version is done by detecting the version and uppinsg it by one. The function must detect the last number on the character string ie if v0 , then version to up is 0 . if v0_1 then it becomes v0_2. Upping versions is done by 1 increment .
Version numbers must be alphanumeric with underscores only (no other signs accepted). 

Some examples :

v10 --> v11
v3_4 --> v3_5
v5_AS_34 -->  v5_AS_35
v5_AS42 -->  v5_AS43
v10_42A -->  v10_43A
0 --> 1 
6v --> 7v

In any case a message should be displayed inviting the used to manually modify in the quarto.yml if necessary

## render_site()

Build pipeline for a generic (non-bilingual) site initialized via `setup_site()`. Wipes `_site/`, runs `quarto::quarto_render()`, rebuilds the sitemap via `build_sitemap()`, and — if `encrypt_site: true` is set in `_quarto.yml` — runs `staticryptR::staticryptr()` over `_site/` using the password in the `STATICRYPT_PASSWORD` env var. Optionally pushes via `site2branch()` and starts a local preview with `servr::httw()` (with absolute `other-links` URLs rewritten to relative paths so navigation works locally).

## deploy_site()

Reads the `ofce_host` key from `_quarto.yml`. If `TRUE`, delegates to `site2branch()` (push of `_site` to the FTP deploy branch). If `FALSE`, runs `quarto publish gh-pages`. Prints the final site URL on success.

## rescan_site()

  - a function that scans for new qmds and rewrites the `other-links` section of the quarto yaml (full rewrite, not append — `index.qmd` is placed first if present)
  when adding pages to the other-links section it should be with the
  folloing syntax  :   
  
  other-links:
   - text: Annexes
     icon: newspaper
     href: annexes.html  
     
     Where -text is the title of the page if one is in the yaml, otherwise use the basename of the qmd, icon is newspaper bydefault and href is the path to html pages ie if the new_page.qmd is at the root then href is new_page.html , if it's under a subfolder at the root ie subfolder/new_page.qmd, then href is subfolder/new_page.html
     
## encrypt_site()

Enables static site encryption. Encryption itself is **not** done by this function: it is performed by `render_site()` via `staticryptR::staticryptr()` when the key `encrypt_site: true` is present in the `_quarto.yml`. `encrypt_site()` just sets up everything needed for that to work, both locally and on GitHub Actions.

Concretely, the function:

1. Adds / flips the `encrypt_site: true` key at the root of the `_quarto.yml` (idempotent).
2. Patches `.github/workflows/ftp_deploy.yml` to expose `STATICRYPT_PASSWORD` to the job (inserts an `env:` block right after `runs-on: ubuntu-latest` that reads `${{ secrets.STATICRYPT_PASSWORD }}`).
3. Prompts the user for a password (via `askpass` if available, otherwise `readline()`) — unless the `password` argument is provided directly.
4. Creates the GitHub secret `STATICRYPT_PASSWORD` on the current repo via `gh secret set` (resolves `owner/repo` from the `origin` remote). Prerequisite: `gh` installed and authenticated.
5. Writes `STATICRYPT_PASSWORD=...` into a `.Renviron` at the repo root and adds `.Renviron` to `.gitignore`, so that local renders have access to the password without shell configuration.

Arguments: `path` (default `"."`) and `password` (default `NULL` → interactive prompt).

## remove_encrypt()

Undoes what `encrypt_site()` did. Idempotent. Flips `encrypt_site` to `false` in the `_quarto.yml`, removes the `env: STATICRYPT_PASSWORD` block from `ftp_deploy.yml`, and (unless `delete_secret = FALSE`) removes the GitHub secret `STATICRYPT_PASSWORD` via `gh secret delete`. Does not touch the local `.Renviron`.
