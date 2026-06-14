library(tidyverse)

# Construit des variables nommées par pays/année pour les textes en ligne.
# Retourne une liste de listes : chaque élément est un vecteur nommé par code pays.
# Exemple d'utilisation dans index.qmd :
#   prev <- source_data("/data_pays/data_vars.R")
#   fra_data <- resume_annuel("FRA")
#   `r fra_data["pib_2026"]`%

data <- source_data("tab_synthese.R")
code <- data |> pull(code)

# Récupère toutes les colonnes numériques (pib_AAAA, tcho_AAAA, etc.)
num_cols <- data |> select(where(is.numeric)) |> names()

result <- lapply(num_cols, function(col) {
  data |> pull(!!col) |> fmt_val() |> str_c(" %") |>
    set_names(code) |> as.list()
}) |> set_names(num_cols)

return(result)
