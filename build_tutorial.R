#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

step_answer_qmd <- c(
  "steps/step01_sim.qmd",
  "steps/step02_sim_iot_fit.qmd",
  "steps/step03_endogenous_transition.qmd",
  "steps/step04_row_lite.qmd",
  "steps/step05_exogenous_transition.qmd",
  "steps/step06_emissions.qmd"
)
index_qmd <- "tutorial_sfc-io.qmd"
r_out_dir <- "R"

step_question_qmd <- sub("\\.qmd$", "-question.qmd", step_answer_qmd)
step_ids <- sub("steps/(step[0-9]+)_.*", "\\1", step_answer_qmd)

show_help <- function() {
  cat(
    "Usage: Rscript build_tutorial.R [flags]\n\n",
    "Flags:\n",
    "  --generate-question-steps   Generate question QMD for each step\n",
    "  --generate-r-steps-answer   Generate per-step answer R files (optional)\n",
    "  --generate-r-steps-question Generate per-step question R files (default R output)\n",
    "  --check-step-sync           Regenerate questions and fail if git diff exists\n",
    "  --render-html               Render docs index + answer/question step pages\n",
    "  --help                      Show this help\n",
    sep = ""
  )
}

if ("--help" %in% args) {
  show_help()
  quit(save = "no", status = 0)
}

flags <- list(
  generate_question_steps = "--generate-question-steps" %in% args || "--generate-question-qmd" %in% args,
  generate_r_steps_answer = "--generate-r-steps-answer" %in% args || "--generate-r-answer" %in% args,
  generate_r_steps_question = "--generate-r-steps-question" %in% args || "--generate-r-question" %in% args,
  check_step_sync = "--check-step-sync" %in% args,
  render_html = "--render-html" %in% args
)

if (!any(unlist(flags))) {
  message("No flags supplied; defaulting to --generate-question-steps --generate-r-steps-question")
  flags$generate_question_steps <- TRUE
  flags$generate_r_steps_question <- TRUE
}

trim_quotes <- function(x) {
  x <- trimws(x)
  if (nchar(x) >= 2 && ((startsWith(x, "\"") && endsWith(x, "\"")) || (startsWith(x, "'") && endsWith(x, "'")))) {
    return(substr(x, 2, nchar(x) - 1))
  }
  x
}

parse_exercise_meta <- function(meta_str, line_no) {
  parts <- strsplit(meta_str, ";", fixed = TRUE)[[1]]
  out <- list()
  for (part in parts) {
    part <- trimws(part)
    if (!nzchar(part)) next
    kv <- strsplit(part, "=", fixed = TRUE)[[1]]
    if (length(kv) < 2) stop("Malformed @exercise metadata at line ", line_no, ": ", part, call. = FALSE)
    key <- trimws(kv[1])
    val <- trimws(paste(kv[-1], collapse = "="))
    out[[key]] <- trim_quotes(val)
  }
  required <- c("id", "kind", "question_expr", "prompt")
  missing <- required[!vapply(required, function(k) !is.null(out[[k]]) && nzchar(out[[k]]), logical(1))]
  if (length(missing) > 0) stop("Missing required @exercise key(s) at line ", line_no, ": ", paste(missing, collapse = ", "), call. = FALSE)
  if (!(out$kind %in% c("core", "optional"))) stop("Invalid @exercise kind at line ", line_no, ": ", out$kind, call. = FALSE)
  tryCatch(parse(text = out$question_expr), error = function(e) stop("Invalid question_expr at line ", line_no, ": ", out$question_expr, call. = FALSE))
  out
}

generate_question_lines <- function(lines) {
  seen_ids <- character(0)
  out <- lines
  for (i in seq_along(lines)) {
    ln <- lines[[i]]
    if (!grepl("@exercise\\[", ln)) next
    m <- regmatches(ln, regexec("^(\\s*[A-Za-z][A-Za-z0-9._]*\\s*<-\\s*)([^#]+?)(\\s*)#\\s*@exercise\\[(.*)\\]\\s*$", ln, perl = TRUE))[[1]]
    if (length(m) != 5) stop("@exercise annotation must be on a single assignment line (line ", i, ").", call. = FALSE)
    prefix <- m[2]
    meta <- parse_exercise_meta(m[5], i)
    if (meta$id %in% seen_ids) stop("Duplicate @exercise id found: ", meta$id, " (line ", i, ").", call. = FALSE)
    seen_ids <- c(seen_ids, meta$id)
    hint_txt <- if (!is.null(meta$hint) && nzchar(meta$hint)) paste0(" Hint: ", meta$hint) else ""
    todo <- paste0("# TODO [", meta$kind, ":", meta$id, "] ", meta$prompt, hint_txt)
    out[[i]] <- paste0(prefix, meta$question_expr, "  ", todo)
  }
  out
}

