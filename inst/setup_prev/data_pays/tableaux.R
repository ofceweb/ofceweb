library(tidyverse)
library(glue)
library(ofce)
library(stringr)
library(lubridate)
library(zoo)
library(gt)
conflicted::conflict_prefer_all("dplyr", quiet = TRUE)

dp <- source_data("data_pays.R", lapse = "1 hour")
#### création de la fonction clean pour faciliter les transpositions  ####

clean_t <- function(df){                    # créé la fonction clean issue du prog de BW
  df <- t(df)                               # qui transpose le dataframe
  colnames(df) <- c(as.vector(df[1,]))      # définit le nom des colonnes du nveau df comme un vecteur contenant la 1ere ligne du df transposé
  rn <- row.names(df)[-1]                   # stocke le nom des lignes (sauf la 1ère) dans rn
  df <- df[-1,] |>                        # supprime la 1ere ligne du nveau df
    as.data.frame(df) |>                    # transforme le df en dataframe standard
    mutate_all(as.numeric)                  # convertit toutes les valeurs du df en numérique
  row.names(df) <- rn                       # réattribue les noms des lignes stockées dans rn au df
  return(df)                              # retourne le nveau df
}

pays_ok <- c("DEU", "ESP", "EUZ", "FRA", "GBR", "ITA", "JPN", "USA")

# création des fonctions de calcul (variation trim, glisst annuel, contrib)
# calcule les taux de croissance trimestriels et les glissements annuels (et renvoie NA s'il y a une valeur manquante)
# calcule les contributions à la croissance (ne fonctionne pas)
vt <- function(x, na.rm = FALSE) (100*(x/lag(x,1)-1))
ga <- function(x, na.rm = FALSE) (100*(x/lag(x,4)-1))
# ct <- function(x,y,na.rm = FALSE) (100*((y-lag(y,1))/x))

# le trim est donné avec une annéee de décalage par rapport à l'annuel (ex : trim : 2025 et 2026, annuel : 2024 à 2026)
annee_base <- as.Date("2024-01-01")        # definit la date de base affichée en annuel
annee_base1 <- annee_base %m-% years(1)    # définit la date avec l'année d'avant pour le calcul des glissts annuels

#### Partie trimestrielle du tableau ####
# par la suite récupérer les données pour chaque pays et créer les tableaux correspondants et les données affichées par chaque pays dans une liste

