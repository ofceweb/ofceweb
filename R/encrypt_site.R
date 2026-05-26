#' Active le chiffrement statique du site
#'
#' Configure le site courant pour qu'il soit chiffré au moment du render via
#' `staticrypt` (étape gérée directement par [render_site()] lorsque la
#' variable `encrypt_site` du `_quarto.yml` vaut `true`). Concrètement :
#' \enumerate{
#'   \item Bascule la variable `encrypt_site` à `true` dans le
#'         `_quarto.yml` (idempotent ; ajoutée si absente).
#'   \item Ajoute la variable d'environnement `STATICRYPT_PASSWORD` au job
#'         `.github/workflows/ftp_deploy.yml` (idempotent).
#'   \item Demande un mot de passe à l'utilisateur et le stocke comme secret
#'         GitHub du dépôt sous le nom `STATICRYPT_PASSWORD` via `gh`.
#'   \item Enregistre `STATICRYPT_PASSWORD` dans le `.Renviron` à la racine
#'         du dépôt (et l'ajoute au `.gitignore`) afin que les renders locaux
#'         disposent du mot de passe sans configuration shell.
#' }
#'
#' Pré-requis : l'outil `gh` doit être installé et authentifié
#' (`gh auth login`) avec les droits d'administration sur le dépôt.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param password Chaîne ou `NULL` (défaut). Si `NULL`, l'utilisateur est
#'   invité à saisir le mot de passe (masqué si `askpass` est disponible).
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [setup_site()], [deploy_site()]
#' @export
encrypt_site <- function(path = ".", password = NULL) {

  root <- fs::path_abs(fs::path_expand(path))
  if(!fs::dir_exists(root))
    cli::cli_abort("Le dossier {.path {root}} n'existe pas.")

  yml_path <- fs::path(root, "_quarto.yml")
  if(!fs::file_exists(yml_path))
    cli::cli_abort(
      "Pas de {.file _quarto.yml} dans {.path {root}}. \\
       Lancer {.run ofceweb::setup_site()} d'abord."
    )

  cli::cli_h1("encrypt_site dans {.path {fs::path_file(root)}}")

  # ---- 1. patch du _quarto.yml -------------------------------------------
  lines <- readLines(yml_path, warn = FALSE)
  idx <- grep("^\\s*encrypt_site\\s*:", lines)
  if(length(idx) == 0) {
    lines <- c(lines, "encrypt_site: true")
    writeLines(lines, yml_path)
    cli::cli_alert_success(
      "Ajout de {.code encrypt_site: true} dans {.file _quarto.yml}"
    )
  } else if(grepl("true", lines[[idx[[1]]]], ignore.case = TRUE)) {
    cli::cli_alert_info(
      "{.code encrypt_site: true} déjà présent — {.file _quarto.yml} inchangé."
    )
  } else {
    lines[[idx[[1]]]] <- sub(":\\s*.*$", ": true", lines[[idx[[1]]]])
    writeLines(lines, yml_path)
    cli::cli_alert_success(
      "Bascule de {.code encrypt_site} à {.val true} dans {.file _quarto.yml}"
    )
  }

  # ---- 2. patch du workflow ftp_deploy.yml -------------------------------
  wf <- fs::path(root, ".github", "workflows", "ftp_deploy.yml")
  if(!fs::file_exists(wf)) {
    cli::cli_alert_warning(
      "{.file .github/workflows/ftp_deploy.yml} introuvable — patch ignoré."
    )
  } else {
    lines <- readLines(wf, warn = FALSE)
    if(any(grepl("STATICRYPT_PASSWORD", lines, fixed = TRUE))) {
      cli::cli_alert_info(
        "{.code STATICRYPT_PASSWORD} déjà référencé dans \\
         {.file ftp_deploy.yml} — patch ignoré."
      )
    } else {
      # Insère un bloc `env:` au niveau du job `deploy:`, juste après
      # `runs-on: ubuntu-latest`.
      idx <- grep("^\\s*runs-on:\\s*ubuntu-latest\\s*$", lines)
      if(length(idx) == 0) {
        cli::cli_alert_warning(
          "Format inattendu de {.file ftp_deploy.yml} — patch manuel requis."
        )
      } else {
        i <- idx[[1]]
        indent <- sub("runs-on:.*$", "", lines[[i]])
        insertion <- c(
          "",
          paste0(indent, "env:"),
          paste0(indent, "  STATICRYPT_PASSWORD: ${{ secrets.STATICRYPT_PASSWORD }}")
        )
        lines <- append(lines, insertion, after = i)
        writeLines(lines, wf)
        cli::cli_alert_success(
          "Ajout de {.code STATICRYPT_PASSWORD} dans {.file ftp_deploy.yml}"
        )
      }
    }
  }

  # ---- 3. owner/repo depuis le remote ------------------------------------
  remotes <- tryCatch(gert::git_remote_list(repo = root),
                      error = function(e) NULL)
  origin_url <- NULL
  if(!is.null(remotes) && nrow(remotes) > 0) {
    o <- remotes[remotes$name == "origin", , drop = FALSE]
    origin_url <- if(nrow(o) > 0) o$url[[1]] else remotes$url[[1]]
  }
  if(is.null(origin_url))
    cli::cli_abort(
      "Impossible de déterminer le remote {.code origin} — secret non créé."
    )

  url2 <- sub("\\.git$", "", origin_url)
  m <- if(grepl("^git@", url2))
    regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1]]
  else
    regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1]]
  if(length(m) < 3)
    cli::cli_abort("Impossible de parser l'URL remote : {.val {origin_url}}")
  owner_repo <- paste0(m[[2]], "/", m[[3]])

  # ---- 4. gh installé ? --------------------------------------------------
  if(nzchar(Sys.which("gh")) == 0)
    cli::cli_abort(
      "L'outil {.code gh} (GitHub CLI) est requis mais introuvable. \\
       Installer puis {.code gh auth login}."
    )

  # ---- 5. demande du mot de passe ----------------------------------------
  if(is.null(password)) {
    if(requireNamespace("askpass", quietly = TRUE)) {
      password <- askpass::askpass(
        prompt = "Mot de passe pour STATICRYPT_PASSWORD : "
      )
    } else {
      cli::cli_alert_warning(
        "Package {.pkg askpass} indisponible — la saisie sera visible."
      )
      password <- readline("Mot de passe pour STATICRYPT_PASSWORD : ")
    }
  }
  if(is.null(password) || !nzchar(password))
    cli::cli_abort("Mot de passe vide — secret non créé.")

  # ---- 6. création du secret GitHub via gh -------------------------------
  cli::cli_alert_info(
    "Création du secret {.code STATICRYPT_PASSWORD} sur {.val {owner_repo}}…"
  )
  status <- system2(
    "gh",
    args = c("secret", "set", "STATICRYPT_PASSWORD",
             "--repo", owner_repo),
    input = password,
    stdout = "", stderr = ""
  )
  if(!identical(status, 0L))
    cli::cli_abort(
      "Échec de {.code gh secret set} (code {status}). \\
       Vérifier {.code gh auth status} et les droits sur le dépôt."
    )
  cli::cli_alert_success(
    "Secret {.code STATICRYPT_PASSWORD} enregistré sur {.val {owner_repo}}."
  )

  # ---- 7. enregistrement dans .Renviron local ----------------------------
  renv_path <- fs::path(root, ".Renviron")
  renv_lines <- if(fs::file_exists(renv_path))
    readLines(renv_path, warn = FALSE) else character()
  keep <- !grepl("^\\s*STATICRYPT_PASSWORD\\s*=", renv_lines)
  renv_lines <- c(
    renv_lines[keep],
    sprintf("STATICRYPT_PASSWORD=%s", password)
  )
  writeLines(renv_lines, renv_path)
  cli::cli_alert_success(
    "{.envvar STATICRYPT_PASSWORD} écrit dans {.file .Renviron}."
  )

  gi_path <- fs::path(root, ".gitignore")
  gi_lines <- if(fs::file_exists(gi_path))
    readLines(gi_path, warn = FALSE) else character()
  if(!any(grepl("^\\s*\\.Renviron\\s*$", gi_lines))) {
    writeLines(c(gi_lines, ".Renviron"), gi_path)
    cli::cli_alert_success("Ajout de {.file .Renviron} à {.file .gitignore}.")
  }

  cli::cli_alert_warning(
    "{.strong Redémarrage de la session R nécessaire} pour que \\
     {.envvar STATICRYPT_PASSWORD} soit chargé depuis {.file .Renviron} \\
     — sans ça, {.run ofceweb::render_site()} ne pourra pas chiffrer."
  )
  cli::cli_alert_warning(
    "Pensez à {.strong commiter et pousser} les changements \\
     ({.file _quarto.yml}, {.file ftp_deploy.yml}) avant de déployer."
  )

  invisible(NULL)
}
