# NA

## FTP deployment architecture

### Production — Content Deployment (`ftp_deploy.yml` / `ftp_deploy_publish.yml`)

- Credentials : `FTP_SERVER` / `FTP_USER` / `FTP_PASSWORD`
- Destination : `${{ vars.FTP_SERVER_DIR }}`
  - **WP**: `{annee}/{wp}/` or `{annee}/{wp}/v{n}` (with version suffix)
  - **Prevision publish**: `prev/prev{YYMM}`
- Effective server path (production): paths under `/wp/` or `/prev/`

### Production — Redirection (`ftp_redirect.yml`)

- Credentials : `FTP_SERVER` / `FTP_USER` / `FTP_PASSWORD`
- Variable `FTP_REDIRECT_DIR` : parent path for stable redirect (without
  version segment)
  - **WP**/**PB**: `{annee}/{wp}/` / `pb/{pb}/` → generates `index.html`
    redirecting to latest version
  - **Prevision**: `derniere/` → redirects to current published
    prevision
- Branch: `site-redirect` (separate from content branches)
- [`push_wp_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_wp_redirect.md)/[`push_pb_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_pb_redirect.md)
  compute the parent dir by stripping the trailing `/<version>` segment
  from `site-path`, matched by value (not by a numeric regex) — a
  custom/suffixed version (e.g. `v2_corr`, `v5_AS42`) must still be
  stripped correctly.
- **Automatic vs. manual**: for WP/PB, called automatically from
  [`deploy_wp()`](https://ofceweb.github.io/ofceweb/reference/deploy_wp.md)/[`deploy_pb()`](https://ofceweb.github.io/ofceweb/reference/deploy_pb.md)
  on every production deploy (redirect always follows the current
  version). For `prev`,
  [`push_prev_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_prev_redirect.md)
  is **not** called automatically — republishing a prevision can also
  mean *correcting an old one*, in which case `/prev/derniere/` must not
  be repointed; call it manually once a new prevision should become
  “current”.

### Staging — Content Deployment (`ftp_deploy_staging.yml`)

- Credentials : `FTP_SERVER` / `STAGING_USER` / `STAGING_PASSWORD`
- The staging FTP user has a **chroot on `www/staging/`**
- `FTP_STAGING_DIR` is set by
  [`setup_prev()`](https://ofceweb.github.io/ofceweb/reference/setup_prev.md)
  /
  [`setup_wp()`](https://ofceweb.github.io/ofceweb/reference/setup_wp.md)
  to `{repo}/{version}/`
- Effective server path : `www/staging/{repo}/{version}/`

### Staging — Redirection (`ftp_redirect_staging.yml`)

- Credentials : `FTP_SERVER` / `STAGING_USER` / `STAGING_PASSWORD`
- Variable `FTP_STAGING_REDIRECT_DIR` : parent path for staging redirect
  - **Prevision**: `prev{YYMM}/` → generates `index.html` redirecting to
    latest version
  - **WP**/**PB**: `{repo}/` → generates `index.html` redirecting to
    latest version
    ([`push_wp_staging_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_wp_staging_redirect.md)/[`push_pb_staging_redirect()`](https://ofceweb.github.io/ofceweb/reference/push_pb_staging_redirect.md),
    reading the versioned `website.site-url` of the form
    `https://staging.ofce.fr/{repo}/{version}/`)
  - Effective server path: `www/staging/prev{YYMM}/` or
    `www/staging/{repo}/`
- Branch: `site-staging-redirect` (separate from staging content branch
  `site-staging`)
- Called automatically: for `prev`, from
  [`render_prev()`](https://ofceweb.github.io/ofceweb/reference/render_prev.md)
  after
  [`site2staging()`](https://ofceweb.github.io/ofceweb/reference/site2staging.md);
  for WP/PB, from
  [`deploy_wp()`](https://ofceweb.github.io/ofceweb/reference/deploy_wp.md)/[`deploy_pb()`](https://ofceweb.github.io/ofceweb/reference/deploy_pb.md)
  on every staging FTP deploy.

## JSON read/write conventions

- Always pair
  [`jsonlite::write_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html)
  (and `toJSON()`) with `auto_unbox = TRUE` when writing scalar fields
  (e.g. `slug`, `stage`, `pb`). Without it, every scalar is wrapped in a
  single-element JSON array (`"slug": ["x"]` instead of `"slug": "x"`),
  which then round-trips back as a length-1 **list** on read — silently
  breaking anything expecting a plain string (e.g. GitHub
  `workflow_dispatch` inputs, which reject arrays). This caused a real
  bug in `adhoc_site.R`’s ad-hoc metadata file (`.adhoc-meta.json`).
- On the read side,
  [`jsonlite::read_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html)
  defaults to `simplifyVector = FALSE`; pass `simplifyVector = TRUE`
  when you expect scalar fields back as atomic vectors rather than
  lists.
- Fields that are genuinely arrays (e.g. registry entries, FTP state
  `data`) are fine to read/manipulate as lists — no change needed there.
