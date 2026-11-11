"""Clean the four spreadsheets and load them into oltp.db (3NF).

Run from the project root:  python src/migrate.py
"""

import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
OLTP_DB = ROOT / "oltp.db"

SEGMENT_FIXES = {
    "Public Sectar": "Public Sector",
    "Retail Custmers": "Retail Customers",
    "Corp&rate": "Corporate",
    "Corprate": "Corporate",
    "Reselers": "Resellers",
}
COUNTRY_FIXES = {"PortugaL": "Portugal"}


def read_period(period: str, prefix: str) -> pd.DataFrame:
    """Read one period's Sales and Manufacturing files as one table of sales."""
    # keep_default_na=False keeps the discount band "None" as text, not NaN.
    sales = pd.read_excel(RAW / f"{prefix}_-_Sales.xlsx", keep_default_na=False)
    manuf = pd.read_excel(RAW / f"{prefix}_-_Manufacturing.xlsx", keep_default_na=False)

    # There is no key, so the two files pair up by row position.
    shared = sales.columns.intersection(manuf.columns)
    assert sales[shared].equals(manuf[shared]), f"{period}: files don't pair up"
    sales["Manufacturing Price"] = manuf["Manufacturing Price"]
    sales["COGS"] = manuf["COGS"]

    sales["source_period"] = period
    sales["source_row"] = sales.index
    duplicates = sales.drop(columns="source_row").duplicated()
    print(f"{period}: {len(sales)} rows, dropping {duplicates.sum()} exact duplicates")
    sales = sales[~duplicates]

    # 1NF: the 2020-2021 files hold country and product in one column.
    if "Country,Product" in sales.columns:
        sales[["Country", "Product"]] = sales["Country,Product"].str.split(",", expand=True)
        sales = sales.drop(columns="Country,Product")
    return sales


def lookup_table(values, id_col: str, name_col: str) -> pd.DataFrame:
    """One row per distinct value, numbered from 1 in alphabetical order."""
    names = sorted(set(values))
    return pd.DataFrame({id_col: range(1, len(names) + 1), name_col: names})


def ids(table: pd.DataFrame, id_col: str, name_col: str) -> dict:
    return dict(zip(table[name_col], table[id_col]))


df = pd.concat([read_period("2020-2021", "Base_de_dados_2020_2021"),
                read_period("2022-2023", "Base_de_dados_2022_2023")], ignore_index=True)
df = df.rename(columns={" Sales": "Sales"}).drop(columns="Product_Name")
df["Segment"] = df["Segment"].replace(SEGMENT_FIXES)
df["Country"] = df["Country"].replace(COUNTRY_FIXES)
df["unit_cost"] = df["COGS"] / df["Units Sold"]

assert len(df) == 1358, f"expected 1,358 sales, got {len(df)}"
assert (df["Gross Sales"] - df["Units Sold"] * df["Sale Price"]).abs().max() < 0.01
assert (df["Sales"] - (df["Gross Sales"] - df["Discounts"])).abs().max() < 0.01
assert (df["Profit"] - (df["Sales"] - df["COGS"])).abs().max() < 0.01
# Manufacturing Price depends only on the product.
assert df.groupby("Product")["Manufacturing Price"].nunique().max() == 1
# Each sale price fixes one segment and one cost per unit (a price tier).
assert df.groupby("Sale Price")[["Segment", "unit_cost"]].nunique().max().max() == 1

segment = lookup_table(df["Segment"], "segment_id", "segment_name")
country = lookup_table(df["Country"], "country_id", "country_name")

product = lookup_table(df["Product"], "product_id", "product_name")
product["manufacturing_price"] = product["product_name"].map(
    df.groupby("Product")["Manufacturing Price"].first())

discount_band = pd.DataFrame({
    "discount_band_id": [1, 2, 3, 4],
    "band_name": ["None", "Low", "Medium", "High"],
    "sort_order": [0, 1, 2, 3],
    "min_rate": [0.00, 0.01, 0.05, 0.10],      # Discounts / Gross Sales
    "max_rate": [0.00, 0.04, 0.09, 0.15],
})

price_tier = (df[["Segment", "Sale Price", "unit_cost"]].drop_duplicates()
              .sort_values(["Segment", "Sale Price"]).reset_index(drop=True))
price_tier.insert(0, "price_tier_id", price_tier.index + 1)
price_tier["segment_id"] = price_tier["Segment"].map(ids(segment, "segment_id", "segment_name"))
price_tier = price_tier.rename(columns={"Sale Price": "sale_price"}).drop(columns="Segment")

sale = pd.DataFrame({
    "source_period": df["source_period"],
    "source_row": df["source_row"],
    "sale_date": df["Date"].dt.strftime("%Y-%m-%d"),
    "country_id": df["Country"].map(ids(country, "country_id", "country_name")),
    "product_id": df["Product"].map(ids(product, "product_id", "product_name")),
    "price_tier_id": df["Sale Price"].map(dict(zip(price_tier["sale_price"],
                                                   price_tier["price_tier_id"]))),
    "discount_band_id": df["Discount Band"].map(ids(discount_band, "discount_band_id",
                                                    "band_name")),
    "units_sold": df["Units Sold"],
    "discounts": df["Discounts"],
})
assert sale.notna().all().all(), "a value has no matching lookup row"

OLTP_DB.unlink(missing_ok=True)
conn = sqlite3.connect(OLTP_DB)
conn.execute("PRAGMA foreign_keys = ON")
conn.executescript((ROOT / "sql" / "oltp_schema.sql").read_text(encoding="utf-8"))
tables = {"segment": segment, "country": country, "product": product,
          "discount_band": discount_band, "price_tier": price_tier, "sale": sale}
with conn:
    for name, table in tables.items():
        table.to_sql(name, conn, if_exists="append", index=False)
        print(f"oltp.db: {name} = {len(table)} rows")
conn.close()
