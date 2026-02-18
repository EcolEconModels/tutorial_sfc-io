#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

canonical_qmd <- "tutorial_sfc-io.qmd"
question_qmd <- "tutorial_sfc-io-question.qmd"
html_out <- "tutorial_sfc-io-notebook.html"
slides_out <- "tutorial_sfc-io-slides.html"
output_r_dir <- "R"

if (!file.exists(canonical_qmd)) {
  stop("Missing file: ", canonical_qmd, call. = FALSE)
}

show_help <- function() {
  cat(
    "Usage: Rscript build_tutorial.R [flags]\n\n",
    "Flags:\n",
    "  --generate-question-qmd  Generate tutorial_sfc-io-question.qmd from canonical answer QMD\n",
    "  --generate-r-answer      Generate answer R scripts in R/ folder\n",
    "  --generate-r-question    Generate question R scripts in R/ folder\n",
    "  --check-question-sync    Regenerate question QMD and fail if git diff is non-empty\n",
    "  --render-html            Render canonical QMD to HTML\n",
    "  --render-slides          Render canonical QMD to revealjs slides\n",
    "  --help                   Show this help\n",
    sep = ""
  )
}

if ("--help" %in% args) {
  show_help()
  quit(save = "no", status = 0)
}

flags <- list(
  generate_question_qmd = "--generate-question-qmd" %in% args,
  generate_r_answer = "--generate-r-answer" %in% args || "--generate-r" %in% args || "--generate-step-r" %in% args,
  generate_r_question = "--generate-r-question" %in% args,
  check_question_sync = "--check-question-sync" %in% args,
  render_html = "--render-html" %in% args,
  render_slides = "--render-slides" %in% args
)

if (!any(unlist(flags))) {
  message("No flags supplied; defaulting to --generate-question-qmd --generate-r-answer --generate-r-question")
  flags$generate_question_qmd <- TRUE
  flags$generate_r_answer <- TRUE
  flags$generate_r_question <- TRUE
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
    if (length(kv) < 2) {
      stop("Malformed @exercise metadata at line ", line_no, ": ", part, call. = FALSE)
    }
    key <- trimws(kv[1])
    val <- trimws(paste(kv[-1], collapse = "="))
    out[[key]] <- trim_quotes(val)
  }

  required <- c("id", "kind", "question_expr", "prompt")
  missing <- required[!vapply(required, function(k) !is.null(out[[k]]) && nzchar(out[[k]]), logical(1))]
  if (length(missing) > 0) {
    stop("Missing required @exercise key(s) at line ", line_no, ": ", paste(missing, collapse = ", "), call. = FALSE)
  }

  if (!(out$kind %in% c("core", "optional"))) {
    stop("Invalid @exercise kind at line ", line_no, ": ", out$kind, call. = FALSE)
  }

  tryCatch(parse(text = out$question_expr), error = function(e) {
    stop("Invalid question_expr at line ", line_no, ": ", out$question_expr, call. = FALSE)
  })

  out
}

generate_question_lines <- function(lines) {
  seen_ids <- character(0)
  out <- lines

  for (i in seq_along(lines)) {
    ln <- lines[[i]]
    if (!grepl("@exercise\\[", ln)) next

    m <- regmatches(ln, regexec("^(\\s*[A-Za-z][A-Za-z0-9._]*\\s*<-\\s*)([^#]+?)(\\s*)#\\s*@exercise\\[(.*)\\]\\s*$", ln, perl = TRUE))[[1]]
    if (length(m) != 5) {
      stop("@exercise annotation must be on a single assignment line (line ", i, ").", call. = FALSE)
    }

    prefix <- m[2]
    meta_str <- m[5]
    meta <- parse_exercise_meta(meta_str, i)

    if (meta$id %in% seen_ids) {
      stop("Duplicate @exercise id found: ", meta$id, " (line ", i, ").", call. = FALSE)
    }
    seen_ids <- c(seen_ids, meta$id)

    hint_txt <- if (!is.null(meta$hint) && nzchar(meta$hint)) paste0(" Hint: ", meta$hint) else ""
    todo <- paste0("# TODO [", meta$kind, ":", meta$id, "] ", meta$prompt, hint_txt)

    out[[i]] <- paste0(prefix, meta$question_expr, "  ", todo)
  }

  out
}

generate_question_qmd <- function(in_file = canonical_qmd, out_file = question_qmd) {
  lines <- readLines(in_file, warn = FALSE)
  q_lines <- generate_question_lines(lines)
  writeLines(q_lines, out_file)
  invisible(out_file)
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
    chunks[[length(chunks) + 1L]] <<- list(step = current_step, label = chunk_label, code = code)
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
        if (!nzchar(label)) label <- sprintf("chunk_%03d", chunk_counter)
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
  for (ch in chunk_list) out <- c(out, ch$code, "")
  out
}

indent_lines <- function(x, spaces = 2) {
  pad <- paste(rep(" ", spaces), collapse = "")
  ifelse(nzchar(x), paste0(pad, x), "")
}

write_setup_script <- function(shared_chunks, out_file, src_qmd) {
  code <- collapse_chunks(shared_chunks)
  lines <- c(
    "#!/usr/bin/env Rscript",
    paste0("# Generated from ", src_qmd, ". Do not edit by hand."),
    "",
    code
  )
  writeLines(lines, out_file)
}