# récupère les données pays en niveau en trim et création de données en niveau ##
data <- map_dfr(pays_ok, \(pays) {
  data_trim <- dp$trim |>
    dplyr::filter(pays == !!pays) |>
    select(
      any_of(c("date", "PIB", "conso", "consoAPU", "FBCF",
               "FBCFprivee", "FBCFresid", "FBCFpub",
               "exp", "imp", "contribStock",
               "IPCH", "tcho", "population")) ) %>%
    dplyr::filter(date >= annee_base1) %>%                                 # ne conserve que les dates souhaitées pour les calculs
    mutate(pib_hab = PIB/population ) %>%                           # calcule le PIB/hab, la demande intérieure hors stocks, le commerce extérieur
    relocate(pib_hab, .after = PIB) %>%
    mutate(DI_HS = conso+FBCF+consoAPU) %>%
    mutate (com_ext = exp - imp) %>%
    select(-population) %>%                                        # enlève la population
    mutate (ydate = year(date)) %>%                        # crée une variable ydate qui stocke l'année (Y) de chaque date à l'aide de la fonction "format"
    relocate(ydate) |>
    arrange(date)

  # calcule des taux de croissance et des contributions trim
  data_trim1 <- data_trim %>%
    mutate(contrib_DI_HS = 100*((DI_HS - lag(DI_HS))/lag(PIB))) %>%          # calcul des contributions de la DI hors stocks et du cce ext
    mutate(contrib_com_ext = 100*((com_ext - lag(com_ext,1))/lag(PIB,1))) %>%
    mutate(across(c(PIB, pib_hab, conso, FBCF, FBCFresid , FBCFprivee, FBCFpub, consoAPU, exp, imp), ~vt(.x))) %>%
    mutate(across(c(IPCH), ~ga(.x))) %>%                                       # calcul des taux de croissance avec la fonction "vt" et "ga"
    select(-DI_HS, -com_ext) %>%                                                # on enlève la DI hors stock et le cce ext en niveau et on ne garde que leur contrib
    relocate(contrib_DI_HS, .before = contribStock) %>%                        # on met les séries dans le bon ordre pour le tableau de sortie
    relocate(contrib_com_ext, .after = contribStock) %>%
    dplyr::filter(date >= annee_base) %>%                                              # on ne garde que les années récentes
    select(-ydate)

  #### Ajout des lignes manquantes (avec des NA) au df trim ####
  data_trim_recap <- data_trim1  %>%
    mutate(soldeCourant = NA,
           deficit = NA,
           dette = NA,
           impulsion = NA)

  #### Partie annuelle du tableau basée sur les variables trim ####
  data_calc_ann <- data_trim %>%   # crée un nveau df pour le calcul des moyennes annuelles
    select(-contribStock, -date) %>%             # supprime la contribution de stocks du df
    group_by(ydate) %>%                    #  regroupe les données par année en faisant la moyenne des données de chaque année par colonne
    summarise_all(mean) %>%
    ungroup()

  # calcul des taux de croissance et des contributions annuelles
  data_calc_ann1 <- data_calc_ann %>%
    mutate(contrib_DI_HS = 100*((DI_HS - lag(DI_HS))/lag(PIB))) %>%
    mutate(contrib_com_ext = 100*((com_ext - lag(com_ext))/lag(PIB))) %>%
    mutate(across(c(PIB, pib_hab, conso, FBCF, FBCFresid , FBCFprivee, FBCFpub, consoAPU, exp, imp), ~vt(.x))) %>%
    mutate(IPCH= vt(IPCH)) %>%
    mutate(contribStock = PIB - contrib_DI_HS - contrib_com_ext) %>%
    select(-DI_HS, -com_ext) %>%
    relocate(contrib_com_ext, .after = contribStock) %>%
    relocate(IPCH, .after = contrib_com_ext ) %>%
    relocate(tcho, .after = IPCH) %>%
    dplyr::filter(ydate >= year(annee_base)) %>%
    mutate(date = as.character(ydate)) |>
    select(-ydate)

  #### Partie annuelle du tableau issue d'excel ####

  ## récupère les données pays en niveau en annuel ##
  data_ann <- dp$an |>
    dplyr::filter(pays == !!pays) |>
    select(any_of(c("date", "deficit", "dette", "soldeCourant", "impulsion"))) |>
    dplyr::filter(date >= year(annee_base)) %>%                     # ne conserve que les années récentes
    mutate(date = date |> as.character()) %>%               # extrait l'année de la date et transforme cette année en chaine de caractères
    relocate(soldeCourant, .before = deficit)

  #### Fusion des tableaux annuels ####
  data_ann_recap <- full_join(data_calc_ann1, data_ann, by="date") |>
    relocate(date)

  #### Fusion des tableaux trim et annuels ####

  data_ann_recap <- data_ann_recap %>%
    mutate(date = str_c(date, " annuel"))

  data_trim_recap <-  data_trim_recap %>%
    mutate(date= str_c(year(date), " T", quarter(date)))

  data_recap <- bind_rows(data_trim_recap, data_ann_recap)

  #### Transposition du df ####
  # on définit les noms des lignes pour le tableau de publication
  # on donne un nom à la colonne avec les noms de lignes
  lignes <- tribble( ~group, ~code,
                     1, "pib",
                     1, "pibh",
                     1, "cm",
                     1, "capu",
                     1, "fbcf",
                     1, "fbcfpp",
                     1, "fbcfr",
                     1, "fbcfapu",
                     1, "exp",
                     1, "imp",
                     2, "di",
                     2, "vs",
                     2, "soldecom",
                     3, "inf",
                     3, "tcho",
                     3, "soldecrt",
                     3, "defapu",
                     3, "dette",
                     3, "impulsion")

  data_t <- data_recap %>%
    clean_t() %>%
    select(-"2024 T1", -"2024 T2", -"2024 T3", -"2024 T4",
           -"2025 T1", -"2025 T2")

  data_t <- lignes %>%
    bind_cols(data_t) |>
    mutate(blank = "   ") |>
    relocate(blank, .before = `2024 annuel`)

  data_t |> mutate(pays = !!pays)
})
#### Création du tableau de sortie ####
# on crée des groupes avec les noms de lignes à regrouper
# on utilise row_group_order pour spécifier l'ordre d'affichage de chaque groupe

