# tutorial_sfc-io

Canonical tutorial source: `tutorial_sfc-io.qmd` (answer version).

Generated teaching variant committed in repo: `tutorial_sfc-io-question.qmd`.

## Run the tutorial

### Option 1: Binder (recommended)

[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/EcolEconModels/tutorial_sfc-io/HEAD?urlpath=rstudio)

1. Open Binder.
2. Wait for RStudio to start.
3. Open `tutorial_sfc-io.qmd` (answer) or `tutorial_sfc-io-question.qmd` (participant version).
4. Run chunks or render from RStudio.

### Option 2: Static HTML (GitHub Pages)

- https://ecoleconmodels.github.io/tutorial_sfc-io/

### Option 3: Local (RStudio)

1. Open this repo in RStudio.
2. Install required packages once if needed:
   `install.packages(c("jsonlite", "ggplot2", "knitr", "quarto"))`
3. Generate derived files:
   `Rscript build_tutorial.R --generate-question-qmd --generate-r-answer --generate-r-question`
4. Choose workflow:
   - Run `.qmd` directly in RStudio (you can run cells interactively and/or click **Render**).
   - Run generated `.R` scripts directly, e.g.:
     - `R/tutorial_sfc-io-answer.R`
     - `R/tutorial_sfc-io-question.R`
     - `R/tutorial_sfc-io-answer_step01.R` … `R/tutorial_sfc-io-answer_step05.R`
     - `R/tutorial_sfc-io-question_step01.R` … `R/tutorial_sfc-io-question_step05.R`

## Build/Sync commands

- Generate question QMD only:
  `Rscript build_tutorial.R --generate-question-qmd`
- Check question sync against canonical:
  `Rscript build_tutorial.R --check-question-sync`
- Render notebook HTML:
  `Rscript build_tutorial.R --render-html`
- Render revealjs slides:
  `Rscript build_tutorial.R --render-slides`

## Notes

- Data handling in tutorial code is cache-first, then download, then fail.
- CI (`.github/workflows/tutorial-sync.yml`) verifies `tutorial_sfc-io-question.qmd` stays synchronized with the canonical answer source.
