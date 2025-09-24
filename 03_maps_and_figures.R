# 03_maps_and_figures.R
# Create maps and histograms for outputs

source("00_packages.R")

data_dir <- here::here("..","data")
out_dir  <- here::here("..","results")

preds_file <- file.path(out_dir, "country_predictions_prevalence_and_cases.xlsx")
if(!file.exists(preds_file)) stop("Predictions file not found. Run earlier scripts.")

preds <- readxl::read_excel(preds_file) %>% as_tibble()

shp_path <- file.path(data_dir, "africa_shapefile.geojson")
if(file.exists(shp_path)){
  shp <- sf::st_read(shp_path, quiet = TRUE)
  shp_name_col <- names(shp)[sapply(shp, is.character)][1]
  if(is.null(shp_name_col)) shp_name_col <- names(shp)[1]
  shp <- shp %>% mutate(Country_shp = !!sym(shp_name_col))
  map_df <- preds %>% filter(Age == "U5", Subtype == "Total") %>% select(Country, Cases_point)
  shp_join <- shp %>% left_join(map_df, by = c("Country_shp" = "Country"))
  plot_map <- tmap::tm_shape(shp_join) + tmap::tm_polygons("Cases_point", title = "SCD cases (U5, Total)", style = "quantile", n = 6) + tmap::tm_layout(legend.outside = TRUE)
  tmap::tmap_save(plot_map, filename = file.path(out_dir, "map_SSA_U5_Total_cases.png"), dpi = 300)
  message("Map saved.")
} else {
  message("No shapefile found. Skipping map creation.")
}

for(a in unique(preds$Age)){
  p <- preds %>% filter(Age == a) %>% ggplot(aes(x = Cases_point + 1)) + geom_histogram(bins = 50) + scale_x_log10() + facet_wrap(~Subtype, scales = "free_x") + labs(title = glue::glue("Distribution of absolute SCD cases by country — {a}"), x = "Cases (log scale)", y = "Number of countries") + theme_minimal()
  ggsave(file.path(out_dir, glue::glue("hist_cases_{a}.png")), plot = p, width = 10, height = 6, dpi = 300)
}
message("Histograms saved to results/")
