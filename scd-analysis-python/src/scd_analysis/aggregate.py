from __future__ import annotations
import numpy as np
import pandas as pd
from .utils import ensure_cols

def attach_cases_from_population(df: pd.DataFrame, prev_col: str, pop_col: str, out_prefix: str = "cases") -> pd.DataFrame:
    ensure_cols(df, [prev_col, pop_col])
    out = df.copy()
    out[out_prefix] = out[prev_col] * out[pop_col]
    if "lcl" in out.columns and "ucl" in out.columns:
        out[f"{out_prefix}_lcl"] = out["lcl"] * out[pop_col]
        out[f"{out_prefix}_ucl"] = out["ucl"] * out[pop_col]
    return out

def read_country_agg(agg_cty_path: str):
    import pandas as pd
    agg = pd.read_excel(agg_cty_path, sheet_name="agg", header=None)
    country = pd.read_excel(agg_cty_path, sheet_name="country", header=None)
    agg.columns = ["Region","Age","SCD subtype","Prev","Prev_L","Prev_U","Total cases (000)","Cases_L (000)","Cases_U (000)"]
    country.columns = ["Country","Age","SCD subtype","Prev","Prev_L","Prev_U","Pop (000)","Total cases (000)","Cases_L (000)","Cases_U (000)"]
    for df in (agg, country):
        for c in ["Total cases (000)","Cases_L (000)","Cases_U (000)","Pop (000)"]:
            if c in df.columns:
                df[c] = pd.to_numeric(df[c], errors="coerce")
        if "Total cases (000)" in df.columns:
            df["Cases"]   = (df["Total cases (000)"]*1000).round()
            df["Cases_L"] = (df["Cases_L (000)"]*1000).round()
            df["Cases_U"] = (df["Cases_U (000)"]*1000).round()
        for p in ["Prev","Prev_L","Prev_U"]:
            if p in df.columns:
                df[p] = pd.to_numeric(df[p], errors="coerce") / 100.0
    return agg, country
