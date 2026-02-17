The 30 min tutorial introduce Stock Flow Consistent (SFC) modelling with production sector based on an Input-Output Table (IOT)

We start only with R code until the repo is fully refactored as per this design doc.
Only after that we'll try to add in Python. So for now, the Python information below is to be ignored.

All R code is generated in folder R/ , all python code in Python/, and all downloaded data in data/

We have a single source, a quarto file tutorial_sfc-io.qmd that build_tutorial.R uses to create html, reveal.js slides, and R and Python code for the tutorial.

The .qmd should specify sections and slides in a user-friendly way, so that the presenter / user can modify and/or add slides or the text on slides.

.qmd file should itself be runnable (both R and Python code) via say github codespace, etc.

R and Python files created as above should match exactly the .qmd code and output when run independently by the user.

For a slide-show tutorial, html and Reveal.js files are created as single standalone files to present so we that don't have file bloat. R code and Python code are displayed side by side in the html and slides and .qmd, or below each other if not easy or not readable. Points, equations and derivations from the slides are included as comments into R and Python files.

We want the following progressive steps in the tutorial. Each is a separate section of the tutorial. These are all part of one .qmd file, but create separate R and Python files for each section. Earlier section files use functions, so that we can source earlier files' functions in the current file to emphasize code reuse and avoid duplication and divergence (if needed). 
For R files we have a main function, with  `if (!interactive()) {  main() }`, so that `source`-ing the file into a later step/section won't run the code and plots already explored/seen in the previous step.

- Introduce and simulate a closed minimal SFC model: SIM (simple) model from Godley and Lavoie book
    - Derive steady state equation for GDP
    - SIM-lag: Use behavioural equations that only depend on previous time step values. Plot GDP from initial value higher and lower than steady state, versus time - 20 years with yearly time step, to see if it reaches the steady state value.
    - SIM-current: Have a switch to instead run fixed point iteration to satisfy behavioural consistency with behavioural equations that depend on current time step values (e.g. consumption from current income and from previous wealth), and compare the simulations in the fixed point iteration case with those above in a similar plot.

- Loading IOT and simulate exogeneous energy transition
    - Allow user to specify the IOT specs at the start: default is Austria 2020 product x product (since idustry x industry is not avalable for 2020), total (not just domestic) flows
    - Load Symmetric IO Table for above selection, use a caching method, if the file is not found locally in current folder, then download it.
    - For starting values of NACE's 2 energy sectors (I think 19 coal, petroleum et al and 35 electricity, gas and heating), set final values after 20 years for an anergy transition, compute a growth rate for each sector. Set also a growth rate for the total GDP.
    - In the fixed point loop, compute also the domestic demand and A matrix consistent with the closure.
    - Simulate here too for 20 time steps.

- Incorporate IOT as production sector into SIM model
    - Load IOT, and use it as production sector
    - Fit other parameters of the SIM model to match the GDP etc.
    - Simulate the model for 20 years.
    - Incorporate an energy transition and simulate endogenously roughly similar to the above but without forcing consistency with the closure

- Add a minimal Rest of the World (RoW) sector and treat imports and exports consistently.
    - Point out that imports for production are already embedded in Z part of the IOT (total instead of domestic chosen earlier) - these are imports for use by industry
    - Point out that domestic consumption imports are different, and we should be careful to use domestic technology for them! How would MRIO handle this compared to just using national IOT? Outline using equations, but not in the simulation.
    - Point out that exports can be largely attributed to domestic technology and included in final demand.

- Download with caching the Eurostat AEA emissions by NACE to compute direct CO2 emissions by industry
    - Here we use a different country than Austria, say Germany or Belgium for which industry x industry emissions are availble, since CO2 emissions are available industry x industry.
    - For this new set, the fitting of the model parameters as per earlier steps, is of course redone.
    - Use intensities to project these emissions of production for domestic demand for the next 20 years under the status quo and the energy transition
    - Point out that these are emissions from production, while those from consumption are extra. Can we use emissions intensities of households to estimate those as well, assuming other domestic consumption is similar to households? Outline using equations, but not in the simulation.

## Non-negotiable Code Structure

1. `shared_setup` in `.qmd` must be very minimal and contain only:
   - library checks/imports
   - global options
   - top-level config variables
   No data loaders, no model equations, no simulation functions.

2. Each step file contains what it needs and should import / source the previous step files' functions as needed, with main() function specifying what is run in that step and not used in following steps. 

3. Each `R/step0X_*.R` must include:
   - `main()`
   - `if (!interactive()) main()`
   - `source()` for required previous step files and/or shared utils.

4. Step ownership is strict:
   - Step 1 file defines only SIM functions.
   - Step 2 file defines only IOT/closure functions.
   - Step 3 file defines only SIM+IOT integration functions.
   - Step 4 file defines only RoW-lite functions.
   - Step 5 file defines only emissions functions.

## Slide and Code Size Constraints

1. One conceptual action per slide.
2. Code shown on a slide must be <= 20 lines.
3. If logic is longer, move it to a step `.R` function and show the call in that slide, with brief explanation / comment of function.
4. Have slide(s) after the above calling slide that go over the code of this function, breaking it up into multiple slides if necessary.
4. Every step section in `.qmd` must follow:
   - Objective slide
   - Equations slide
   - Easily digestible code-call slide(s)
   - Output/plot slide
   - Play slide that specifies what parameters to play with
   - Interpretation slide
