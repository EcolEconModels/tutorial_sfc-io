# Auto-extracted helper functions for standalone step tutorials.
# Do not edit generated blocks manually unless updating all step usage.

# @first_intro_step: 2
ordered_categories <- function(dim_obj) {
  raw_idx <- unlist(dim_obj[["category"]][["index"]])
  ord <- order(as.integer(raw_idx))
  codes <- names(raw_idx)[ord]
  lbl_all <- dim_obj[["category"]][["label"]]
  labels <- unlist(lbl_all[codes])
  labels[is.na(labels)] <- codes[is.na(labels)]
  data.frame(code = codes, label = labels, stringsAsFactors = FALSE)
}

# @first_intro_step: 2
decode_jsonstat_index <- function(flat0, sizes) {
  k <- length(sizes)
  pos <- integer(k)
  rem <- as.integer(flat0)
  for (i in seq_len(k)) {
    stride <- if (i == k) 1L else as.integer(prod(sizes[(i + 1):k]))
    pos[i] <- rem %/% stride
    rem <- rem %% stride
  }
  pos
}

# @first_intro_step: 2
extract_matrix_from_json <- function(js, row_dim, col_dim) {
  ids <- unlist(js[["id"]])
  sizes <- as.integer(unlist(js[["size"]]))
  row_i <- match(row_dim, ids)
  col_i <- match(col_dim, ids)
  row_cat <- ordered_categories(js[["dimension"]][[row_dim]])
  col_cat <- ordered_categories(js[["dimension"]][[col_dim]])
  vals <- unlist(js[["value"]])
  M <- matrix(NA_real_, nrow = nrow(row_cat), ncol = nrow(col_cat))
  flat_idx <- as.integer(names(vals))
  for (j in seq_along(flat_idx)) {
    pos <- decode_jsonstat_index(flat_idx[j], sizes)
    M[pos[row_i] + 1L, pos[col_i] + 1L] <- as.numeric(vals[[j]])
  }
  list(M = M, row_cat = row_cat, col_cat = col_cat)
}

# @first_intro_step: 2
extract_values_by_dim <- function(js, dim_name) {
  ids <- unlist(js[['id']])
  sizes <- as.integer(unlist(js[['size']]))
  dim_i <- match(dim_name, ids)
  cat_tbl <- ordered_categories(js[['dimension']][[dim_name]])
  vals <- unlist(js[['value']])
  out <- setNames(rep(NA_real_, nrow(cat_tbl)), cat_tbl$code)
  flat_idx <- as.integer(names(vals))
  for (j in seq_along(flat_idx)) {
    pos <- decode_jsonstat_index(flat_idx[j], sizes)
    out[cat_tbl$code[pos[dim_i] + 1L]] <- as.numeric(vals[[j]])
  }
  out
}
