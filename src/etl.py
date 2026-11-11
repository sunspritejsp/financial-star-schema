import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OLTP_DB = ROOT / "oltp.db"
DW_DB = ROOT / "dw.db"

if not OLTP_DB.exists():
    raise SystemExit("oltp.db not found. Run python src/migrate.py.")

conn = sqlite3.connect(DW_DB)
conn.execute("PRAGMA foreign_keys = ON")
conn.executescript((ROOT / "sql" / "dw_schema.sql").read_text(encoding="utf-8"))
conn.execute("ATTACH DATABASE ? AS oltp", (str(OLTP_DB),))
conn.executescript((ROOT / "sql" / "etl.sql").read_text(encoding="utf-8"))

for table in ["dim_date", "dim_segment", "dim_country", "dim_product",
              "dim_discount_band", "fact_sales"]:
    count = conn.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
    print(f"dw.db: {table} = {count} rows")
conn.close()
