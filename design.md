## SFC-IO tutorial design document
This is the design document for a 30 min tutorial introducing Stock Flow Consistent (SFC) modelling with production sector based on an Input-Output Table (IOT), exogenous and endogenous energy transition and CO2 emissions computations.

## Single source .qmd, and its derivatives

We start only with R code until the repo is fully refactored as per this design doc.
Only after that we'll try to add in Python. So for now, the Python information below is to be ignored.

All R code is generated in folder R/, all python code in Python/, and all downloaded data in data/

We have a single authored source, tutorial_sfc-io.qmd (answer version), that build_tutorial.R uses to create html, Reveal.js slides, and generated tutorial files. A participant question version is generated from this source and kept in sync.

The .qmd should specify sections and slides in a user-friendly way, so that the presenter / user can modify and/or add slides or the text on slides.

.qmd file should itself be runnable (both R and Python code) via, say, GitHub Codespaces, etc.

Generated files should match the .qmd code and output when run independently by the user.

For a slide-show tutorial, html and Reveal.js files are created as single standalone files to present so that we do not have file bloat. R code and Python code are displayed side by side in the html and slides and .qmd, or below each other if not easy or not readable. Points, equations and derivations from the slides are included as comments into R and Python files.

## Progressive steps:

We want the following progressive steps in the tutorial. Each is a separate section of the tutorial. These are all part of one .qmd file, but create separate R and Python files for each section. Earlier section files use functions, so that we can source earlier files' functions in the current file to emphasize code reuse and avoid duplication and divergence (if needed). 
For R files we have a main function, with  `if (!interactive()) {  main() }`, so that `source`-ing the file into a later step/section won't run the code and plots already explored/seen in the previous step.

- Introduce and simulate a closed minimal SFC model: SIM (simple) model from Godley and Lavoie book
    - Derive steady state equation for GDP
    - SIM-lag: Use behavioural equations that only depend on previous time step values. Plot GDP from initial value higher and lower than steady state, versus time - 20 years with yearly time step, to see if it reaches the steady state value.
    - SIM-current: Have a switch to instead run fixed point iteration to satisfy behavioural consistency with behavioural equations that depend on current time step values (e.g. consumption from current income and from previous wealth), and compare the simulations in the fixed point iteration case with those above in a similar plot.

- Step 2 core: Incorporate IOT as production sector into SIM model and fit baseline
    - Load IOT and use it as production sector
    - Fit SIM-side parameters to base-year macro values
    - Simulate the fitted model for 20 years with transition speed set to zero

- Step 3 core: Apply endogenous transition on top of Step 2 baseline
    - Activate endogenous brown-to-green demand-share shifts
    - Compare transition path to Step 2 no-transition baseline

- Step 4 core: Add a minimal Rest of the World (RoW) sector and treat imports and exports consistently
    - Point out that imports for production are already embedded in Z part of the IOT (total instead of domestic chosen earlier) - these are imports for use by industry
    - Point out that domestic consumption imports are different, and we should be careful to use domestic technology for them! How would MRIO handle this compared to just using national IOT? Outline using equations, but not in the simulation.
    - Point out that exports can be largely attributed to domestic technology and included in final demand.

- Step 5 advanced/optional: Loading IOT and simulate exogenous energy transition
    - Allow user to specify the IOT specs at the start: default is Austria 2020 product x product (since industry x industry is not available for 2020), total (not just domestic) flows
    - Load Symmetric IO Table for above selection, use a caching method, if the file is not found locally in current folder, then download it.
    - For starting values of NACE's 2 energy sectors (I think 19 coal, petroleum et al and 35 electricity, gas and heating), set final values after 20 years for an energy transition, compute a growth rate for each sector. Set also a growth rate for the total GDP.
    - In the fixed point loop, compute also the domestic demand and A matrix consistent with the closure.
    - Simulate here too for 20 time steps.

- Step 6 advanced/optional: Download Eurostat AEA emissions by NACE to compute direct CO2 emissions by industry
    - Here we use a different country than Austria, say Germany or Belgium for which industry x industry emissions are available, since CO2 emissions are available industry x industry.
    - For this new set, the fitting of the model parameters as per earlier steps, is of course redone.
    - Use intensities to project these emissions of production for domestic demand for the next 20 years under the status quo and the energy transition
    - Point out that these are emissions from production, while those from consumption are extra. Can we use emissions intensities of households to estimate those as well, assuming other domestic consumption is similar to households? Outline using equations, but not in the simulation.

## Exercise / Play Design (economics focus)

