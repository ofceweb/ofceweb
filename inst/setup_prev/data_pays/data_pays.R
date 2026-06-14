library(tidyverse)

# Télécharge data_pays.RData depuis le dépôt privé OFCE/prev_orga si
# GITHUB_PAT est défini, sinon charge la version locale.
if (Sys.getenv("GITHUB_PAT") != "") {
  owner  <- "OFCE"
  repo   <- "prev_orga"
  path   <- "Comptes Pays/data_pays.RData" |> utils::URLencode(repeated = TRUE)
  pat    <- Sys.getenv("GITHUB_PAT")
  branch <- "main"

  download.file(
    url      = glue::glue("https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}"),
    destfile = "data_pays.RData",
    headers  = c(Authorization = paste("Bearer", pat))
  )
}

load("data_pays.RData")

convert_date <- function(x) as.Date(as.numeric(x), origin = "1899-12-30")

trim <- data_pays$resume_t |>
  left_join(
    {
      px <- data_pays$prix |> select(PAYS, DATE, any_of(c("ipc", "ipch")))
      if ("ipc" %in% names(px) && "ipch" %in% names(px)) {
        px |> mutate(IPCH = coalesce(ipc, ipch)) |> select(PAYS, DATE, IPCH)
      } else if ("ipc" %in% names(px)) {
        px |> rename(IPCH = ipc) |> select(PAYS, DATE, IPCH)
      } else {
        px |> rename(IPCH = ipch) |> select(PAYS, DATE, IPCH)
      }
    },
    by = c("PAYS", "DATE")
  ) |>
  rename(
    pays       = PAYS,
    date       = DATE,
    PIB        = pib_1,
    conso      = p3s14_1,
    FBCF       = p51_1,
    FBCFresid  = p51s14_1,
    FBCFprivee = p51s11_1,
    FBCFpub    = p51s13_1,
    consoAPU   = p3s13_1,
    exp        = p6_1,
    imp        = p7_1,
    contribStock = contribstock
  ) |>
  mutate(
    date  = (date),
    across(-c(pays, date), ~ suppressWarnings(as.numeric(.x)))
  )

an <- data_pays$resume_a |>
  rename(
    pays         = PAYS,
    date         = DATE,
    deficit      = soldepublic,
    soldeCourant = soldecourant
  ) |>
  mutate(
    date  = (date),
    across(-c(pays, date), ~ suppressWarnings(as.numeric(.x)))
  )

return(list(trim = trim, an = an))