lilab <- tribble( ~group, ~code, ~label,
                   1, "pib", "PIB",
                   1, "pibh", "PIB par habitant",
                   1, "cm", "Consommation ménages",
                   1, "capu", "Consommation publique",
                   1, "fbcf", "FBCF totale",
                   1, "fbcfpp", " *dont* : productive privée",
                   1, "fbcfr",  "            logement",
                   1, "fbcfapu", "            APU",
                   1, "exp", "Exportations",
                   1, "imp", "Importations",
                   2, "di", "Demande intérieure",
                   2, "vs",  "Variations de stocks",
                   2, "soldecom", "Commerce extérieur",
                   3, "inf", "Inflation",
                   3, "tcho", "Taux de chômage",
                   3, "soldecrt", "Solde courant",
                   3, "defapu", "Déficit public",
                   3, "dette", "Dette publique",
                   3, "impulsion", "Impulsion budgétaire")

lilab_fra <- tribble( ~group, ~code, ~label,
                  1, "pib", "PIB",
                  1, "pibh", "PIB par habitant",
                  1, "cm", "Consommation ménages",
                  1, "capu", "Consommation publique",
                  1, "fbcf", "FBCF totale",
                  1, "fbcfpp",  " *dont* : SNF-EI",
                  1, "fbcfr",   "           ménages",
                  1, "fbcfapu", "           APU",
                  1, "exp", "Exportations",
                  1, "imp", "Importations",
                  2, "di", "Demande intérieure",
                  2, "vs",  "Variations de stocks",
                  2, "soldecom", "Commerce extérieur",
                  3, "inf", "Inflation",
                  3, "tcho", "Taux de chômage",
                  3, "soldecrt", "Solde courant",
                  3, "defapu", "Déficit public",
                  3, "dette", "Dette publique",
                  3, "impulsion", "Impulsion budgétaire") |>
  mutate(pays = "FRA")


liglab <- lilab |>
  cross_join(tibble(pays = pays_ok)) |>
  left_join(lilab_fra, by = c("code", "pays"), suffix = c("", ".fr")) |>
  mutate(
    label = ifelse(is.na(label.fr), label, label.fr)) |>
  select(group, code, pays, label)

data <- data |> left_join(
  liglab, by = c("code", "pays", "group")) |>
  select(-code) |>
  relocate(group, label)

