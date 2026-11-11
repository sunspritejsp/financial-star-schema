import runpy
import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent

for db in ["oltp.db", "dw.db"]:
    (ROOT / db).unlink(missing_ok=True)

for script in ["src/migrate.py", "src/etl.py", "src/check.py"]:
    print(f"\n===== {script}")
    runpy.run_path(str(ROOT / script))

pd.set_option("display.float_format", "{:,.2f}".format)
pd.set_option("display.width", 200)
conn = sqlite3.connect(ROOT / "dw.db")
for query in sorted((ROOT / "sql" / "queries").glob("*.sql")):
    print(f"\n===== {query.name}")
    print(pd.read_sql(query.read_text(encoding="utf-8"), conn).to_string(index=False))
conn.close()
