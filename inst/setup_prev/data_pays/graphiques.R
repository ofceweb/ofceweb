library(tidyverse)
library(glue)
library(ofce)
library(conflicted)
conflict_prefer_all("dplyr", quiet = TRUE)

.gt <- function(x, na.rm = FALSE) (100 * (x / lag(x, 1) - 1))
.ga <- function(x, na.rm = FALSE) (100 * (x / lag(x, 4) - 1))

dp <- source_data("data_pays.R", lapse = "1 hour")

data_gpib <- dp$trim |>
  select(date, pays, PIB) |>
  arrange(pays, date) |>
  mutate(date = floor_date(date, "quarter") + days(45)) |>
  group_by(pays) |>
  mutate(value = .gt(PIB)) |>
  ungroup() |>
  transmute(
    date, pays, value,
    variable = "Croissance du PIB",
    long     = pays_long[toupper(pays)],
    tooltip  = glue("<b>{long}</b><br>{date_trim(date)}<br>{variable} : {round(value, 1)}%"))

data_tcho <- dp$trim |>
  select(date, pays, tcho) |>
  arrange(pays, date) |>
  mutate(date = floor_date(date, "quarter") + days(45)) |>
  transmute(
    date, pays,
    variable = "Taux de chômage (BIT)",
    value    = tcho,
    long     = pays_long[toupper(pays)],
    tooltip  = glue("<b>{long}</b><br>{date_trim(date)}<br>{variable} : {round(value, 1)}%"))

data_prix <- dp$trim |>
  select(date, pays, IPCH) |>
  arrange(pays, date) |>
  mutate(date = floor_date(date, "quarter") + days(45)) |>
  group_by(pays) |>
  mutate(value = .ga(IPCH)) |>
  ungroup() |>
  transmute(
    date, pays, value,
    variable = "Inflation (IPCH)",
    long     = pays_long[toupper(pays)],
    tooltip  = glue("<b>{long}</b><br>{date_trim(date)}<br>{variable} : {round(value, 1)}%"))

data_solde <- dp$an |>
  select(date, pays, deficit) |>
  arrange(pays, date) |>
  mutate(
    date = ymd(date, truncated = 2),
    date = floor_date(date, "year") + days(300)) |>
  transmute(
    date, pays,
    variable = "Déficit public (APU)",
    value    = deficit,
    long     = pays_long[toupper(pays)],
    tooltip  = glue("<b>{long}</b><br>{date_trim(date)}<br>{variable} : {round(value, 1)}%"))

data <- bind_rows(data_gpib, data_tcho, data_prix, data_solde) |>
  mutate(variable = factor(
    variable,
    c("Croissance du PIB", "Taux de chômage (BIT)", "Inflation (IPCH)", "Déficit public (APU)")))

# graphe(pays, pays2, autres_pays, source, dps, pc)
# Produit un ggplot interactif à 4 panneaux pour un pays donné.
# - pays        : code ISO3 du pays principal (ex. "FRA")
# - pays2       : pays de référence (ex. "EUZ"), affiché en gris foncé
# - autres_pays : contexte, affiché en gris clair
# - source      : texte source pour la caption
# - dps         : date de début de la prévision (date_prev_start)
# - pc          : couleur de la prévision (prev_color)
graphe <- function(pays, pays2 = "EUZ",
                   autres_pays = c("DEU", "EUZ", "ITA", "ESP", "FRA"),
                   source = "",
                   dps = date_prev_start,
                   pc  = prev_color) {

  autres    <- autres_pays |> setdiff(pays2) |> setdiff(pays)
  les_pays  <- unique(c(pays, pays2, autres_pays))
  note      <- if (pays2 == "EUZ") "La zone euro est en gris foncé" else NULL

  local_data <- data |>
    dplyr::filter(pays %in% les_pays, date >= "2022-01-01") |>
    mutate(id = str_c(date, "-", pays))

  ggplot(local_data) +
    theme_ofce() +
    aes(x = date, y = value, group = pays, color = variable, fill = variable) +
    annotate_prevision(size = 0) +
    facet_wrap(vars(variable), scales = "free_y") +
    geom_line(
      data  = ~ .x |> dplyr::filter(pays %in% autres),
      color = "gray80", linewidth = 0.25) +
    geom_line(
      data  = ~ .x |> dplyr::filter(pays == pays2),
      color = "gray50", linewidth = 0.25) +
    geom_point_interactive(
      data  = ~ .x |> dplyr::filter(pays %in% autres),
      aes(tooltip = tooltip, data_id = id),
      size = 0.75, stroke = 0.25, shape = 1,
      col  = "gray80", hover_nearest = TRUE) +
    geom_point_interactive(
      data  = ~ .x |> dplyr::filter(pays == pays2),
      aes(tooltip = tooltip, data_id = id),
      size = 0.75, stroke = 0.25, shape = 21,
      col  = "gray50", hover_nearest = TRUE) +
    geom_line(
      data = ~ .x |> dplyr::filter(pays == !!pays)) +
    scale_ofce_date(
      limits            = as.Date(c("2022-01-01", NA)),
      date_breaks       = "1 year",
      labels            = ofce::date1,
      date_minor_breaks = "3 months",
      expand            = expansion(mult = c(0.03, 0.0)),
      oob               = oob_keep) +
    geom_point_interactive(
      data  = ~ .x |> dplyr::filter(pays == !!pays, date < dps),
      aes(tooltip = tooltip, data_id = id),
      stroke = 0.5, shape = 21, col = "white", hover_nearest = TRUE) +
    geom_point_interactive(
      data  = ~ .x |> dplyr::filter(pays == !!pays, date >= dps),
      aes(tooltip = tooltip, data_id = id),
      stroke = 0.25, shape = 21, col = pc, hover_nearest = TRUE) +
    labs(y = "En %", x = NULL) +
    PrettyCols::scale_color_pretty_d("Summer") +
    PrettyCols::scale_fill_pretty_d("Summer") +
    scale_y_continuous(
      labels = label_number(decimal.mark = ",", accuracy = NULL, suffix = "%"),
      breaks = scales::breaks_pretty()) +
    guides(color = "none", fill = "none") +
    ofce_caption(source = source, note = note) +
    ofce::licence_auteur(author = "DAP")
}

return(list(
  graphe = graphe,
  data   = function(pays = "FRA") {
    data |> select(date, pays, value, variable) |> dplyr::filter(pays == !!pays)
  }
))
