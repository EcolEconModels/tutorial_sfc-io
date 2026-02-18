# Auto-extracted helper functions for standalone step tutorials.
# Do not edit generated blocks manually unless updating all step usage.

# @first_intro_step: 2
ensure_cache_dir <- function(cache_dir = "data") {
  if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
  cache_dir
}

# @first_intro_step: 2
sanitize_for_filename <- function(x) gsub("[^A-Za-z0-9_\\-]", "_", x)

cache_file_for_query <- function(dataset_id, params, cache_dir) {
  key_parts <- character(0)
  for (nm in names(params)) {
    vv <- params[[nm]]
    for (v in vv) key_parts <- c(key_parts, paste0(nm, "-", as.character(v)))
  }
  file.path(cache_dir, paste0(dataset_id, "__", sanitize_for_filename(paste(key_parts, collapse = "__")), ".json"))
}

# @first_intro_step: 2

# @first_intro_step: 2
query_cache_paths <- function(dataset_id, params, cache_dir) {
  json_file <- cache_file_for_query(dataset_id, params, cache_dir)
  rds_file <- sub("\\.json$", ".rds", json_file)
  list(json = json_file, rds = rds_file)
}

# @first_intro_step: 2
build_query_parts <- function(params) {
  q <- character(0)
  for (nm in names(params)) {
    vv <- params[[nm]]
    for (v in vv) q <- c(q, paste0(nm, "=", utils::URLencode(as.character(v), reserved = TRUE)))
  }
  q
}

# @first_intro_step: 2
fetch_eurostat_json <- function(dataset_id, params, cache_dir = "data") {
  cache_dir <- ensure_cache_dir(cache_dir)
  cache_file <- cache_file_for_query(dataset_id, params, cache_dir)
  if (file.exists(cache_file)) return(jsonlite::read_json(cache_file, simplifyVector = FALSE))
  base <- "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
  url <- paste0(base, "/", dataset_id, "?", paste(build_query_parts(params), collapse = "&"))
  utils::download.file(url, destfile = cache_file, mode = "wb", quiet = TRUE)
  jsonlite::read_json(cache_file, simplifyVector = FALSE)
}
