#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

qmd_file <- "tutorial_sfc-io.qmd"
r_dir <- "R"
python_dir <- "Python"
data_dir <- "data"
combined_r_file <- file.path(r_dir, "tutorial_sfc-io.R")
html_out <- "tutorial_sfc-io-notebook.html"
slides_out <- "tutorial_sfc-io-slides.html"
setup_file <- file.path(r_dir, "step00_setup.R")

if (!file.exists(qmd_file)) {
  stop("Missing file: ", qmd_file, call. = FALSE)
}

show_help <- function() {
  cat(
    "Usage: Rscript build_tutorial.R [flags]\n\n",
    "Flags:\n",
    "  --generate-r         Generate combined R/tutorial_sfc-io.R from tutorial_sfc-io.qmd\n",
    "  --generate-step-r    Generate per-step scripts in R/\n",
    "  --render-html        Render notebook HTML output\n",
    "  --render-slides      Render revealjs slides output\n",
    "  --help               Show this help\n",
    sep = ""
  )
}

if ("--help" %in% args) {
  show_help()
  quit(save = "no", status = 0)
}

flags <- list(
  generate_r = "--generate-r" %in% args,
  generate_step_r = "--generate-step-r" %in% args,
  render_html = "--render-html" %in% args,
  render_slides = "--render-slides" %in% args
)

if (!any(unlist(flags))) {
  message("No flags supplied; defaulting to --generate-r --generate-step-r")
  flags$generate_r <- TRUE
  flags$generate_step_r <- TRUE
}

