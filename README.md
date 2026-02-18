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
3. Generate derived participant files (default):
   `Rscript build_tutorial.R --generate-question-steps --generate-r-steps-question`
4. Optional instructor export (not default):
   `Rscript build_tutorial.R --generate-r-steps-answer`
5. Choose workflow:
   - Run step `.qmd` files directly in RStudio (you can run chunks interactively and/or click **Render**).
   - Run generated participant `.R` step scripts directly, e.g. `R/step01_question.R` … `R/step06_question.R`

## Build/Sync commands

- Generate question step QMDs:
  `Rscript build_tutorial.R --generate-question-steps`
- Check question sync against canonical:
  `Rscript build_tutorial.R --check-step-sync`
- Render notebook HTML:
  `Rscript build_tutorial.R --render-html`
- Render revealjs slides:
  `Rscript build_tutorial.R --render-slides`

## Notes

- Data handling in tutorial code is cache-first, then download, then fail.
- CI (`.github/workflows/tutorial-sync.yml`) verifies `tutorial_sfc-io-question.qmd` stays synchronized with the canonical answer source.