Each step should have one core play and one optional play, framed as an economic question rather than a coding exercise.

- Step 1 (SIM):
  - Core play: compare convergence when initial GDP starts below versus above steady state.
  - Optional play: change consumption out of wealth and discuss effects on convergence speed and stability.
- Step 2 (SIM + IOT baseline fit, core):
  - Core play: adjust government growth or tax assumptions and compare the no-transition baseline path.
  - Optional play: change household propensity to consume from wealth and inspect baseline wealth/GDP dynamics.
- Step 3 (endogenous transition, core):
  - Core play: change endogenous transition pressure/speed and compare macro path and sector reallocation.
  - Optional play: vary household propensity to consume from wealth under transition and discuss growth versus wealth-depletion trade-offs.
- Step 4 (RoW-lite, core):
  - Core play: change import leakage and compare GDP and trade-balance dynamics.
  - Optional play: change export growth and compare external-demand-led versus domestic-demand-led growth paths.
- Step 5 (IOT + exogenous transition, advanced/optional):
  - Core play: switch closure assumption and compare which sectors absorb adjustment under the same aggregate growth target.
  - Optional play: strengthen or relax green-versus-brown transition assumptions and compare sector mix and GDP composition.
- Step 6 (production emissions, advanced/optional):
  - Core play: compare baseline and transition CO2 paths and interpret production-based emissions.
  - Optional play: add exogenous intensity decline and separate activity effects from intensity effects.

Question variant generation principle:
- The answer `.qmd` remains canonical.
- Question prompts and default student values are authored inline in that file via exercise metadata.
- The question `.qmd` is generated automatically from canonical and checked in CI for sync.

## Non-negotiable Code Structure

1. `shared_setup` in `.qmd` must be very minimal and contain only:
   - library checks/imports
   - global options
   - only universal setup variables (no step-specific setup that belongs in later sections)
   No data loaders, no model equations, no simulation functions.

2. Each step file contains what it needs and should import / source the previous step files' functions as needed, with main() function specifying what is run in that step and not used in following steps. 

3. Each generated step file in `R/` (answer and question variants) must include:
   - `main()`
   - `if (!interactive()) main()`
   - `source()` for required previous step files and/or shared utils.

4. Step ownership is strict:
   - Step 1 file defines only SIM functions.
   - Step 2 file defines SIM+IOT baseline-fit functions (including shared IO setup used by core flow).
   - Step 3 file defines endogenous-transition functions using the Step 2 fitted model.
   - Step 4 file defines only RoW-lite functions.
   - Step 5 file defines only IOT/closure exogenous-transition functions (advanced section).
   - Step 6 file defines only emissions functions.

## Slide and Code Size Constraints

1. One conceptual action per slide.
2. Code shown on a slide must be <= 20 lines.
3. If logic is longer, move it to a step `.R` function and show the call in that slide, with brief explanation / comment of function.
4. Have slide(s) after the above calling slide that go over the code of this function, breaking it up into multiple slides if necessary.
5. Every step section in `.qmd` must follow:
   - Objective slide
   - Equations slide
   - Easily digestible code-call slide(s)
   - Output/plot slide
   - Play slide that specifies what parameters to play with
   - Interpretation slide

## Workshop Delivery Infrastructure

The tutorial must run reliably through three paths:

1. Binder (primary online path, RStudio in browser)
2. Local RStudio (no `renv` in this phase)
3. Pre-rendered static HTML via GitHub Pages

### Non-negotiable constraints

1. `tutorial_sfc-io.qmd` remains the only authored tutorial logic source.
2. Generated files in `R/` are derived artifacts only.
3. No hidden tutorial logic in standalone `.R` modules outside generated outputs.
4. Keep setup minimal and reliable; avoid optional tooling unless required.

### Reproducibility and startup policy

1. Binder config should be minimal and prioritize startup reliability over sophistication.
2. Keep dependency footprint small to reduce Binder build timeouts.

### CI/Publishing policy

1. GitHub Actions renders `tutorial_sfc-io.qmd` to HTML on push to `main`.
2. Publish static output to GitHub Pages as no-fail viewing fallback.
3. Render must work from repository root with stable relative paths.
4. CI checks that generated question materials remain synchronized with the canonical answer source (no CI auto-commit).

### Acceptance criteria

1. Clean clone + install required packages + render works locally.
2. Binder launches RStudio and can run/render tutorial without manual environment repair.
3. GitHub Pages always serves latest rendered tutorial.
4. All three paths are documented in README with troubleshooting notes.
5. Question and answer variants are synchronized in CI.
