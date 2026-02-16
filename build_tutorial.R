#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

qmd_file <- "tutorial_sfc-io.qmd"
r_file <- "tutorial_sfc-io.R"
html_out <- "tutorial_sfc-io-notebook.html"
reveal_out <- "tutorial_sfc-io-slides.html"

if (!file.exists(qmd_file)) {
  stop("Missing file: ", qmd_file, call. = FALSE)
}

if (!requireNamespace("knitr", quietly = TRUE)) {
  stop("Package 'knitr' is required. Install with install.packages('knitr').", call. = FALSE)
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

message("Generating standalone R script from QMD...")
knitr::purl(qmd_file, output = r_file, documentation = 0)
message("Wrote: ", r_file)

purl_only <- "--purl-only" %in% args
render_reveal <- "--reveal" %in% args
render_html <- !purl_only

if (render_html) {
  message("Rendering html notebook...")
  must_succeed("quarto", c("render", qmd_file, "--to", "html", "--output", html_out))
  message("Wrote: ", html_out)
}

if (render_reveal) {
  message("Rendering revealjs slides...")
  reveal_args <- c("render", qmd_file, "--to", "revealjs", "--output", reveal_out)
  reveal_try <- run_cmd("quarto", reveal_args)

  if (!reveal_try$ok) {
    message("Reveal render failed once; retrying with temporary HOME...")
    temp_home <- tempfile("quarto-home-")
    dir.create(temp_home, recursive = TRUE, showWarnings = FALSE)

    r_lib_user <- Sys.getenv("R_LIBS_USER", unset = "")
    env <- c(paste0("HOME=", temp_home))
    if (nzchar(r_lib_user)) {
      env <- c(env, paste0("R_LIBS_USER=", r_lib_user))
    }

    must_succeed("quarto", reveal_args, env = env)
  }
  message("Wrote: ", reveal_out)
}

message("Done.")
