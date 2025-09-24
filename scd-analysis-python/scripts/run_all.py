from __future__ import annotations
from pathlib import Path
import pandas as pd
from scd_analysis.io import load_excel, write_table
from scd_analysis.meta import subgroup_meta, meta_regression
from scd_analysis.aggregate import read_country_agg
from scd_analysis.plots import forest_plot, grouped_enhanced_bars

DATA_DIR = Path("data")
OUT_DIR  = Path("outputs")
(OUT_DIR / "tables").mkdir(parents=True, exist_ok=True)
(OUT_DIR / "figures").mkdir(parents=True, exist_ok=True)

def main():
    xlsx = DATA_DIR / "SCD_prevalence_9points_CI-new-upd.xlsx"
    prev_cases = load_excel(xlsx, "Result-prev-cases")
    agg1 = load_excel(xlsx, "Result-agg1")
    agg2 = load_excel(xlsx, "Result-agg2")
    write_table(prev_cases, OUT_DIR / "tables" / "Result-prev-cases.xlsx")
    write_table(agg1, OUT_DIR / "tables" / "Result-agg1.xlsx")
    write_table(agg2, OUT_DIR / "tables" / "Result-agg2.xlsx")

    meta_data = load_excel(xlsx, "meta data")
    if set(["Age group","SCA Subtype","Events","N"]).issubset(meta_data.columns):
        by_pheno = subgroup_meta(meta_data, ["SCA Subtype"], "Events", "N")
        by_age   = subgroup_meta(meta_data, ["Age group"], "Events", "N")
        write_table(by_pheno, OUT_DIR / "tables" / "meta_subgroup_phenotype.xlsx")
        write_table(by_age, OUT_DIR / "tables" / "meta_subgroup_age.xlsx")

    processed = load_excel(xlsx, "processed")
    mod_cols = [c for c in ["SDI","Pop_2023","Longitude","Latitude"] if c in processed.columns]
    if set(["Events","N"]).issubset(processed.columns) and mod_cols:
        mr = meta_regression(processed.dropna(subset=["Events","N"] + mod_cols),
                             event_col="Events", n_col="N", moderators=mod_cols)
        write_table(mr, OUT_DIR / "tables" / "meta_regression.xlsx")

    agg, country = read_country_agg(DATA_DIR / "agg-cty.xlsx")
    write_table(agg, OUT_DIR / "tables" / "agg_regions_fullNumbers.xlsx")
    write_table(country, OUT_DIR / "tables" / "agg_countries_fullNumbers.xlsx")

    df15 = country[(country["Age"]=="U15") & (country["SCD subtype"]=="Total")].copy()
    regions_dict = {
        "Eastern Africa": ["Burundi","Comoros","Djibouti","Eritrea","Ethiopia","Kenya","Madagascar","Malawi","Mauritius","Mayotte","Mozambique","Réunion","Rwanda","Seychelles","Somalia","South Sudan","Uganda","United Republic of Tanzania","Zambia","Zimbabwe"],
        "Central Africa": ["Angola","Cameroon","Central African Republic","Chad","Congo","Democratic Republic of the Congo","Equatorial Guinea","Gabon","Sao Tome and Principe","Sudan"],
        "Southern Africa": ["Botswana","Eswatini","Lesotho","Namibia","South Africa"],
        "Western Africa": ["Benin","Burkina Faso","Cabo Verde","Côte d'Ivoire","Gambia","Ghana","Guinea","Guinea-Bissau","Liberia","Mali","Mauritania","Niger","Nigeria","Saint Helena","Senegal","Sierra Leone","Togo"]
    }
    order = []; region_breaks = []; cum = 0
    for reg, clist in regions_dict.items():
        present = [c for c in clist if (df15["Country"]==c).any()]
        order.extend(present); cum += len(present); region_breaks.append(cum)
    if order:
        df15 = df15.set_index("Country").loc[order].reset_index()
        df15["label"] = df15["Country"]
        grouped_enhanced_bars(df15, value_col="Cases", label_col="label",
                              group_breaks=region_breaks,
                              out_path=OUT_DIR / "figures" / "U15_Total_cases_enhanced_barchart_userOrder.png", logx=True)
    print("Done. Tables in outputs/tables, figures in outputs/figures.")

if __name__ == "__main__":
    main()
