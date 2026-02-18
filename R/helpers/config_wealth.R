# Auto-extracted helper functions for standalone step tutorials.
# Do not edit generated blocks manually unless updating all step usage.

# @first_intro_step: 2
make_core_config <- function() {
  list(
    country = Sys.getenv("SFC_IO_COUNTRY", "AT"),
    year = Sys.getenv("SFC_IO_YEAR", "2020"),
    scope = Sys.getenv("SFC_IO_SCOPE", "TOTAL"),
    table_type = Sys.getenv("SFC_IO_TABLE_TYPE", "product_by_product"),
    freq = "A",
    iot_unit = "MIO_EUR",
    wealth_unit = "MIO_EUR",
    wealth_co_nco = "NCO",
    wealth_na_item = "BF90",
    wealth_finpos = "LIAB",
    cache_dir = "data"
  )
}

# @first_intro_step: 6
make_emissions_config <- function() {
  list(
    country = Sys.getenv("SFC_EMIS_COUNTRY", "BE"),
    year = Sys.getenv("SFC_EMIS_YEAR", "2020"),
    scope = Sys.getenv("SFC_EMIS_SCOPE", "TOTAL"),
    table_type = Sys.getenv("SFC_EMIS_TABLE_TYPE", "industry_by_industry"),
    freq = "A",
    iot_unit = "MIO_EUR",
    wealth_unit = "MIO_EUR",
    wealth_co_nco = "NCO",
    wealth_na_item = "BF90",
    wealth_finpos = "LIAB",
    emissions_airpol = Sys.getenv("SFC_EMIS_AIRPOL", "CO2"),
    emissions_unit = "THS_T",
    cache_dir = "data",
    enforce_co2_consistency = TRUE
  )
}

# @first_intro_step: 2
load_wealth_init <- function(cfg) {
  params <- list(
    freq = cfg$freq,
    unit = cfg$wealth_unit,
    co_nco = cfg$wealth_co_nco,
    sector = c("S13", "S14"),
    finpos = cfg$wealth_finpos,
    na_item = cfg$wealth_na_item,
    geo = cfg$country,
    time = as.character(cfg$year)
  )
  cache_paths <- query_cache_paths("nasa_10_f_bs_wealth", params, cfg$cache_dir)
  if (file.exists(cache_paths$rds)) return(readRDS(cache_paths$rds))
  js <- fetch_eurostat_json("nasa_10_f_bs", params, cache_dir = cfg$cache_dir)
  vals <- extract_values_by_dim(js, "sector")
  out <- list(V0 = as.numeric(vals[["S14"]]), B0 = max(-as.numeric(vals[["S13"]]), 0))
  saveRDS(out, cache_paths$rds)
  out
}
