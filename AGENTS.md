## FTP deployment architecture

### Production (`ftp_deploy.yml`)
- Credentials : `FTP_SERVER` / `FTP_USER` / `FTP_PASSWORD`
- Destination : `${{ vars.FTP_SERVER_DIR }}` → set by `setup_wp()` to `{annee}/{wp}/` (with optional `/v{n}` suffix)
- Variable `FTP_REDIRECT_DIR` : parent path used for stable redirect (without version segment)

### Staging (`ftp_stage.yml`)
- Credentials : `FTP_SERVER` / `STAGING_USER` / `STAGING_PASSWORD`
- The staging FTP user has a **chroot on `www/staging/`**
- `FTP_STAGING_DIR` is set by `setup_wp()` to `{repo}/{version}/`
- Effective server path : `www/staging/{repo}/{version}/`