generate_question_qmd <- function(in_file, out_file) {
  lines <- readLines(in_file, warn = FALSE)
  q_lines <- generate_question_lines(lines)
  writeLines(q_lines, out_file)
}

generate_r_from_qmd <- function(in_file, out_file) {
  if (!requireNamespace("knitr", quietly = TRUE)) stop("Package 'knitr' is required for R generation.", call. = FALSE)
  if (!dir.exists(dirname(out_file))) dir.create(dirname(out_file), recursive = TRUE)
  knitr::purl(in_file, output = out_file, documentation = 0)
  message("Wrote: ", out_file)
}

must_succeed <- function(cmd, cmd_args, env = character()) {
  status <- system2(cmd, args = cmd_args, env = env)
  if (!identical(status, 0L)) stop("Command failed: ", cmd, " ", paste(cmd_args, collapse = " "), call. = FALSE)
}

if (flags$generate_question_steps) {
  message("Generating question step QMDs...")
  for (i in seq_along(step_answer_qmd)) {
    generate_question_qmd(step_answer_qmd[i], step_question_qmd[i])
    message("Wrote: ", step_question_qmd[i])
  }
}

if (flags$generate_r_steps_answer) {
  message("Generating answer R step files...")
  for (i in seq_along(step_answer_qmd)) {
    out <- file.path(r_out_dir, paste0(step_ids[i], "_answer.R"))
    generate_r_from_qmd(step_answer_qmd[i], out)
  }
}

if (flags$generate_r_steps_question) {
  message("Generating question R step files...")
  for (i in seq_along(step_question_qmd)) {
    if (!file.exists(step_question_qmd[i])) generate_question_qmd(step_answer_qmd[i], step_question_qmd[i])
    out <- file.path(r_out_dir, paste0(step_ids[i], "_question.R"))
    generate_r_from_qmd(step_question_qmd[i], out)
  }
}

if (flags$check_step_sync) {
  message("Checking question step sync...")
  for (i in seq_along(step_answer_qmd)) {
    generate_question_qmd(step_answer_qmd[i], step_question_qmd[i])
  }
  status <- system2("git", c("diff", "--exit-code", "--", step_question_qmd), stdout = FALSE, stderr = FALSE)
  if (!identical(status, 0L)) stop("One or more step question files are out of sync.", call. = FALSE)
  message("Step question files are in sync.")
}

if (flags$render_html) {
  if (!dir.exists("docs")) dir.create("docs", recursive = TRUE)

  message("Rendering landing page...")
  must_succeed("quarto", c("render", index_qmd, "--to", "html", "--output", "index.html", "--output-dir", "docs"))

  if (!dir.exists("docs/answer")) dir.create("docs/answer", recursive = TRUE)
  if (!dir.exists("docs/question")) dir.create("docs/question", recursive = TRUE)

  if (!all(file.exists(step_question_qmd))) {
    for (i in seq_along(step_answer_qmd)) generate_question_qmd(step_answer_qmd[i], step_question_qmd[i])
  }

  message("Rendering answer step pages...")
  for (i in seq_along(step_answer_qmd)) {
    must_succeed("quarto", c("render", step_answer_qmd[i], "--to", "html"))
    src_html <- sub("\\.qmd$", ".html", step_answer_qmd[i])
    file.copy(src_html, file.path("docs/answer", paste0(step_ids[i], ".html")), overwrite = TRUE)
  }

  message("Rendering question step pages...")
  for (i in seq_along(step_question_qmd)) {
    must_succeed("quarto", c("render", step_question_qmd[i], "--to", "html"))
    src_html <- sub("\\.qmd$", ".html", step_question_qmd[i])
    file.copy(src_html, file.path("docs/question", paste0(step_ids[i], ".html")), overwrite = TRUE)
  }
}

message("Done.")
