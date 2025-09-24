# 01_data_prep_and_crude.R
# Prepare study-level data and compute crude pooled prevalences (DL on logit scale)

source("00_packages.R")

# CONFIG: change only file names here if your data files are in different names/paths
data_dir <- here::here("..","data")
prev_file  <- file.path(data_dir, "preprocessed_prev_data_updated.xlsx")
class_file <- file.path(data_dir, "CLASS.xlsx")
sdi_file   <- file.path(data_dir, "SDI.xlsx")
out_dir    <- here::here("..","results")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

message("Reading prevalence file: ", prev_file)
prev_raw <- readxl::read_excel(prev_file, sheet = 1) %>% janitor::clean_names()

message("Columns in prevalence file: ", paste(names(prev_raw), collapse = ", "))

prev <- prev_raw %>%
  rename_with(~ str_replace_all(.x, "\\s+", "_")) %>%
  rename(
    Country = any_of(c("country","country_name")),
    Cases = any_of(c("cases","case_count","case_number")),
    SampleSize = any_of(c("sample_size","n","denominator")),
    Age_group = any_of(c("age_group","age")),
    HB = any_of(c("hb","hb_type","haemoglobin","haemoglobin_type")),
    lon = any_of(c("lon","longitude","long")),
    lat = any_of(c("lat","latitude")),
    StudyYear = any_of(c("study_year","year"))
  ) %>%
  mutate(
    Cases = as.numeric(Cases),
    SampleSize = as.numeric(SampleSize)
  )

prev <- prev %>%
  mutate(Age = case_when(
    str_detect(Age_group, regex("newborn|neonat|u1|0-1|0 to 1|0–1", ignore_case = TRUE)) ~ "U1",
    str_detect(Age_group, regex("u5|0-4|0 to 4|0–4", ignore_case = TRUE)) ~ "U5",
    str_detect(Age_group, regex("u15|0-14|0 to 14|0–14|u6-10|u6-15|u11-15", ignore_case = TRUE)) ~ "U15",
    TRUE ~ NA_character_
  ))

prev <- prev %>%
  mutate(Subtype = case_when(
    str_to_lower(HB) %in% c("all","total") ~ "Total",
    str_detect(HB, regex("^ss$|sickle.*ss|fs$", ignore_case = TRUE)) ~ "SS",
    str_detect(HB, regex("^sc$|fsc", ignore_case = TRUE)) ~ "SC",
    TRUE ~ "Other"
  ))

prev <- prev %>%
  mutate(p_obs = Cases / SampleSize,
         var_p = if_else(!is.na(p_obs) & !is.na(SampleSize) & SampleSize > 0,
                         p_obs * (1 - p_obs) / SampleSize, NA_real_))

class_df <- readxl::read_excel(class_file) %>% janitor::clean_names()
class_map <- class_df %>%
  rename(Country = any_of(c("economy","country","country_name")),
         IncomeGroup = any_of(c("income_group","incomegroup"))) %>%
  select(Country, IncomeGroup)

prev <- prev %>% left_join(class_map, by = "Country")

sdi_df <- readxl::read_excel(sdi_file) %>% janitor::clean_names()
if("2019" %in% names(sdi_df)){
  sdi_map <- sdi_df %>% transmute(Country = location, SDI_2019 = `2019`)
  prev <- prev %>% left_join(sdi_map, by = "Country") %>% mutate(SDI = coalesce(SDI_2019, NA_real_))
} else if(all(c("location","year","sdi") %in% names(sdi_df))){
  sdi_mean <- sdi_df %>% rename(Country = location) %>% group_by(Country) %>% summarize(SDI = mean(sdi, na.rm = TRUE))
  prev <- prev %>% left_join(sdi_mean, by = "Country")
} else {
  prev$SDI <- NA_real_
  warning("SDI file not recognized. Edit script to map SDI correctly.")
}

write.xlsx(prev, file.path(out_dir, "prev_cleaned.xlsx"), overwrite = TRUE)

calc_pooled <- function(df){
  df2 <- df %>% filter(!is.na(Cases) & !is.na(SampleSize) & SampleSize > 0)
  if(nrow(df2) < 2) return(tibble(k = nrow(df2), pooled = NA_real_, low = NA_real_, high = NA_real_))
  esc <- escalc(measure = "PLO", xi = df2$Cases, ni = df2$SampleSize)
  res <- rma.uni(yi = esc$yi, vi = esc$vi, method = "DL")
  tibble(k = nrow(df2),
         pooled = as.numeric(transf.ilogit(res$beta) * 100),
         low = as.numeric(transf.ilogit(res$ci.lb) * 100),
         high = as.numeric(transf.ilogit(res$ci.ub) * 100))
}

ages <- c("U1","U5","U15")
subtypes <- c("Total","SS","SC","Other")
pooled_results <- purrr::map_dfr(ages, function(a){
  purrr::map_dfr(subtypes, function(s){
    calc_pooled(prev %>% filter(Age == a & Subtype == s)) %>% mutate(Age = a, Subtype = s)
  })
})

write.xlsx(pooled_results, file.path(out_dir, "pooled_crude_prevalence_by_age_subtype.xlsx"), overwrite = TRUE)
message("01_data_prep_and_crude.R finished. Outputs in: ", out_dir)
