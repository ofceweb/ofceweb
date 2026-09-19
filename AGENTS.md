## FTP deployment architecture

### Production — Content Deployment (`ftp_deploy.yml` / `ftp_deploy_publish.yml`)
- Credentials : `FTP_SERVER` / `FTP_USER` / `FTP_PASSWORD`
- Destination : `${{ vars.FTP_SERVER_DIR }}`
  - **WP**: `{annee}/{wp}/` or `{annee}/{wp}/v{n}` (with version suffix)
  - **Prevision publish**: `prev/prev{YYMM}`
- Effective server path (production): paths under `/wp/` or `/prev/`

### Production — Redirection (`ftp_redirect.yml`)
- Credentials : `FTP_SERVER` / `FTP_USER` / `FTP_PASSWORD`
- Variable `FTP_REDIRECT_DIR` : parent path for stable redirect (without version segment)
  - **WP**/**PB**: `{annee}/{wp}/` / `pb/{pb}/` → generates `index.html` redirecting to latest version
  - **Prevision**: `derniere/` → redirects to current published prevision
- Branch: `site-redirect` (separate from content branches)
- `push_wp_redirect()`/`push_pb_redirect()` compute the parent dir by stripping the trailing `/<version>` segment from `site-path`, matched by value (not by a numeric regex) — a custom/suffixed version (e.g. `v2_corr`, `v5_AS42`) must still be stripped correctly.
- **Automatic vs. manual**: for WP/PB, called automatically from `deploy_wp()`/`deploy_pb()` on every production deploy (redirect always follows the current version). For `prev`, `push_prev_redirect()` is **not** called automatically — republishing a prevision can also mean *correcting an old one*, in which case `/prev/derniere/` must not be repointed; call it manually once a new prevision should become "current".

### Staging — Content Deployment (`ftp_deploy_staging.yml`)
- Credentials : `FTP_SERVER` / `STAGING_USER` / `STAGING_PASSWORD`
- The staging FTP user has a **chroot on `www/staging/`**
- `FTP_STAGING_DIR` is set by `setup_prev()` / `setup_wp()` to `{repo}/{version}/`
- Effective server path : `www/staging/{repo}/{version}/`

### Staging — Redirection (`ftp_redirect_staging.yml`)
- Credentials : `FTP_SERVER` / `STAGING_USER` / `STAGING_PASSWORD`
- Variable `FTP_STAGING_REDIRECT_DIR` : parent path for staging redirect
  - **Prevision**: `prev{YYMM}/` → generates `index.html` redirecting to latest version
  - **WP**/**PB**: `{repo}/` → generates `index.html` redirecting to latest version (`push_wp_staging_redirect()`/`push_pb_staging_redirect()`, reading the versioned `website.site-url` of the form `https://staging.ofce.fr/{repo}/{version}/`)
  - Effective server path: `www/staging/prev{YYMM}/` or `www/staging/{repo}/`
- Branch: `site-staging-redirect` (separate from staging content branch `site-staging`)
- Called automatically: for `prev`, from `render_prev()` after `site2staging()`; for WP/PB, from `deploy_wp()`/`deploy_pb()` on every staging FTP deploy.

## Console verbosity conventions (`setup_wp()`/`setup_pb()`)

- `check_gh_setup()` (called by `setup_wp()`/`setup_pb()`/`setup_prev()` with `bump_cache = FALSE`) prints a single condensed `cli_alert_success()` line ("gh installé et configuré à {user_name} <{user_email}> (jeton : {source})") when all 4 sub-checks (`gh:cli`, `gh:auth`, `gh:deploy_pat`, `git:identity`) pass. It falls back to one line per check (as before) only when at least one fails. `check_wp()`/`check_pb()`/`check_prev()` still call it with `verbose = FALSE` and read the returned `data.frame` themselves — unaffected.
- Template installation (`_quarto.yml`, `index.qmd`, `annexes.qmd`, `news.qmd`, `www/`) no longer prints a success/info line per file. Each is tracked into a `tmpl_status` named vector (`"copié"`/`"existant"`/`"synchronisé"`) and reported as one `cli_alert_info("Gabarits : ...")` line after the `www/` copy step.
- `set_gh_var(root, name, value, verbose = TRUE)` gained a `verbose` argument and now always returns (invisibly) `list(ok = logical, message = chaîne)`. `setup_wp()`/`setup_pb()` call it with `verbose = FALSE` for `FTP_SERVER_DIR`/`FTP_REDIRECT_DIR`/`FTP_STAGING_DIR` and collapse the results into one `cli_alert_success("Variables GitHub mises à jour : ...")` (+ a separate warning line listing any that failed). All other callers (`wp_redirect.R`, `pb_redirect.R`, `prev_redirect.R`, `site_redirect.R`, `render_wp()`, `render_pb()`, `*_version_up()`, `setup_prev()`, `setup_site()`) keep the default `verbose = TRUE` and are unaffected.

## Registry consistency check in `check_wp()`/`check_pb()`

- `registry_diag_rows(entries, source_repo, local_id, local_annee = NULL, kind = c("wp", "pb"))` (`R/git_utils.R`) is a shared, **read-only** diagnostic: it compares `_quarto.yml`'s `wp`/`annee` (or `pb`) against the matching entry in `ofce/wp-registry` (found via `repo_slug_equal()` on the `origin` remote), and returns `list(field = "registry", status, message)` rows for `add_diag()`. Unlike `sync_wp_registry_state()`/`sync_pb_registry_state()` (called by `setup_wp()`/`setup_pb()`/`publish_wp()`/`publish_pb()`), it never writes `_quarto.yml` — safe to call unconditionally from `check_wp()`/`check_pb()` on every invocation.
- `check_wp()` calls it with `fetch_wp_entries()` + `yml$wp`/`yml$annee`, `kind = "wp"`; `check_pb()` with `fetch_pb_entries()` + `yml$pb` (no `local_annee` — PBs are numbered sequentially, independent of year), `kind = "pb"`. Both fetch calls are unauthenticated (`raw.githubusercontent.com`), so this check runs even without `gh` auth.
- Outcomes: `"ok"` when local and registry numbers match (or when absent from both, i.e. still a draft); `"warning"` for any mismatch, a registered entry not yet reflected locally (relancer `setup_wp()`/`setup_pb()`), a local number no longer found in the registry, an unreachable registry, or an unresolved `origin` remote. `check_prev()` has no equivalent — previsions have no registry (`repo_type.R` lists `registry = NULL` for `prev`).

## JSON read/write conventions

- Always pair `jsonlite::write_json()` (and `toJSON()`) with `auto_unbox = TRUE` when writing scalar fields (e.g. `slug`, `stage`, `pb`). Without it, every scalar is wrapped in a single-element JSON array (`"slug": ["x"]` instead of `"slug": "x"`), which then round-trips back as a length-1 **list** on read — silently breaking anything expecting a plain string (e.g. GitHub `workflow_dispatch` inputs, which reject arrays). This caused a real bug in `adhoc_site.R`'s ad-hoc metadata file (`.adhoc-meta.json`).
- On the read side, `jsonlite::read_json()` defaults to `simplifyVector = FALSE`; pass `simplifyVector = TRUE` when you expect scalar fields back as atomic vectors rather than lists.
- Fields that are genuinely arrays (e.g. registry entries, FTP state `data`) are fine to read/manipulate as lists — no change needed there.
