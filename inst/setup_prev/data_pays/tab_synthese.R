ofce::init_qmd()

annee_min <- min(year(f_pays()$trim$date[!is.na(f_pays()$trim$PIB)]))
annee_max <- max(year(f_pays()$trim$date[!is.na(f_pays()$trim$PIB)]))

annuel <- f_pays()$an |>
  mutate(annee = date) |>
  select(annee, deficit, pays) |>
  filter(annee >= annee_max - 1)

tab_synthese <- f_pays()$trim |>
  select(date, pib = PIB, ipch = IPCH, tcho, pays) |>
  filter(pays %in% c("EUZ", "DEU", "FRA", "USA", "GBR", "ITA", "ESP", "JPN")) |>
  mutate(annee = year(date)) |>
  group_by(annee, pays) |>
  summarize(across(c(pib, ipch, tcho), mean), .groups = "drop") |>
  arrange(annee) |>
  group_by(pays) |>
  mutate(across(c(pib, ipch), ~ 100 * .x / lag(.x) - 100)) |>
  ungroup() |>
  filter(annee >= annee_max - 1) |>
  left_join(annuel, by = c("annee", "pays")) |>
  pivot_wider(names_from = annee, values_from = c(pib, ipch, tcho, deficit)) |>
  rename(code = pays) |>
  mutate(
    pays = pays_long[code],
    code = factor(code, c("EUZ", "DEU", "FRA", "ITA", "ESP", "GBR", "USA", "JPN"))
  ) |>
  arrange(code) |>
  mutate(zone = case_match(
    code,
    "EUZ" ~ "[Zone euro](/inter/synthese.qmd)",
    "DEU" ~ "[Allemagne](/fiches/zone_euro.qmd)",
    "FRA" ~ "[France](/france/cadrage.qmd)",
    "USA" ~ "[Etats-Unis](/fiches/usa.qmd)",
    "GBR" ~ "[Royaume-Uni](/fiches/uk.qmd)",
    "ITA" ~ "[Italie](/tableaux_comptes/tab_compte_italie.qmd)",
    "ESP" ~ "[Espagne](/tableaux_comptes/tab_compte_espagne.qmd)",
    "JPN" ~ "[Japon](/tableaux_comptes/tab_compte_japon.qmd)"
  )) |>
  relocate(code, pays, zone) |>
  mutate(
    code = as.character(code),
    code = if_else(code == "EUZ", "EU", code)
  )

return(tab_synthese)
