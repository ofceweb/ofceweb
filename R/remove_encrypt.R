#' Désactive le chiffrement statique du site
#'
#' Annule les effets de [encrypt_site()] :
#' \enumerate{
#'   \item Bascule la variable `encrypt_site` à `false` dans le
#'         `_quarto.yml`.
#'   \item Retire le bloc `env: STATICRYPT_PASSWORD` du job
#'         `.github/workflows/ftp_deploy.yml`.
#'   \item Supprime le secret GitHub `STATICRYPT_PASSWORD` du dépôt via `gh`
#'         (si `gh` est installé et que le dépôt a un remote `origin`).
#' }
#'
#' Toutes les étapes sont idempotentes : si un élément n'existe pas,
#' l'étape est simplement ignorée.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param delete_secret Logique. Si `TRUE` (défaut), tente de supprimer le
#'   secret GitHub `STATICRYPT_PASSWORD` via `gh secret delete`.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [encrypt_site()]
#' @export
remove_encrypt <- function(path = ".", delete_secret = TRUE) {

  root <- fs::path_abs(fs::path_expand(path))
  if(!fs::dir_exists(root))
    cli::cli_abort("Le dossier {.path {root}} n'existe pas.")

  cli::cli_h1("remove_encrypt dans {.path {fs::path_file(root)}}")

  # ---- 1. bascule dans _quarto.yml ---------------------------------------
  yml_path <- fs::path(root, "_quarto.yml")
  if(!fs::file_exists(yml_path)) {
    cli::cli_alert_warning(
      "{.file _quarto.yml} introuvable — patch ignoré."
    )
  } else {
    lines <- readLines(yml_path, warn = FALSE)
    idx <- grep("^\\s*encrypt_site\\s*:", lines)
    if(length(idx) == 0) {
      lines <- c(lines, "encrypt_site: false")
      writeLines(lines, yml_path)
      cli::cli_alert_success(
        "Ajout de {.code encrypt_site: false} dans {.file _quarto.yml}"
      )
    } else if(grepl("false", lines[[idx[[1]]]], ignore.case = TRUE)) {
      cli::cli_alert_info(
        "{.code encrypt_site: false} déjà présent — {.file _quarto.yml} inchangé."
      )
    } else {
      lines[[idx[[1]]]] <- sub(":\\s*.*$", ": false", lines[[idx[[1]]]])
      writeLines(lines, yml_path)
      cli::cli_alert_success(
        "Bascule de {.code encrypt_site} à {.val false} dans {.file _quarto.yml}"
      )
    }
  }

  # ---- 2. retrait dans ftp_deploy.yml ------------------------------------
  wf <- fs::path(root, ".github", "workflows", "ftp_deploy.yml")
  if(!fs::file_exists(wf)) {
    cli::cli_alert_warning(
      "{.file .github/workflows/ftp_deploy.yml} introuvable — patch ignoré."
    )
  } else {
    lines <- readLines(wf, warn = FALSE)
    idx_secret <- grep("STATICRYPT_PASSWORD", lines, fixed = TRUE)
    if(length(idx_secret) == 0) {
      cli::cli_alert_info(
        "{.code STATICRYPT_PASSWORD} absent de {.file ftp_deploy.yml} — \\
         patch ignoré."
      )
    } else {
      drop <- integer()
      for(i in idx_secret) {
        drop <- c(drop, i)
        # Ligne `env:` juste au-dessus, si elle ne contient que ce mapping.
        if(i >= 2 && grepl("^\\s*env:\\s*$", lines[[i - 1]])) {
          # Vérifie qu'aucune autre variable ne suit dans le bloc env.
          j <- i + 1
          has_other <- FALSE
          env_indent <- nchar(sub("env:.*$", "", lines[[i - 1]]))
          var_indent <- nchar(sub("STATICRYPT_PASSWORD.*$", "", lines[[i]]))
          while(j <= length(lines)) {
            ln <- lines[[j]]
            if(!nzchar(trimws(ln))) { j <- j + 1; next }
            cur_indent <- nchar(sub("\\S.*$", "", ln))
            if(cur_indent >= var_indent) { has_other <- TRUE; break }
            break
          }
          if(!has_other) {
            drop <- c(drop, i - 1)
            # Ligne vide insérée par encrypt_site() juste avant `env:`.
            if(i >= 3 && !nzchar(trimws(lines[[i - 2]]))) {
              drop <- c(drop, i - 2)
            }
          }
        }
      }
      lines <- lines[-sort(unique(drop))]
      writeLines(lines, wf)
      cli::cli_alert_success(
        "Retrait de {.code STATICRYPT_PASSWORD} dans {.file ftp_deploy.yml}"
      )
    }
  }

  # ---- 3. suppression du secret GitHub via gh ----------------------------
  if(!delete_secret) {
    cli::cli_alert_info(
      "{.arg delete_secret = FALSE} — secret GitHub conservé."
    )
    return(invisible(NULL))
  }

  remotes <- tryCatch(gert::git_remote_list(repo = root),
                      error = function(e) NULL)
  origin_url <- NULL
  if(!is.null(remotes) && nrow(remotes) > 0) {
    o <- remotes[remotes$name == "origin", , drop = FALSE]
    origin_url <- if(nrow(o) > 0) o$url[[1]] else remotes$url[[1]]
  }
  if(is.null(origin_url)) {
    cli::cli_alert_warning(
      "Remote {.code origin} introuvable — suppression du secret ignorée."
    )
    return(invisible(NULL))
  }

  url2 <- sub("\\.git$", "", origin_url)
  m <- if(grepl("^git@", url2))
    regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1]]
  else
    regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1]]
  if(length(m) < 3) {
    cli::cli_alert_warning(
      "Impossible de parser l'URL remote {.val {origin_url}} — \\
       suppression du secret ignorée."
    )
    return(invisible(NULL))
  }
  owner_repo <- paste0(m[[2]], "/", m[[3]])

  if(nzchar(Sys.which("gh")) == 0) {
    cli::cli_alert_warning(
      "{.code gh} (GitHub CLI) introuvable — supprimer manuellement le \\
       secret {.code STATICRYPT_PASSWORD} sur {.val {owner_repo}}."
    )
    return(invisible(NULL))
  }

  cli::cli_alert_info(
    "Suppression du secret {.code STATICRYPT_PASSWORD} sur \\
     {.val {owner_repo}}…"
  )
  status <- system2(
    "gh",
    args = c("secret", "delete", "STATICRYPT_PASSWORD",
             "--repo", owner_repo),
    stdout = "", stderr = ""
  )
  if(!identical(status, 0L)) {
    cli::cli_alert_warning(
      "Échec de {.code gh secret delete} (code {status}). \\
       Le secret n'existait peut-être pas, ou droits insuffisants."
    )
  } else {
    cli::cli_alert_success(
      "Secret {.code STATICRYPT_PASSWORD} supprimé de {.val {owner_repo}}."
    )
  }

  invisible(NULL)
}
