from __future__ import annotations
import numpy as np
import pandas as pd
from dataclasses import dataclass
from .utils import logit, expit, continuity_correct, ensure_cols

@dataclass
class MetaResult:
    k: int
    tau2: float
    pooled_logit: float
    pooled: float
    se: float
    lcl: float
    ucl: float

def dl_random_effects_logit(events: np.ndarray, n: np.ndarray) -> MetaResult:
    e, N = continuity_correct(events, n)
    p = e / N
    yi = logit(p)
    vi = 1.0 / (e) + 1.0 / (N - e)
    wi = 1.0 / vi
    ybar = np.sum(wi * yi) / np.sum(wi)
    Q = np.sum(wi * (yi - ybar) ** 2)
    C = np.sum(wi) - (np.sum(wi**2) / np.sum(wi))
    tau2 = max(0.0, (Q - (len(yi) - 1)) / C) if C > 0 else 0.0
    wi_star = 1.0 / (vi + tau2)
    mu = np.sum(wi_star * yi) / np.sum(wi_star)
    se = np.sqrt(1.0 / np.sum(wi_star))
    pe = expit(mu)
    lcl = expit(mu - 1.96 * se)
    ucl = expit(mu + 1.96 * se)
    return MetaResult(k=len(yi), tau2=tau2, pooled_logit=mu, pooled=pe, se=se, lcl=lcl, ucl=ucl)

def subgroup_meta(df: pd.DataFrame, group_cols: list[str], event_col: str, n_col: str) -> pd.DataFrame:
    ensure_cols(df, group_cols + [event_col, n_col])
    out = []
    for keys, g in df.groupby(group_cols, dropna=False):
        res = dl_random_effects_logit(g[event_col].values, g[n_col].values)
        row = dict(zip(group_cols, keys if isinstance(keys, tuple) else (keys,)))
        row.update({
            "k": res.k, "tau2": res.tau2,
            "pooled_prev": res.pooled,
            "lcl": res.lcl, "ucl": res.ucl,
        })
        out.append(row)
    return pd.DataFrame(out)

def meta_regression(df: pd.DataFrame, event_col: str, n_col: str, moderators: list[str]) -> pd.DataFrame:
    import statsmodels.api as sm
    ensure_cols(df, [event_col, n_col] + moderators)
    e, N = continuity_correct(df[event_col].to_numpy(), df[n_col].to_numpy())
    p = e / N
    yi = logit(p)
    vi = 1.0 / e + 1.0 / (N - e)
    wi = 1.0 / vi
    ybar = np.sum(wi * yi) / np.sum(wi)
    Q = np.sum(wi * (yi - ybar) ** 2)
    C = np.sum(wi) - (np.sum(wi**2) / np.sum(wi))
    tau2 = max(0.0, (Q - (len(yi) - 1)) / C) if C > 0 else 0.0
    W = 1.0 / (vi + tau2)
    X = sm.add_constant(df[moderators])
    model = sm.WLS(yi, X, weights=W)
    fit = model.fit()
    coefs = fit.params
    ses   = fit.bse
    out = pd.DataFrame({"term": coefs.index, "coef_logit": coefs.values, "se": ses.values})
    return out
