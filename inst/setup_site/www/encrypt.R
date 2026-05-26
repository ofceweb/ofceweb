if (!requireNamespace("staticryptR", quietly = TRUE)) {
  stop(
    "staticryptR package is required for this script to work.
    Please install with: install.packages('staticryptR')",
    call. = FALSE
  )
}

if (isTRUE(staticryptR::check_system())) {
  message(
    "Encrypting..."
  )
}

staticryptR::staticryptr(
  files = "_site",
  directory = ".",
  recursive = TRUE,
  password = Sys.getenv("STATICRYPT_PASSWORD"),
  short = TRUE, # set to FALSE if you want to enforce a long password
  template_color_primary = "#e6142d",
  template_color_secondary = "#f9f9f3",
  template_title = "Accès restreint",
  template_instructions = "Entrez le mot de passe ou contactez un responsable de la page que vous souhaitez atteindre.",
  template_button = "Accès"
)
