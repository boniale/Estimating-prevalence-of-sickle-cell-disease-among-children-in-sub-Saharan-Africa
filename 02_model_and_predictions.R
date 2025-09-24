# 02_model_and_predictions.R
# Fit GLMM (binomial) on counts, produce country-level predictions with uncertainty and absolute cases.

source("00_packages.R")

data_dir <- here::here("..","data")
out_dir  <- here::here("..","results")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

prev_clean_file <- file.path(out_dir, "prev_cleaned.xlsx")
if(!file.exists(prev_clean_file)) stop("Run 01_data_prep_and_crude.R first to create prev_cleaned.xlsx")

prev <- readxl::read_excel(prev_clean_file) %>% as_tibble()

pop_raw <- readxl::read_excel(file.path(data_dir, "WPP2023.xlsx")) %>% janitor::clean_names()
message("Population columns: ", paste(names(pop_raw), collapse = ", "))

u1_col <- names(pop_raw)[grepl("0[_\\-]?1|^u1$|0 to 1", names(pop_raw), ignore.case = TRUE)][1]
u5_col <- names(pop_raw)[grepl("0[_\\-]?4|^u5$|0 to 4", names(pop_raw), ignore.case = TRUE)][1]
u15_col<- names(pop_raw)[grepl("0[_\\-]?14|^u15$|0 to 14", names(pop_raw), ignore.case = TRUE)][1]
country_col <- names(pop_raw)[1]

if(is.na(u1_col) | is.na(u5_col) | is.na(u15_col)){
  stop("Could not detect U1/U5/U15 columns in WPP2023.xlsx automatically. Please set the correct column names in script.")
}

pop <- pop_raw %>%
  rename(Country = !!country_col,
         pop_U1 = !!u1_col,
         pop_U5 = !!u5_col,
         pop_U15 = !!u15_col) %>%
  mutate(Country = as.character(Country))

mod_df <- prev %>%
  filter(!is.na(Cases) & !is.na(SampleSize) & SampleSize > 0 & !is.na(SDI)) %>%
  mutate(
    IncomeEnc = as.factor(IncomeGroup),
    Age_f = factor(Age, levels = c("U1","U5","U15")),
    Sub_f = factor(Subtype, levels = c("Total","SS","SC","Other")),
    lon = as.numeric(lon),
    lat = as.numeric(lat)
  ) %>%
  filter(!is.na(lon) & !is.na(lat))

form <- as.formula("cbind(Cases, SampleSize - Cases) ~ SDI + I(SDI^2) + IncomeEnc + Age_f + Sub_f + lon + lat + I(lon*lat) + (1 | Country)")

glmm_fit <- glmer(form, data = mod_df, family = binomial(link = "logit"),
                  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5)))
saveRDS(glmm_fit, file.path(out_dir, "glmm_fit.rds"))
message("GLMM fitted; summary:")
print(summary(glmm_fit))

beta_hat <- fixef(glmm_fit)
vcov_beta <- as.matrix(vcov(glmm_fit))
sigma_u2 <- as.numeric(VarCorr(glmm_fit)$Country[1])

ssa_countries <- unique(pop$Country)
ages <- c("U1","U5","U15")
subtypes <- c("Total","SS","SC","Other")

grid <- expand.grid(Country = ssa_countries, Age = ages, Subtype = subtypes, stringsAsFactors = FALSE) %>% as_tibble()

country_sdi <- prev %>% group_by(Country) %>% summarize(SDI = mean(SDI, na.rm = TRUE))
grid <- grid %>% left_join(country_sdi, by = "Country")

income_map <- prev %>% select(Country, IncomeGroup) %>% distinct()
grid <- grid %>% left_join(income_map, by = "Country")

centroids <- prev %>% group_by(Country) %>% summarize(lon = mean(lon, na.rm = TRUE), lat = mean(lat, na.rm = TRUE))
grid <- grid %>% left_join(centroids, by = "Country")

grid <- grid %>% left_join(pop, by = "Country")
grid <- grid %>% mutate(Population = case_when(Age == "U1" ~ pop_U1, Age == "U5" ~ pop_U5, Age == "U15" ~ pop_U15))

grid <- grid %>% mutate(Age_f = factor(Age, levels = levels(mod_df$Age_f)), Sub_f = factor(Subtype, levels = levels(mod_df$Sub_f)), IncomeEnc = factor(IncomeGroup, levels = levels(mod_df$IncomeEnc)))
grid$IncomeEnc[is.na(grid$IncomeEnc)] <- levels(mod_df$IncomeEnc)[1]

X <- model.matrix(delete.response(terms(glmm_fit)), data = grid)
eta_fixed <- as.vector(X %*% beta_hat)
var_eta_fixed <- diag(X %*% vcov_beta %*% t(X))
var_eta <- var_eta_fixed + sigma_u2
se_eta <- sqrt(var_eta)
eta_low <- eta_fixed - 1.96 * se_eta
eta_high <- eta_fixed + 1.96 * se_eta
p_hat <- plogis(eta_fixed)
p_low <- plogis(eta_low)
p_high <- plogis(eta_high)

grid_out <- grid %>% mutate(eta = eta_fixed, se_eta = se_eta, prevalence_pct = p_hat*100, prev_lower_pct = p_low*100, prev_upper_pct = p_high*100, Population = Population, Cases_point = (p_hat)*Population, Cases_lower = (p_low)*Population, Cases_upper = (p_high)*Population)

write.xlsx(grid_out, file.path(out_dir, "country_predictions_prevalence_and_cases.xlsx"), overwrite = TRUE)
message("02_model_and_predictions.R complete; outputs saved.")
