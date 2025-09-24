# SCD Analysis (Python)

Python reproduction of the SCD analysis pipeline (meta-analysis, subgroups, meta-regression, pooled totals, and figures).

## Quick start
```bash
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python scripts/run_all.py
```
Place your input Excel files in `data/`:
- `SCD_prevalence_9points_CI-new-upd.xlsx`
- `agg-cty.xlsx`

Outputs go to `outputs/tables` and `outputs/figures`.
