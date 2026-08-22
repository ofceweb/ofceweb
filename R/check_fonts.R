# Polices Google utilisées par les thèmes OFCE ------------------------------

#' Polices Google requises par les thèmes OFCE
#'
#' @return Un vecteur de noms de familles.
#' @keywords internal
ofce_fonts <- function() {
  c("Open Sans", "Arimo", "Merriweather")
}

#' Vérifie (et installe) les polices Google utilisées par les thèmes OFCE
#'
#' Regarde si les familles `Open Sans`, `Arimo` et `Merriweather` sont
#' disponibles pour le système (via [systemfonts::system_fonts()]) et, le cas
#' échéant, installe celles qui manquent avec [install_fonts()].
#'
#' @param fonts Familles à vérifier. Défaut : `c("Open Sans", "Arimo",
#'   "Merriweather")`.
#' @param install Si `TRUE` (défaut), installe les polices manquantes. Si
#'   `FALSE`, se contente de signaler ce qui manque.
#' @param quiet Si `TRUE`, n'affiche aucun message.
#' @param ... Passé à [install_fonts()] (notamment `method`).
#'
#' @return Invisible, un vecteur logique nommé indiquant, pour chaque famille,
#'   si elle est installée **après** l'éventuelle installation.
#' @export
check_fonts <- function(fonts = ofce_fonts(),
                        install = TRUE,
                        quiet = FALSE,
                        ...) {
  present <- font_installed(fonts)
  missing <- names(present)[!present]

  if (length(missing) == 0) {
    if (!quiet) {
      cli::cli_alert_success(
        "Polices déjà installées : {.val {fonts}}."
      )
    }
    return(invisible(present))
  }

  if (!install) {
    if (!quiet) {
      cli::cli_alert_warning(
        "Police{?s} manquante{?s} : {.val {missing}}. \\
         Lancer {.run ofceweb::check_fonts()} pour {?la/les} installer."
      )
    }
    return(invisible(present))
  }

  install_fonts(missing, quiet = quiet, ...)

  present <- font_installed(fonts)
  still_missing <- names(present)[!present]
  if (length(still_missing) > 0 && !quiet) {
    cli::cli_alert_warning(
      "Police{?s} toujours introuvable{?s} après installation : \\
       {.val {still_missing}}. Un redémarrage de la session R (ou de \\
       l'ordinateur sous Windows) peut être nécessaire."
    )
  }

  invisible(present)
}

#' Teste la présence de familles de polices sur le système
#'
#' @param fonts Vecteur de noms de familles.
#' @return Un vecteur logique nommé (mêmes noms que `fonts`).
#' @export
font_installed <- function(fonts = ofce_fonts()) {
  # `systemfonts` met en cache la liste des polices : on la vide pour voir
  # celles installées depuis le début de la session.
  try(systemfonts::reset_font_cache(), silent = TRUE)
  installed <- tryCatch(
    unique(systemfonts::system_fonts()$family),
    error = function(e) character()
  )
  out <- stats::setNames(
    tolower(fonts) %in% tolower(installed),
    fonts
  )
  out
}

#' Installe des polices Google
#'
#' Sur un système Unix (macOS, Linux) où Homebrew est disponible, l'installation
#' passe par `brew install --cask font-<famille>`. Sinon (ou en cas d'échec),
#' les fichiers `.ttf` sont téléchargés depuis l'API Google Fonts et copiés dans
#' le dossier de polices de l'utilisateur :
#'
#' * macOS : `~/Library/Fonts`
#' * Linux : `~/.local/share/fonts` (+ `fc-cache -f`)
#' * Windows : `%LOCALAPPDATA%/Microsoft/Windows/Fonts` (+ enregistrement dans
#'   `HKCU\\...\\Fonts`)
#'
#' @param fonts Familles à installer. Défaut : `c("Open Sans", "Arimo",
#'   "Merriweather")`.
#' @param method `"auto"` (défaut) essaie Homebrew puis le téléchargement ;
#'   `"brew"` force Homebrew ; `"download"` force le téléchargement.
#' @param quiet Si `TRUE`, n'affiche aucun message.
#'
#' @return Invisible, un vecteur logique nommé : `TRUE` si l'installation de la
#'   famille s'est déroulée sans erreur.
#' @export
install_fonts <- function(fonts = ofce_fonts(),
                          method = c("auto", "brew", "download"),
                          quiet = FALSE) {
  method <- match.arg(method)

  if (length(fonts) == 0) return(invisible(logical()))

  if (method == "brew" && !has_brew()) {
    cli::cli_abort(
      "Homebrew est introuvable ({.code brew} absent du {.envvar PATH})."
    )
  }

  use_brew <- method == "brew" || (method == "auto" && is_unix() && has_brew())

  ok <- stats::setNames(rep(FALSE, length(fonts)), fonts)

  if (use_brew) {
    if (!quiet) {
      cli::cli_alert_info("Installation via Homebrew : {.val {fonts}}.")
    }
    ok <- install_fonts_brew(fonts, quiet = quiet)
    if (all(ok) || method == "brew") return(invisible(ok))
    if (!quiet) {
      cli::cli_alert_warning(
        "Homebrew n'a pas pu installer {.val {names(ok)[!ok]}} \\
         — bascule sur le téléchargement Google Fonts."
      )
    }
    fonts <- names(ok)[!ok]
  }

  dl <- install_fonts_download(fonts, quiet = quiet)
  ok[names(dl)] <- dl
  invisible(ok)
}

# Homebrew ------------------------------------------------------------------

#' @keywords internal
is_unix <- function() {
  .Platform$OS.type == "unix"
}

#' @keywords internal
has_brew <- function() {
  nzchar(Sys.which("brew")[[1]])
}

#' Nom du cask Homebrew correspondant à une famille Google
#' @keywords internal
brew_cask_name <- function(font) {
  paste0("font-", gsub(" ", "-", tolower(font), fixed = TRUE))
}

#' @keywords internal
install_fonts_brew <- function(fonts, quiet = FALSE) {
  ok <- stats::setNames(rep(FALSE, length(fonts)), fonts)
  for (font in fonts) {
    cask <- brew_cask_name(font)
    status <- suppressWarnings(system2(
      "brew",
      c("install", "--cask", cask),
      stdout = if (quiet) FALSE else "",
      stderr = if (quiet) FALSE else ""
    ))
    ok[[font]] <- identical(as.integer(status), 0L)
    if (ok[[font]] && !quiet) {
      cli::cli_alert_success("{.val {font}} installée ({.code {cask}}).")
    }
  }
  ok
}

# Téléchargement Google Fonts ------------------------------------------------

#' Dossier de polices de l'utilisateur, selon l'OS
#' @keywords internal
user_font_dir <- function() {
  sysname <- Sys.info()[["sysname"]]
  if (identical(sysname, "Darwin")) {
    fs::path_home("Library", "Fonts")
  } else if (.Platform$OS.type == "windows") {
    fs::path(Sys.getenv("LOCALAPPDATA"), "Microsoft", "Windows", "Fonts")
  } else {
    fs::path_home(".local", "share", "fonts")
  }
}

#' URL de la feuille de style Google Fonts pour une famille
#'
#' On passe par l'API CSS (`css2`) plutôt que par le bouton « download » du site
#' (qui ne sert plus d'archive zip directement) : avec un `User-Agent` ancien,
#' Google renvoie des `@font-face` pointant sur des fichiers `.ttf`.
#'
#' @keywords internal
google_font_css_url <- function(font, spec = "ital,wght@0,400;0,700;1,400;1,700") {
  family <- gsub(" ", "+", font, fixed = TRUE)
  paste0(
    "https://fonts.googleapis.com/css2?family=", family,
    if (nzchar(spec)) paste0(":", spec) else ""
  )
}

#' Récupère le CSS Google Fonts d'une famille
#'
#' Essaie successivement les variantes demandées, de la plus riche (italiques +
#' graisses) à la plus simple, car toutes les familles ne les proposent pas.
#'
#' @keywords internal
fetch_google_font_css <- function(font) {
  h <- curl::new_handle()
  # UA ancien mais pas trop : `Mozilla/4.0` fait servir des `.ttf` (et non des
  # `.woff2`) tout en renvoyant bien toutes les variantes demandées.
  curl::handle_setheaders(h, "User-Agent" = "Mozilla/4.0")
  specs <- c("ital,wght@0,400;0,700;1,400;1,700", "wght@400;700", "")
  for (spec in specs) {
    res <- try(
      curl::curl_fetch_memory(google_font_css_url(font, spec), handle = h),
      silent = TRUE
    )
    if (inherits(res, "try-error") || res$status_code != 200) next
    css <- rawToChar(res$content)
    if (grepl("url(", css, fixed = TRUE)) return(css)
  }
  cli::cli_abort("Google Fonts ne connait pas la famille {.val {font}}.")
}

#' Extrait les URL de fichiers de police d'un CSS Google Fonts
#'
#' @return Un vecteur nommé (nom de fichier cible -> URL).
#' @keywords internal
parse_google_font_css <- function(css, font) {
  blocks <- strsplit(css, "@font-face", fixed = TRUE)[[1]][-1]
  urls <- character()
  for (b in blocks) {
    url <- stringr::str_match(b, "url\\(([^)]+)\\)")[, 2]
    if (is.na(url)) next
    weight <- stringr::str_match(b, "font-weight:\\s*([0-9]+)")[, 2]
    style <- stringr::str_match(b, "font-style:\\s*([a-z]+)")[, 2]
    ext <- fs::path_ext(url)
    if (!nzchar(ext)) ext <- "ttf"
    name <- paste0(
      gsub(" ", "", font, fixed = TRUE), "-",
      if (is.na(weight)) "400" else weight,
      if (identical(style, "italic")) "italic" else "",
      ".", ext
    )
    urls[[name]] <- url
  }
  urls[!duplicated(urls)]
}

#' @keywords internal
install_fonts_download <- function(fonts, quiet = FALSE) {
  ok <- stats::setNames(rep(FALSE, length(fonts)), fonts)
  if (length(fonts) == 0) return(ok)

  dest_dir <- user_font_dir()
  fs::dir_create(dest_dir)

  work_dir <- fs::file_temp()
  fs::dir_create(work_dir)
  on.exit(try(fs::dir_delete(work_dir), silent = TRUE), add = TRUE)

  for (font in fonts) {
    if (!quiet) {
      cli::cli_alert_info("Téléchargement de {.val {font}} depuis Google Fonts.")
    }
    installed <- tryCatch({
      urls <- parse_google_font_css(fetch_google_font_css(font), font)
      if (length(urls) == 0) {
        cli::cli_abort("Aucun fichier de police trouvé pour {.val {font}}.")
      }

      dl_dir <- fs::path(work_dir, gsub(" ", "", font, fixed = TRUE))
      fs::dir_create(dl_dir)

      files <- character()
      for (nm in names(urls)) {
        target <- fs::path(dl_dir, nm)
        curl::curl_download(urls[[nm]], target, quiet = TRUE)
        files <- c(files, as.character(target))
      }

      copy_font_files(files, dest_dir)
      TRUE
    }, error = function(e) {
      if (!quiet) {
        cli::cli_alert_danger(
          "Échec de l'installation de {.val {font}} : {conditionMessage(e)}"
        )
      }
      FALSE
    })
    ok[[font]] <- installed
    if (installed && !quiet) {
      cli::cli_alert_success(
        "{.val {font}} installée dans {.path {dest_dir}}."
      )
    }
  }

  if (any(ok)) refresh_font_cache(dest_dir, quiet = quiet)
  ok
}

#' Copie les fichiers de police et, sous Windows, les enregistre
#' @keywords internal
copy_font_files <- function(files, dest_dir) {
  fs::file_copy(files, dest_dir, overwrite = TRUE)
  if (.Platform$OS.type == "windows") {
    for (f in files) {
      name <- fs::path_file(f)
      suppressWarnings(system2(
        "reg",
        c(
          "add",
          "\"HKCU\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts\"",
          "/v", shQuote(fs::path_ext_remove(name)),
          "/t", "REG_SZ",
          "/d", shQuote(as.character(fs::path(dest_dir, name))),
          "/f"
        ),
        stdout = FALSE, stderr = FALSE
      ))
    }
  }
  invisible(TRUE)
}

#' @keywords internal
refresh_font_cache <- function(dest_dir, quiet = FALSE) {
  if (nzchar(Sys.which("fc-cache")[[1]])) {
    suppressWarnings(system2(
      "fc-cache", c("-f", shQuote(as.character(dest_dir))),
      stdout = FALSE, stderr = FALSE
    ))
  }
  # Vide le cache de `systemfonts` pour que la police fraîchement copiée soit
  # visible sans redémarrer la session.
  try(systemfonts::reset_font_cache(), silent = TRUE)
  invisible(TRUE)
}
