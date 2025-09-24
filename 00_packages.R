# 00_packages.R
# Install (if needed) and load packages used across the pipeline.

packages <- c(
  "tidyverse", "readxl", "janitor", "metafor", "lme4", "broom.mixed",
  "openxlsx", "sf", "tmap", "countrycode", "glue", "here", "officer", "flextable", "rmarkdown"
)

installed <- rownames(installed.packages())
for(p in packages){
  if(! p %in% installed ){
    install.packages(p, repos = "https://cloud.r-project.org")
  }
}
# load
invisible(lapply(packages, library, character.only = TRUE))
