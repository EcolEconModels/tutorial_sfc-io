# Auto-extracted helper functions for standalone step tutorials.
# Do not edit generated blocks manually unless updating all step usage.

# @first_intro_step: 2
iot_schema <- function(table_type) {
  if (identical(table_type, "industry_by_industry")) {
    list(dataset_id = "naio_10_cp1750", row_dim = "ind_ava", col_dim = "ind_use")
  } else {
    list(dataset_id = "naio_10_cp1700", row_dim = "prd_ava", col_dim = "prd_use")
  }
}

# @first_intro_step: 2
sum_matching_cols <- function(M, col_codes, col_labels, patterns) {
  p <- paste(patterns, collapse = '|')
  hit <- grepl(p, col_codes, ignore.case = TRUE) | grepl(p, col_labels, ignore.case = TRUE)
  if (!any(hit)) return(rep(0, nrow(M)))
  rowSums(M[, hit, drop = FALSE], na.rm = TRUE)
}

# @first_intro_step: 2
find_energy_indices <- function(sector_codes) {
  idx_brown <- grep("(^|_)C19", sector_codes)[1]
  idx_green <- grep("(^|_)D35|(^|_)D", sector_codes)[1]
  if (is.na(idx_brown) || is.na(idx_green)) stop("Energy sectors not found for this IOT configuration.", call. = FALSE)
  list(idx_green = idx_green, idx_brown = idx_brown)
}

# @first_intro_step: 2
download_or_load_iot <- function(cfg) {
  schema <- iot_schema(cfg$table_type)
  params <- list(freq = cfg$freq, unit = cfg$iot_unit, stk_flow = cfg$scope, geo = cfg$country, time = as.character(cfg$year))
  cache_paths <- query_cache_paths(paste0(schema$dataset_id, "_iot"), params, cfg$cache_dir)
  if (file.exists(cache_paths$rds)) return(readRDS(cache_paths$rds))
  js <- fetch_eurostat_json(schema$dataset_id, params, cache_dir = cfg$cache_dir)
  mat <- extract_matrix_from_json(js, schema$row_dim, schema$col_dim)

  row_codes <- mat$row_cat$code
  row_labels <- mat$row_cat$label
  col_codes <- mat$col_cat$code
  col_labels <- mat$col_cat$label

  tu_col <- match('TU', col_codes)
  if (is.na(tu_col)) tu_col <- match('TOTAL', col_codes)

  x_by_row <- mat$M[, tu_col]
  names(x_by_row) <- row_codes
  exclude <- c('TOTAL', 'TU', 'TFU', 'TS_BP', 'IMP', 'B1G', 'P1', 'P2_ADJ', 'P7', 'P7_B0', 'P7_D0', 'P7_U2', 'P7_U3')
  sector_codes <- setdiff(intersect(row_codes, col_codes), exclude)
  sector_codes <- intersect(sector_codes, names(x_by_row)[is.finite(x_by_row) & x_by_row > 1e-9])

  r_idx <- match(sector_codes, row_codes)
  c_idx <- match(sector_codes, col_codes)
  Z <- mat$M[r_idx, c_idx, drop = FALSE]
  x0 <- as.numeric(x_by_row[sector_codes])
  names(x0) <- sector_codes

  A0 <- sweep(Z, 2, pmax(x0, 1e-9), '/')
  A0[!is.finite(A0)] <- 0
  L0 <- solve(diag(length(sector_codes)) - A0 + diag(1e-8, length(sector_codes)))

  Msel <- mat$M[r_idx, , drop = FALSE]
  C_i0 <- sum_matching_cols(Msel, col_codes, col_labels, c('^P3_S14$', 'households'))
  C_i0 <- C_i0 + sum_matching_cols(Msel, col_codes, col_labels, c('^P3_S15$', 'NPISH'))
  G_i0 <- sum_matching_cols(Msel, col_codes, col_labels, c('^P3_S13$', 'government'))
  I_i0 <- sum_matching_cols(Msel, col_codes, col_labels, c('^P51G$', '^P52$', '^P53$', '^P5$', 'gross capital'))
  EX_i0 <- sum_matching_cols(Msel, col_codes, col_labels, c('^P6$', '^P6_', 'exports'))

  imp_row <- which(row_codes %in% c('P7', 'IMP'))
  imports_i <- as.numeric(mat$M[imp_row[1], c_idx, drop = TRUE])
  imports_i[!is.finite(imports_i)] <- 0

  m_i <- pmin(pmax(imports_i / pmax(x0, 1e-9), 0), 0.95)
  va_row <- which(row_codes == 'B1G')
  va_coeff <- as.numeric(mat$M[va_row[1], c_idx, drop = TRUE]) / pmax(x0, 1e-9)
  va_coeff[!is.finite(va_coeff)] <- 0
  va_coeff <- pmax(va_coeff, 0)

  beta_C <- C_i0 / sum(C_i0)
  beta_G <- G_i0 / sum(G_i0)
  beta_C[!is.finite(beta_C)] <- 0
  beta_G[!is.finite(beta_G)] <- 0
  if (sum(beta_C) > 0) beta_C <- beta_C / sum(beta_C)
  if (sum(beta_G) > 0) beta_G <- beta_G / sum(beta_G)

  out <- list(
    base_year = as.integer(cfg$year),
    country = cfg$country,
    scope = cfg$scope,
    table_type = cfg$table_type,
    dataset_id = schema$dataset_id,
    n = length(sector_codes),
    sector_codes = sector_codes,
    sector_labels = row_labels[r_idx],
    Z0 = Z,
    A0 = A0,
    L0 = L0,
    x0 = x0,
    C_i0 = C_i0,
    G_i0 = G_i0,
    I_i0 = I_i0,
    EX_i0 = EX_i0,
    F0 = C_i0 + G_i0 + I_i0 + EX_i0,
    m_i = m_i,
    va_coeff = va_coeff,
    Y0 = sum(va_coeff * x0),
    G0 = sum(G_i0),
    beta_C = beta_C,
    beta_G = beta_G
  )
  saveRDS(out, cache_paths$rds)
  out
}
