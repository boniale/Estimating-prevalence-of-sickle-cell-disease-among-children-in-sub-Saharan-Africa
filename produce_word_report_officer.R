# produce_word_report_officer.R
# Produce a Word report using officer and flextable. Assumes results exist.

source("00_packages.R")
library(officer); library(flextable); library(openxlsx); library(glue)

proj_root <- here::here("..")
results_dir <- file.path(proj_root, "results")

country_file <- file.path(results_dir, "country_predictions_prevalence_and_cases.xlsx")
pooled_file  <- file.path(results_dir, "pooled_crude_prevalence_by_age_subtype.xlsx")
region_file  <- file.path(results_dir, "regional_aggregates.xlsx")

if(!file.exists(country_file)) stop("country predictions file missing. Run pipeline first.")

country_df <- readxl::read_excel(country_file)
pooled_df  <- readxl::read_excel(pooled_file)
region_df  <- if(file.exists(region_file)) readxl::read_excel(region_file) else NULL

cont_table <- pooled_df %>% mutate(label = glue::glue("{pooled:.3f} ({low:.3f} - {high:.3f})")) %>% select(Age, Subtype, label) %>% pivot_wider(names_from = Age, values_from = label)

country_top <- country_df %>% filter(Age == "U5", Subtype == "Total") %>% arrange(desc(Cases_point)) %>% mutate(Prevalence = round(prevalence_pct,3), Cases_point = round(Cases_point), Cases_lower = round(Cases_lower), Cases_upper = round(Cases_upper)) %>% select(Country, Prevalence, Cases_point, Cases_lower, Cases_upper) %>% slice_head(n = 20) %>% mutate(Cases = paste0(Cases_point, " (", Cases_lower, "-", Cases_upper, ")")) %>% select(Country, Prevalence, Cases)

ft_cont <- flextable(cont_table) %>% autofit()
ft_country <- flextable(country_top) %>% autofit()

figs <- list.files(results_dir, pattern = "\\.png$", full.names = TRUE)
figs_to_use <- head(figs, 6)

doc <- read_docx() %>% body_add_par("Sickle Cell Disease (SCD) in Sub-Saharan Africa", style = "heading 1") %>% body_add_par(glue::glue("Report generated: {Sys.Date()}"), style = "Normal") %>% body_add_page_break()
doc <- doc %>% body_add_par("Crude pooled prevalence", style = "heading 2") %>% body_add_flextable(ft_cont) %>% body_add_page_break() %>% body_add_par("Top countries (U5, Total)", style = "heading 2") %>% body_add_flextable(ft_country)

if(length(figs_to_use)>0){
  doc <- doc %>% body_add_page_break() %>% body_add_par("Figures", style = "heading 2")
  for(f in figs_to_use){
    doc <- doc %>% body_add_par(basename(f), style = "heading 3") %>% body_add_img(src = f, width = 6, height = 4)
  }
}

out_docx <- file.path(results_dir, glue::glue("SCD_report_officer_{Sys.Date()}.docx"))
print(doc, target = out_docx)
message("Word report produced at: ", out_docx)