# Retourner les données brutes ET la fonction tableau
list(
  donnees_brutes = data,

  tableau = function(pays, source="Eurostat", prev = "prévision OFCE avril 2026") {
  td <- data |>
    dplyr::filter(pays == !!pays)

  if(nrow(td)==0)
    return(NULL)

  td |>
    select(-pays, -`2024 annuel`) |>
    rowwise() |>
    dplyr::filter(!all(is.na(c_across(-c(group, label, blank))))) |>
    ungroup() |>
    gt::gt(id=pays)  |>
    tab_row_group(NULL, rows = group == 1, id = "g1") |>
    tab_row_group(NULL, rows = group == 2, id = "g2") |>
    tab_row_group(NULL, rows = group == 3, id = "g3") |>
    row_group_order(c("g1", "g2", "g3")) |>
    tab_spanner("2025", contains("2025 T")) |>
    tab_spanner("2026", contains("2026 T")) |>
    tab_spanner("2025", `2025 annuel`, id = "2025a") |>
    tab_spanner("2026", `2026 annuel`, id = "2026a") |>
    tab_spanner("2027", `2027 annuel`, id = "2027a") |>
    cols_label("2025 annuel" = "", "2026 annuel" = "", "2027 annuel" = "",  blank = "")  |>
    cols_label_with(fn = ~ str_replace(., "\\d{4} (T\\d{1})", "\\1" ))  |>
    cols_label_with(fn = ~ str_replace(., "^\\d{4}.+$", "" )) |>
    cols_label(label = "en %", blank = "")  |>
    ofce::ofce_fmt_decimal() |>
    ofce::ofce_fmt_decimal(row = label == "Dette publique", decimals = 0) |>
    fmt_markdown(label) |>
    sub_missing()  |>
    cols_nanoplot(
      new_col_name = "plot",
      plot_type = "line",
      columns = starts_with(c("2025 T", "2026 T", "2027 T")),
      rows = !str_detect(label, "^Solde|^Dette|^Impulsion|^D\u00e9ficit"),
      missing_vals = "zero",
      autohide = FALSE,
      before = "blank",
      reference_line = 0,
      plot_height = "1.8em",
      options = nanoplot_options(
        data_point_fill_color = c(rep("grey", 2), rep(prev_color_f5, 8)),
        data_point_stroke_color = c(rep("grey", 2), rep(prev_color_f5, 8)),
        data_line_stroke_color =  "#CCC",
        data_area_fill_color = "transparent",
        y_val_fmt_fn = \(x) x |> round(1) |> str_replace("\\.", ",") |> str_c("%"))) |>
    cols_width(plot ~ px(110)) |>
    cols_width(label ~ px(120)) |>
    cols_hide(starts_with("2027 T")) |>
    cols_label(plot = md("**de 2025t3 \u00e0 2027t4**")) |>
    cols_hide(c(group, blank)) |>
    cols_align("left", label) |>
    cols_align("center", plot) |>
    ofce::ofce_align_decimal() |>
    ofce::ofce_row_bold(label=="PIB") |>
    ofce::ofce_spanners_bold() |>
    tab_style(cell_text(style = "italic", size = "90%", align = "right"),
              locations = cells_column_labels(label)) |>
    ofce::ofce_cols_fill(starts_with(c("2026", "2027"))) |>
    tab_style(cell_text(align = "right"), cells_column_labels(-c(group, label, plot))) |>
    cols_width(
      starts_with(c("2025 T", "2026 T", "2027 T")) ~ px(38) ,
      starts_with(c("2025 a", "2026 a", "2027 a")) ~ px(38)) |>
    tab_footnote(
      "En volume, aux prix chaînés.",
      cells_body(columns = label, rows = !str_detect(label, "^Inflation|^Taux de chômage|^Solde|^Dette|^Impulsion|^Déficit public"))) |>
    tab_footnote(
      "FBCF : Formation Brute de Capital Fixe ; APU : Administrations Publiques.",
      cells_body(columns = label, rows = str_detect(label, "FBCF|APU"))) |>
    tab_footnote(
      "Biens et services.",
      cells_body(columns = label, rows = str_detect(label, "^Export|^Import|^Commerce"))) |>
    tab_footnote(
      "Demande intérieure hors variation de stocks.",
      cells_body(columns = label, rows = str_detect(label, "^Demande"))) |>
    tab_footnote(
      "Contribution à la croissance du PIB.",
      cells_body(columns = label, rows = str_detect(label, "^Demande|^Variations|^Commerce"))) |>
    tab_footnote(
      "Evolution de l'indice des prix à la consommation (IPC ou IPCH selon les pays). Pour les trimestres, glissement annuel (T/T(-4)) des prix. Pour les années, croissance moyenne annuelle des prix.",
      cells_body(columns = label, rows = label == "Inflation")) |>
    tab_footnote(
      "Au sens du BIT, en % de la population active. Pour les trimestres moyenne trimestrielle,
      pour les années, moyenne annuelle.",
      cells_body(columns = label, rows = str_detect(label,"^Taux de chômage"))) |>
    tab_footnote(
      "En % du PIB annuel, en fin d'année.",
      cells_body(columns = label, rows = str_detect(label, "^Solde|^Dette|^Déficit public"))) |>
    tab_footnote(
      "Variation annuelle du déficit public (APU) structurel, en points de PIB.",
      cells_body(columns = label, rows = str_detect(label, "^Impulsion"))) |>
    tab_source_note(
      md("*Sources* : {source}, {prev}." |> glue())) |>
    ofce::ofce_tab_options() |>
    gt::opt_css(glue("
            #{pays} .gt_table_body td {{
              height: 1.9em;
            }}
            #{pays} .vert-line text {{
              font-family: 'Open Sans';
              font-size: 4em;
              font-weight: normal;
              color: #777;
            }}"))
  }
)

