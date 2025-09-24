# run_all.R
# Wrapper to run the pipeline

# Optionally set working directory to package root before sourcing
source("00_packages.R")
source("01_data_prep_and_crude.R")
source("02_model_and_predictions.R")
source("03_maps_and_figures.R")
message("Pipeline complete. Check results/ for outputs.")
