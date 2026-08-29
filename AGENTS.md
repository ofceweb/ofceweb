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
