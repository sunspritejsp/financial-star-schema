"""Check that nothing was lost or changed between the three stages.

Run from the project root:  python src/check.py
Exits with an error if any check fails.
"""

import sqlite3
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
OLTP_DB = ROOT / "oltp.db"
DW_DB = ROOT / "dw.db"
TOLERANCE = 0.01   # money is stored as REAL, so allow a cent of rounding

failed = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global failed
    print(f"[{'PASS' if ok else 'FAIL'}] {name}  {detail}")
    failed += not ok


raw = []
for prefix in ["Base_de_dados_2020_2021", "Base_de_dados_2022_2023"]:
    sales = pd.read_excel(RAW / f"{prefix}_-_Sales.xlsx", keep_default_na=False)
    manuf = pd.read_excel(RAW / f"{prefix}_-_Manufacturing.xlsx", keep_default_na=False)
    sales["COGS"] = manuf["COGS"]
    raw.append(sales.drop_duplicates())
raw = pd.concat(raw)
spreadsheet = {"rows": len(raw), "units_sold": raw["Units Sold"].sum(),
               "sales": raw[" Sales"].sum(), "cogs": raw["COGS"].sum(),
               "profit": raw["Profit"].sum()}

conn = sqlite3.connect(DW_DB)
conn.execute("PRAGMA foreign_keys = ON")
conn.execute("ATTACH DATABASE ? AS oltp", (str(OLTP_DB),))
totals = "count(*), sum(units_sold), sum(sales), sum(cogs), sum(profit)"
oltp = dict(zip(spreadsheet, conn.execute(f"SELECT {totals} FROM oltp.v_sale").fetchone()))
dw = dict(zip(spreadsheet, conn.execute(f"SELECT {totals} FROM fact_sales").fetchone()))

check("1,358 sales", spreadsheet["rows"] == oltp["rows"] == dw["rows"] == 1358,
      f"{spreadsheet['rows']} / {oltp['rows']} / {dw['rows']}")
for measure in ["units_sold", "sales", "cogs", "profit"]:
    a, b, c = spreadsheet[measure], oltp[measure], dw[measure]
    check(f"total {measure} matches", abs(a - b) <= TOLERANCE and abs(b - c) <= TOLERANCE,
          f"{a:,.2f} / {b:,.2f} / {c:,.2f}")

check("no broken foreign keys in dw.db", not conn.execute("PRAGMA foreign_key_check").fetchall())
check("no broken foreign keys in oltp.db",
      not conn.execute("PRAGMA oltp.foreign_key_check").fetchall())
conn.close()

conn = sqlite3.connect(OLTP_DB)
conn.execute("PRAGMA foreign_keys = ON")
conn.executescript((ROOT / "sql" / "oltp_schema.sql").read_text(encoding="utf-8"))
check("oltp_schema.sql runs a second time", True)

bad_inserts = {
    "unknown country (foreign key)": "99, 1, 1, 1, 10.0, 0.0",
    "negative units (CHECK)": "1, 1, 1, 1, -5.0, 0.0",
    "text in a number column (STRICT)": "1, 1, 1, 1, 'ten', 0.0",
}
for name, values in bad_inserts.items():
    try:
        conn.execute("INSERT INTO sale (source_period, source_row, sale_date, country_id, "
                     "product_id, price_tier_id, discount_band_id, units_sold, discounts) "
                     f"VALUES ('2022-2023', 9999, '2023-01-01', {values})")
        check(f"rejects {name}", False, "the insert was accepted")
    except sqlite3.IntegrityError:
        check(f"rejects {name}", True)
    conn.rollback()
conn.close()

if failed:
    sys.exit(f"\n{failed} check(s) failed.")
print("\nAll checks passed.")
