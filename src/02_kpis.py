"""Step 2: run each query in sql/kpis.sql against ae.db and save the result
to outputs/<name>.csv. These files are where every README number comes from."""
from pathlib import Path
import sqlite3
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs"
OUT.mkdir(exist_ok=True)

sql = (ROOT / "sql" / "kpis.sql").read_text()
blocks = [b for b in sql.split("-- name: ")[1:]]

with sqlite3.connect(ROOT / "data" / "clean" / "ae.db") as con:
    for block in blocks:
        name, query = block.split("\n", 1)
        result = pd.read_sql(query.split(";")[0], con)
        result.to_csv(OUT / f"{name.strip()}.csv", index=False)
        print(f"\n== {name.strip()}\n{result.to_string(index=False)}")
