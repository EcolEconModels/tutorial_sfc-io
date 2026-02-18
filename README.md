# tutorial_sfc-io

Minimal SFC-IO tutorial in Quarto (`tutorial_sfc-io.qmd`).

## Run the tutorial

### Option 1: Binder (recommended)

[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/EcolEconModels/tutorial_sfc-io/HEAD?urlpath=rstudio)

1. Open the Binder link.
2. Wait for RStudio to start.
3. Open `tutorial_sfc-io.qmd` and run R chunks directly in RStudio.

### Option 2: Static HTML (GitHub Pages)

- https://ecoleconmodels.github.io/tutorial_sfc-io/

### Option 3: Local (RStudio)

If R + Quarto are already installed:

1. Open the repo in RStudio.
2. Install required packages once (if needed):
   `install.packages(c("jsonlite", "ggplot2", "knitr", "quarto"))`
3. Generate derived R files from the canonical `.qmd`:
   `Rscript build_tutorial.R --generate-r --generate-step-r`
4. Choose one workflow:
   - Run `.qmd` directly: open `tutorial_sfc-io.qmd` and run R chunks in RStudio (or click **Render**).
   - Run generated `.R` scripts: open and run `R/tutorial_sfc-io.R` or any step file such as `R/step02_iot_exogenous.R`.

## Notes

- Data logic is cache-first, then download, then fail (defined in `tutorial_sfc-io.qmd`).
- First Binder launch may take a few minutes.
