"""Rebuild both databases from the spreadsheets, check them and print every query result.

Run from the project root:  python run_all.py
"""

import sqlite3
import subprocess
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent

# Start from scratch, so the result never depends on an old database.
for db in ["oltp.db", "dw.db"]:
    (ROOT / db).unlink(missing_ok=True)

for script in ["src/migrate.py", "src/etl.py", "src/check.py"]:
    print(f"\n===== {script}", flush=True)
    subprocess.run([sys.executable, ROOT / script], check=True)

pd.set_option("display.float_format", "{:,.2f}".format)
pd.set_option("display.width", 200)
conn = sqlite3.connect(ROOT / "dw.db")
for query in sorted((ROOT / "sql" / "queries").glob("*.sql")):
    sql = query.read_text(encoding="utf-8")
    question = sql.splitlines()[0].removeprefix("-- Question: ")
    print(f"\n===== {query.name}: {question}")
    print(pd.read_sql(sql, conn).to_string(index=False))
conn.close()