write_step_script <- function(function_chunks, main_chunks, out_file, prior_files, setup_file, src_qmd) {
  fn_code <- collapse_chunks(function_chunks)
  main_code <- collapse_chunks(main_chunks)
  if (length(main_code) == 0) main_code <- c("message('No executable code extracted for this step.')")

  source_lines <- c(sprintf("source(file.path(script_dir, '%s'))", setup_file))
  if (length(prior_files) > 0) {
    src_prev <- sprintf("source_sfc_step(file.path(script_dir, '%s'))", prior_files)
    source_lines <- c(source_lines, src_prev)
  }

  lines <- c(
    "#!/usr/bin/env Rscript",
    paste0("# Generated from ", src_qmd, ". Do not edit by hand."),
    "",
    "get_script_dir <- function() {",
    "  full_args <- commandArgs(trailingOnly = FALSE)",
    "  file_arg <- grep('^--file=', full_args, value = TRUE)",
    "  if (length(file_arg) > 0) return(dirname(normalizePath(sub('^--file=', '', file_arg[1]), mustWork = FALSE)))",
    "  getwd()",
    "}",
    "",
    "source_sfc_step <- function(path) {",
    "  old <- Sys.getenv('SFC_IO_SOURCE_MODE', unset = NA_character_)",
    "  Sys.setenv(SFC_IO_SOURCE_MODE = '1')",
    "  on.exit({ if (is.na(old)) Sys.unsetenv('SFC_IO_SOURCE_MODE') else Sys.setenv(SFC_IO_SOURCE_MODE = old) }, add = TRUE)",
    "  source(path)",
    "}",
    "",
    "script_dir <- get_script_dir()",
    "setwd(script_dir)",
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

generate_r_variant <- function(src_qmd, prefix) {
  if (!file.exists(src_qmd)) stop("Missing QMD for R generation: ", src_qmd, call. = FALSE)
  if (!requireNamespace("knitr", quietly = TRUE)) stop("Package 'knitr' is required for R generation.", call. = FALSE)
  if (!dir.exists(output_r_dir)) dir.create(output_r_dir, recursive = TRUE)

  combined_file <- file.path(output_r_dir, paste0(prefix, ".R"))
  message("Generating combined R script: ", combined_file)
  knitr::purl(src_qmd, output = combined_file, documentation = 0)

  qmd_lines <- readLines(src_qmd, warn = FALSE)
  chunks <- extract_r_chunks(qmd_lines)

  setup_file <- file.path(output_r_dir, paste0(prefix, "_step00_setup.R"))
  shared_chunks <- Filter(function(ch) identical(ch$step, "shared"), chunks)
  write_setup_script(shared_chunks, setup_file, src_qmd)

  step_ids <- sprintf("step%02d", 1:5)
  step_files <- file.path(output_r_dir, paste0(prefix, "_", step_ids, ".R"))

  for (i in seq_along(step_ids)) {
    sid <- step_ids[i]
    step_chunks <- Filter(function(ch) identical(ch$step, sid), chunks)
    function_chunks <- Filter(function(ch) grepl("functions", ch$label, ignore.case = TRUE), step_chunks)
    main_chunks <- Filter(function(ch) !grepl("functions", ch$label, ignore.case = TRUE), step_chunks)
    prior_files <- if (i == 1) character() else basename(step_files[seq_len(i - 1)])

    write_step_script(
      function_chunks = function_chunks,
      main_chunks = main_chunks,
      out_file = step_files[i],
      prior_files = prior_files,
      setup_file = basename(setup_file),
      src_qmd = src_qmd
    )
    message("Wrote: ", step_files[i])
  }

  message("Wrote: ", setup_file)
  message("Wrote: ", combined_file)
}

if (flags$generate_question_qmd) {
  message("Generating question QMD...")
  generate_question_qmd(canonical_qmd, question_qmd)
  message("Wrote: ", question_qmd)
}

if (flags$generate_r_answer) {
  generate_r_variant(canonical_qmd, "tutorial_sfc-io-answer")
}

if (flags$generate_r_question) {
  if (!file.exists(question_qmd)) {
    message("Question QMD missing; generating first...")
    generate_question_qmd(canonical_qmd, question_qmd)
  }
  generate_r_variant(question_qmd, "tutorial_sfc-io-question")
}

if (flags$check_question_sync) {
  generate_question_qmd(canonical_qmd, question_qmd)
  status <- system2("git", c("diff", "--exit-code", "--", question_qmd), stdout = FALSE, stderr = FALSE)
  if (!identical(status, 0L)) {
    stop(question_qmd, " is out of sync with ", canonical_qmd, ". Regenerate and commit.", call. = FALSE)
  }
  message("Question QMD is in sync.")
}

if (flags$render_html) {
  message("Rendering HTML notebook...")
  must_succeed("quarto", c("render", canonical_qmd, "--to", "html", "--output", html_out))
  message("Wrote: ", html_out)
}

if (flags$render_slides) {
  message("Rendering revealjs slides...")
  slide_args <- c("render", canonical_qmd, "--to", "revealjs", "--output", slides_out)
  first_try <- run_cmd("quarto", slide_args)
  if (!first_try$ok) {
    message("Reveal render failed once; retrying with temporary HOME...")
    temp_home <- tempfile("quarto-home-")
    dir.create(temp_home, recursive = TRUE, showWarnings = FALSE)
    env <- c(paste0("HOME=", temp_home))
    must_succeed("quarto", slide_args, env = env)
  }
  message("Wrote: ", slides_out)
}

message("Done.")
