#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

qmd_file <- "tutorial_sfc-io.qmd"
combined_r_file <- "tutorial_sfc-io.R"
html_out <- "tutorial_sfc-io-notebook.html"
slides_out <- "tutorial_sfc-io-slides.html"
steps_dir <- "r_steps"
shared_file <- file.path(steps_dir, "shared_utils.R")

if (!file.exists(qmd_file)) {
  stop("Missing file: ", qmd_file, call. = FALSE)
}

show_help <- function() {
  cat(
    "Usage: Rscript build_tutorial.R [flags]\n\n",
    "Flags:\n",
    "  --generate-r         Generate combined tutorial_sfc-io.R from tutorial_sfc-io.qmd\n",
    "  --generate-step-r    Generate per-step scripts in r_steps/\n",
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

extract_r_chunks_by_step <- function(lines) {
  step_ids <- sprintf("step%02d", 1:5)
  out <- c(list(shared = character()), stats::setNames(vector("list", length(step_ids)), step_ids))

  current_step <- "shared"
  in_chunk <- FALSE
  chunk_buffer <- character()

  flush_chunk <- function() {
    if (length(chunk_buffer) == 0) return(invisible(NULL))
    code <- chunk_buffer[!grepl("^\\s*#\\|", chunk_buffer)]
    if (length(code) > 0) {
      out[[current_step]] <<- c(out[[current_step]], code, "")
    }
    invisible(NULL)
  }

  for (ln in lines) {
    if (!in_chunk) {
      m <- regmatches(ln, regexec("^##\\s+Step\\s+([0-9]+)\\b", ln))[[1]]
      if (length(m) == 2) {
        sid <- sprintf("step%02d", as.integer(m[2]))
        if (sid %in% names(out)) current_step <- sid
      }

      if (grepl("^```\\{r[^}]*\\}\\s*$", ln)) {
        in_chunk <- TRUE
        chunk_buffer <- character()
      }
    } else {
      if (grepl("^```\\s*$", ln)) {
        flush_chunk()
        in_chunk <- FALSE
        chunk_buffer <- character()
      } else {
        chunk_buffer <- c(chunk_buffer, ln)
      }
    }
  }

  out
}

indent_lines <- function(x, spaces = 2) {
  pad <- paste(rep(" ", spaces), collapse = "")
  ifelse(nzchar(x), paste0(pad, x), "")
}

write_shared_utils <- function(shared_code, out_file) {
  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
  lines <- c(
    "#!/usr/bin/env Rscript",
    "# Generated from tutorial_sfc-io.qmd. Do not edit by hand.",
    "",
    shared_code
  )
  writeLines(lines, out_file)
}

write_step_script <- function(step_code, out_file) {
  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)

  body <- if (length(step_code) == 0) {
    c("message('No code extracted for this step.')")
  } else {
    step_code
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
    "script_dir <- get_script_dir()",
    "repo_root <- normalizePath(file.path(script_dir, '..'), mustWork = FALSE)",
    "setwd(repo_root)",
    "source(file.path(script_dir, 'shared_utils.R'))",
    "",
    "main <- function() {",
    indent_lines(body, 2),
    "}",
    "",
    "if (!interactive()) {",
    "  main()",
    "}"
  )

  writeLines(lines, out_file)
}

if (flags$generate_r) {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    stop("Package 'knitr' is required for --generate-r.", call. = FALSE)
  }

  message("Generating combined R script...")
  knitr::purl(qmd_file, output = combined_r_file, documentation = 0)
  message("Wrote: ", combined_r_file)
}

if (flags$generate_step_r) {
  message("Generating per-step R scripts...")
  qmd_lines <- readLines(qmd_file, warn = FALSE)
  sections <- extract_r_chunks_by_step(qmd_lines)

  write_shared_utils(sections$shared, shared_file)

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
    # Cumulative step scripts: each step includes code from prior steps.
    step_body <- unlist(sections[step_ids[seq_len(i)]], use.names = FALSE)
    write_step_script(step_body, file.path(steps_dir, step_map[[sid]]))
    message("Wrote: ", file.path(steps_dir, step_map[[sid]]))
  }

  message("Wrote: ", shared_file)
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
