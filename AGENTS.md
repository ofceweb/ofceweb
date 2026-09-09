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
  - **WP**: `{annee}/{wp}/` → generates `index.html` redirecting to latest version
  - **Prevision**: `derniere/` → redirects to current published prevision
- Branch: `site-redirect` (separate from content branches)

### Staging — Content Deployment (`ftp_deploy_staging.yml`)
- Credentials : `FTP_SERVER` / `STAGING_USER` / `STAGING_PASSWORD`
- The staging FTP user has a **chroot on `www/staging/`**
- `FTP_STAGING_DIR` is set by `setup_prev()` / `setup_wp()` to `{repo}/{version}/`
- Effective server path : `www/staging/{repo}/{version}/`

### Staging — Redirection (`ftp_redirect_staging.yml`)
- Credentials : `FTP_SERVER` / `STAGING_USER` / `STAGING_PASSWORD`
- Variable `FTP_STAGING_REDIRECT_DIR` : parent path for staging redirect
  - **Prevision**: `prev{YYMM}/` → generates `index.html` redirecting to latest version
  - Effective server path: `www/staging/prev{YYMM}/`
- Branch: `site-staging-redirect` (separate from staging content branch `site-staging`)

## JSON read/write conventions

- Always pair `jsonlite::write_json()` (and `toJSON()`) with `auto_unbox = TRUE` when writing scalar fields (e.g. `slug`, `stage`, `pb`). Without it, every scalar is wrapped in a single-element JSON array (`"slug": ["x"]` instead of `"slug": "x"`), which then round-trips back as a length-1 **list** on read — silently breaking anything expecting a plain string (e.g. GitHub `workflow_dispatch` inputs, which reject arrays). This caused a real bug in `adhoc_site.R`'s ad-hoc metadata file (`.adhoc-meta.json`).
- On the read side, `jsonlite::read_json()` defaults to `simplifyVector = FALSE`; pass `simplifyVector = TRUE` when you expect scalar fields back as atomic vectors rather than lists.
- Fields that are genuinely arrays (e.g. registry entries, FTP state `data`) are fine to read/manipulate as lists — no change needed there.
