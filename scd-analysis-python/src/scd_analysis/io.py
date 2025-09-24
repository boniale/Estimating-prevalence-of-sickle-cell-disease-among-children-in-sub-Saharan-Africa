from __future__ import annotations
import pandas as pd
from pathlib import Path

def load_excel(path: str | Path, sheet: str) -> pd.DataFrame:
    return pd.read_excel(Path(path), sheet_name=sheet)

def write_table(df: pd.DataFrame, path: str | Path) -> None:
    p = Path(path); p.parent.mkdir(parents=True, exist_ok=True)
    df.to_excel(p, index=False)

def write_csv(df: pd.DataFrame, path: str | Path) -> None:
    p = Path(path); p.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(p, index=False)