ensure_dirs <- function() {
  dir.create(r_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(python_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
}

run_cmd <- function(cmd, cmd_args, env = character()) {
  status <- system2(cmd, args = cmd_args, env = env)
  list(ok = identical(status, 0L), status = status)
}

must_succeed <- function(cmd, cmd_args, env = character()) {
  out <- run_cmd(cmd, cmd_args, env = env)
  if (!out$ok) {
    stop("Command failed: ", cmd, " ", paste(cmd_args, collapse = " "), call. = FALSE)
  }
  invisible(TRUE)
}

extract_r_chunks <- function(lines) {
  step_ids <- sprintf("step%02d", 1:5)
  chunks <- list()

  current_step <- "shared"
  in_chunk <- FALSE
  chunk_label <- NULL
  chunk_buffer <- character()
  chunk_counter <- 0L

  flush_chunk <- function() {
    if (length(chunk_buffer) == 0) return(invisible(NULL))

    code <- chunk_buffer[!grepl("^\\s*#\\|", chunk_buffer)]
    chunks[[length(chunks) + 1L]] <<- list(
      step = current_step,
      label = chunk_label,
      code = code
    )

    invisible(NULL)
  }

  for (ln in lines) {
    if (!in_chunk) {
      m_step <- regmatches(ln, regexec("^##\\s+Step\\s+([0-9]+)\\b", ln))[[1]]
      if (length(m_step) == 2) {
        sid <- sprintf("step%02d", as.integer(m_step[2]))
        if (sid %in% step_ids) current_step <- sid
      }

      m_chunk <- regmatches(ln, regexec("^```\\{r\\s*([^}]*)\\}\\s*$", ln))[[1]]
      if (length(m_chunk) == 2) {
        in_chunk <- TRUE
        chunk_counter <- chunk_counter + 1L
        header <- trimws(m_chunk[2])
        parts <- strsplit(header, ",", fixed = TRUE)[[1]]
        label <- trimws(parts[1])
        if (!nzchar(label)) {
          label <- sprintf("chunk_%03d", chunk_counter)
        }
        chunk_label <- label
        chunk_buffer <- character()
      }
    } else {
      if (grepl("^```\\s*$", ln)) {
        flush_chunk()
        in_chunk <- FALSE
        chunk_label <- NULL
        chunk_buffer <- character()
      } else {
        chunk_buffer <- c(chunk_buffer, ln)
      }
    }
  }

  chunks
}

collapse_chunks <- function(chunk_list) {
  if (length(chunk_list) == 0) return(character())
  out <- character()
  for (ch in chunk_list) {
    out <- c(out, ch$code, "")
  }
  out
}

indent_lines <- function(x, spaces = 2) {
  pad <- paste(rep(" ", spaces), collapse = "")
  ifelse(nzchar(x), paste0(pad, x), "")
}

write_setup_script <- function(shared_chunks, out_file) {
  ensure_dirs()
  code <- collapse_chunks(shared_chunks)
  lines <- c(
    "#!/usr/bin/env Rscript",
    "# Generated from tutorial_sfc-io.qmd. Do not edit by hand.",
    "",
    code
  )
  writeLines(lines, out_file)
}

write_step_script <- function(function_chunks, main_chunks, out_file, prior_files, setup_basename) {
  ensure_dirs()

  fn_code <- collapse_chunks(function_chunks)
  main_code <- collapse_chunks(main_chunks)
  if (length(main_code) == 0) {
    main_code <- c("message('No executable code extracted for this step.')")
  }

  source_lines <- c(
    sprintf("source(file.path(script_dir, '%s'))", setup_basename)
  )

  if (length(prior_files) > 0) {
    src_prev <- sprintf("source_sfc_step(file.path(script_dir, '%s'))", prior_files)
    source_lines <- c(source_lines, src_prev)
  }

  lines <- c(
    "#!/usr/bin/env Rscript",
    "# Generated from tutorial_sfc-io.qmd. Do not edit by hand.",
    "",
    "get_script_dir <- function() {",
    "  full_args <- commandArgs(trailingOnly = FALSE)",
    "  file_arg <- grep('^--file=', full_args, value = TRUE)",
    "  if (length(file_arg) > 0) {",
    "    return(dirname(normalizePath(sub('^--file=', '', file_arg[1]), mustWork = FALSE)))",
    "  }",
    "  getwd()",
    "}",
    "",
    "source_sfc_step <- function(path) {",
    "  old <- Sys.getenv('SFC_IO_SOURCE_MODE', unset = NA_character_)",
    "  Sys.setenv(SFC_IO_SOURCE_MODE = '1')",
    "  on.exit({",
    "    if (is.na(old)) Sys.unsetenv('SFC_IO_SOURCE_MODE') else Sys.setenv(SFC_IO_SOURCE_MODE = old)",
    "  }, add = TRUE)",
    "  source(path)",
    "}",
    "",
    "script_dir <- get_script_dir()",
    "repo_root <- normalizePath(file.path(script_dir, '..'), mustWork = FALSE)",
    "setwd(repo_root)",
    source_lines,
    "",
    fn_code,
    "main <- function() {",
    indent_lines(main_code, 2),
    "}",
    "",
    "if (!interactive() && Sys.getenv('SFC_IO_SOURCE_MODE', '0') != '1') {",
    "  main()",
    "}"
  )

  writeLines(lines, out_file)
}

if (flags$generate_r) {
  ensure_dirs()

  if (!requireNamespace("knitr", quietly = TRUE)) {
    stop("Package 'knitr' is required for --generate-r.", call. = FALSE)
  }

  message("Generating combined R script...")
  knitr::purl(qmd_file, output = combined_r_file, documentation = 0)
  message("Wrote: ", combined_r_file)
}

if (flags$generate_step_r) {
  ensure_dirs()

  message("Generating per-step R scripts...")
  qmd_lines <- readLines(qmd_file, warn = FALSE)
  chunks <- extract_r_chunks(qmd_lines)

  shared_chunks <- Filter(function(ch) identical(ch$step, "shared"), chunks)
  write_setup_script(shared_chunks, setup_file)

  step_map <- c(
    step01 = "step01_sim.R",
    step02 = "step02_iot_exogenous.R",
    step03 = "step03_sim_iot_endogenous.R",
    step04 = "step04_row_lite.R",
    step05 = "step05_aea_emissions.R"
  )

  step_ids <- names(step_map)
  for (i in seq_along(step_ids)) {
    sid <- step_ids[i]
    step_chunks <- Filter(function(ch) identical(ch$step, sid), chunks)

    function_chunks <- Filter(function(ch) grepl("functions", ch$label, ignore.case = TRUE), step_chunks)
    main_chunks <- Filter(function(ch) !grepl("functions", ch$label, ignore.case = TRUE), step_chunks)

    prior_files <- if (i == 1) character() else unname(step_map[seq_len(i - 1)])
    out_file <- file.path(r_dir, step_map[[sid]])

    write_step_script(
      function_chunks = function_chunks,
      main_chunks = main_chunks,
      out_file = out_file,
      prior_files = prior_files,
      setup_basename = basename(setup_file)
    )

    message("Wrote: ", out_file)
  }

  message("Wrote: ", setup_file)
}

if (flags$render_html) {
  message("Rendering HTML notebook...")
  must_succeed("quarto", c("render", qmd_file, "--to", "html", "--output", html_out))
  message("Wrote: ", html_out)
}

if (flags$render_slides) {
  message("Rendering revealjs slides...")
  slide_args <- c("render", qmd_file, "--to", "revealjs", "--output", slides_out)
  first_try <- run_cmd("quarto", slide_args)

  if (!first_try$ok) {
    message("Reveal render failed once; retrying with temporary HOME...")
    temp_home <- tempfile("quarto-home-")
    dir.create(temp_home, recursive = TRUE, showWarnings = FALSE)

    r_lib_user <- Sys.getenv("R_LIBS_USER", unset = "")
    env <- c(paste0("HOME=", temp_home))
    if (nzchar(r_lib_user)) env <- c(env, paste0("R_LIBS_USER=", r_lib_user))

    must_succeed("quarto", slide_args, env = env)
  }

  message("Wrote: ", slides_out)
}

message("Done.")
