# Auto-extracted helper functions for standalone step tutorials.
# Do not edit generated blocks manually unless updating all step usage.

# @first_intro_step: 6
normalize_nace_code <- function(x) {
  y <- toupper(as.character(x))
  y <- gsub("-", "_", y)
  y <- gsub("\\.", "", y)
  y <- gsub("^([A-Z])(\\d{2})_(\\d{2})$", "\\1\\2_\\1\\3", y, perl = TRUE)
  y
}

# @first_intro_step: 6
get_aea_codes <- function(cfg) {
  params <- list(freq = cfg$freq, airpol = cfg$emissions_airpol, unit = cfg$emissions_unit, geo = cfg$country, time = as.character(cfg$year))
  js <- fetch_eurostat_json("env_ac_ainah_r2", params, cache_dir = cfg$cache_dir)
  vals <- extract_values_by_dim(js, "nace_r2")
  unique(normalize_nace_code(names(vals)[is.finite(vals) & !is.na(vals)]))
}

# @first_intro_step: 6
align_iot_to_aea <- function(iot, cfg) {
  aea_norm <- get_aea_codes(cfg)
  sec_norm <- normalize_nace_code(iot$sector_codes)
  keep <- sec_norm %in% aea_norm
  idx <- which(keep)

  iot$sector_codes <- iot$sector_codes[idx]
  iot$sector_labels <- iot$sector_labels[idx]
  iot$n <- length(idx)
  iot$Z0 <- iot$Z0[idx, idx, drop = FALSE]
  iot$A0 <- iot$A0[idx, idx, drop = FALSE]
  iot$L0 <- solve(diag(iot$n) - iot$A0 + diag(1e-8, iot$n))

  for (nm in c("x0", "C_i0", "G_i0", "I_i0", "EX_i0", "m_i", "va_coeff", "beta_C", "beta_G")) iot[[nm]] <- iot[[nm]][idx]

  iot$F0 <- iot$C_i0 + iot$G_i0 + iot$I_i0 + iot$EX_i0
  iot$G0 <- sum(iot$G_i0)
  iot$Y0 <- sum(iot$va_coeff * iot$x0)
  if (sum(iot$beta_C) > 0) iot$beta_C <- iot$beta_C / sum(iot$beta_C)
  if (sum(iot$beta_G) > 0) iot$beta_G <- iot$beta_G / sum(iot$beta_G)
  iot
}

# @first_intro_step: 6
load_aea_emissions <- function(cfg, sector_codes, x0) {
  if (!identical(cfg$table_type, "industry_by_industry")) {
    stop("AEA emissions are not directly available for product_by_product mode.", call. = FALSE)
  }

  params <- list(freq = cfg$freq, airpol = cfg$emissions_airpol, unit = cfg$emissions_unit, geo = cfg$country, time = as.character(cfg$year))
  js <- fetch_eurostat_json("env_ac_ainah_r2", params, cache_dir = cfg$cache_dir)
  vals <- extract_values_by_dim(js, "nace_r2")
  names(vals) <- normalize_nace_code(names(vals))

  sec_norm <- normalize_nace_code(sector_codes)
  em_ths_t <- as.numeric(vals[sec_norm])
  names(em_ths_t) <- sector_codes

  missing <- !is.finite(em_ths_t)
  if (any(missing)) stop("CO2 missing for sectors: ", paste(sector_codes[missing], collapse = ", "), call. = FALSE)

  intensity <- (em_ths_t * 1e6) / pmax(as.numeric(x0), 1e-9)
  intensity[!is.finite(intensity)] <- 0
  data.frame(sector = sector_codes, intensity_kg_per_meur = intensity, stringsAsFactors = FALSE)
}

# @first_intro_step: 6
attach_production_emissions <- function(sim_result, intensity_tbl, sector_codes) {
  idx <- match(sector_codes, intensity_tbl$sector)
  s <- intensity_tbl$intensity_kg_per_meur[idx]
  s[!is.finite(s)] <- 0
  co2_kg <- as.numeric(sim_result$x %*% s)
  out <- sim_result$aggregate
  out$CO2_Mt <- co2_kg / 1e9
  out
}
