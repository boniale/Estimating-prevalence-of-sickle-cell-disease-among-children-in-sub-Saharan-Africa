from __future__ import annotations
import numpy as np
import pandas as pd

def logit(p: np.ndarray) -> np.ndarray:
    p = np.clip(p, 1e-9, 1 - 1e-9)
    return np.log(p / (1 - p))

def expit(x: np.ndarray) -> np.ndarray:
    return 1 / (1 + np.exp(-x))

def continuity_correct(events: np.ndarray, n: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    e = events.astype(float).copy()
    N = n.astype(float).copy()
    mask_zero = (e <= 0)
    mask_one  = (e >= N)
    any_mask = mask_zero | mask_one
    e[any_mask] = e[any_mask] + 0.5
    N[any_mask] = N[any_mask] + 1.0
    return e, N

def ci_from_logit(lhat: float, se: float, z: float = 1.96) -> tuple[float, float, float]:
    lo = expit(lhat - z * se)
    hi = expit(lhat + z * se)
    pe = expit(lhat)
    return pe, lo, hi

def ensure_cols(df: pd.DataFrame, cols: list[str]) -> None:
    missing = [c for c in cols if c not in df.columns]
    if missing:
        raise ValueError(f"Missing required columns: {missing}")
