from __future__ import annotations
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
import matplotlib.colors as mcolors

def forest_plot(df: pd.DataFrame, est_col: str, lcl_col: str, ucl_col: str,
                label_col: str, title: str, out_path: str,
                to_percent: bool = True):
    p = Path(out_path); p.parent.mkdir(parents=True, exist_ok=True)
    est = df[est_col].astype(float).to_numpy()
    lcl = df[lcl_col].astype(float).to_numpy()
    ucl = df[ucl_col].astype(float).to_numpy()
    if to_percent:
        est, lcl, ucl = est*100, lcl*100, ucl*100
    y = np.arange(len(df))
    fig, ax = plt.subplots(figsize=(8, max(4, 0.35*len(df)+2)))
    ax.errorbar(est, y, xerr=[est - lcl, ucl - est], fmt='o', capsize=3)
    ax.set_yticks(y)
    ax.set_yticklabels(df[label_col].tolist(), fontsize=8)
    ax.set_xlabel("Prevalence (%)" if to_percent else "Prevalence")
    ax.set_title(title)
    ax.invert_yaxis()
    ax.grid(axis='x', alpha=0.2)
    fig.tight_layout()
    fig.savefig(p, dpi=300)
    plt.close(fig)

def grouped_enhanced_bars(df: pd.DataFrame, value_col: str, label_col: str,
                          group_breaks: list[int], out_path: str, logx: bool = True):
    p = Path(out_path); p.parent.mkdir(parents=True, exist_ok=True)
    vals = df[value_col].astype(float).to_numpy()
    cmap = plt.cm.get_cmap("RdYlGn_r")
    norm = mcolors.Normalize(vmin=np.nanmin(vals), vmax=np.nanmax(vals))
    colors = [cmap(norm(v)) for v in vals]
    y = np.arange(len(df))
    fig, ax = plt.subplots(figsize=(11, max(5, 0.35*len(df)+2)))
    ax.barh(y, vals, color=colors, alpha=0.95)
    ax.set_yticks(y)
    ax.set_yticklabels(df[label_col].tolist(), fontsize=9)
    if logx:
        ax.set_xscale("log")
    ax.set_xlabel("Cases")
    ax.grid(False)
    for br in group_breaks[:-1]:
        ax.axhline(br-0.5, color="#999", linestyle="--", linewidth=0.6)
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm); sm.set_array([])
    cbar = plt.colorbar(sm, ax=ax, fraction=0.03, pad=0.02)
    cbar.set_label("Cases (absolute)")
    fig.tight_layout()
    fig.savefig(p, dpi=300)
    plt.close(fig)
