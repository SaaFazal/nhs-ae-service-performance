"""Step 1: load every monthly NHS England A&E CSV in data/raw, clean it,
and save one tidy table (CSV for Power BI checks, SQLite for the SQL KPIs)."""
from pathlib import Path
import sqlite3
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
CLEAN = ROOT / "data" / "clean"
CLEAN.mkdir(parents=True, exist_ok=True)

frames = []
for f in sorted(RAW.glob("ae_*.csv")):
    df = pd.read_csv(f)
    # Each file ends with a national total row, written differently from month to month
    # ("TOTAL", "Total ", or a normal Period with Org Code TOTAL). Split it off.
    is_total = (df["Org Code"].astype(str).str.strip().str.upper() == "TOTAL") |                ~df["Period"].astype(str).str.strip().str.upper().str.startswith("MSITAE-")
    total_row, df = df[is_total], df[~is_total]
    # Check: the provider rows must add up to NHS England's own total row
    num = df.columns[4:]
    assert len(total_row) == 1, f"{f.name}: expected one total row"
    assert (df[num].sum() == total_row[num].iloc[0]).all(), f"{f.name}: rows do not match total"
    frames.append(df)
df = pd.concat(frames, ignore_index=True)

# "MSitAE-OCTOBER-2025" -> 2025-10-01
df["month"] = pd.to_datetime(df["Period"].str.replace("MSitAE-", ""), format="%B-%Y")
df["region"] = df["Parent Org"].str.strip().str.replace("NHS ENGLAND ", "").str.title()
df["org_name"] = df["Org name"].str.strip()

att_cols = [c for c in df.columns if c.startswith("A&E attendances")]
over4_cols = [c for c in df.columns if c.startswith("Attendances over 4hrs")]

tidy = pd.DataFrame({
    "month": df["month"].dt.date,
    "org_code": df["Org Code"],
    "org_name": df["org_name"],
    "region": df["region"],
    "attendances": df[att_cols].sum(axis=1),
    "attendances_type1": df["A&E attendances Type 1"],
    "over_4hrs": df[over4_cols].sum(axis=1),
    "dta_4_to_12hrs": df["Patients who have waited 4-12 hs from DTA to admission"],
    "dta_over_12hrs": df["Patients who have waited 12+ hrs from DTA to admission"],
    "emergency_admissions": df[[c for c in df.columns if "admissions" in c.lower() and "DTA" not in c]].sum(axis=1),
})
tidy["within_4hrs"] = tidy["attendances"] - tidy["over_4hrs"]
# An "acute trust" here = any provider with a major (Type 1) A&E that month.
# Walk in centres and UTCs only have minor attendances and are left out of the trust RAG table.
tidy["has_type1_ae"] = (tidy["attendances_type1"] > 0).astype(int)

# Checks: fail loudly instead of producing wrong numbers
assert tidy["month"].nunique() == len(frames), "one month per file expected"
assert not tidy.duplicated(["month", "org_code"]).any(), "duplicate provider in a month"
assert (tidy["over_4hrs"] <= tidy["attendances"]).all(), "more over 4hrs than attendances"
assert (tidy[["attendances", "over_4hrs", "dta_over_12hrs"]] >= 0).all().all()

tidy.to_csv(CLEAN / "ae_monthly.csv", index=False)
with sqlite3.connect(CLEAN / "ae.db") as con:
    tidy.to_sql("ae_monthly", con, if_exists="replace", index=False)

print(f"{len(frames)} files, {len(tidy)} rows, {tidy['org_code'].nunique()} providers, "
      f"{tidy['month'].min()} to {tidy['month'].max()}")
print(f"saved {CLEAN / 'ae_monthly.csv'} and ae.db")
