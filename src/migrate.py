import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
OLTP_DB = ROOT / "oltp.db"

sales_2020 = pd.read_excel(RAW / "Base_de_dados_2020_2021_-_Sales.xlsx", keep_default_na=False)
manuf_2020 = pd.read_excel(RAW / "Base_de_dados_2020_2021_-_Manufacturing.xlsx", keep_default_na=False)
sales_2022 = pd.read_excel(RAW / "Base_de_dados_2022_2023_-_Sales.xlsx", keep_default_na=False)
manuf_2022 = pd.read_excel(RAW / "Base_de_dados_2022_2023_-_Manufacturing.xlsx", keep_default_na=False)

assert (sales_2020["Units Sold"] == manuf_2020["Units Sold"]).all()
assert (sales_2022["Units Sold"] == manuf_2022["Units Sold"]).all()

sales_2020["COGS"] = manuf_2020["COGS"]
sales_2020["Manufacturing Price"] = manuf_2020["Manufacturing Price"]
sales_2022["COGS"] = manuf_2022["COGS"]
sales_2022["Manufacturing Price"] = manuf_2022["Manufacturing Price"]

print(f"2020-2021: {len(sales_2020)} linhas, {sales_2020.duplicated().sum()} duplicadas")
print(f"2022-2023: {len(sales_2022)} linhas, {sales_2022.duplicated().sum()} duplicadas")
sales_2020 = sales_2020.drop_duplicates()
sales_2022 = sales_2022.drop_duplicates()

sales_2020["source_period"] = "2020-2021"
sales_2020["source_row"] = sales_2020.index
sales_2022["source_period"] = "2022-2023"
sales_2022["source_row"] = sales_2022.index

sales_2020[["Country", "Product"]] = sales_2020["Country,Product"].str.split(",", expand=True)
sales_2020 = sales_2020.drop(columns="Country,Product")

df = pd.concat([sales_2020, sales_2022], ignore_index=True)
df = df.drop(columns="Product_Name")
df = df.rename(columns={" Sales": "Sales"})

df["Segment"] = df["Segment"].replace({
    "Public Sectar": "Public Sector",
    "Retail Custmers": "Retail Customers",
    "Corp&rate": "Corporate",
    "Corprate": "Corporate",
    "Reselers": "Resellers",
})
df["Country"] = df["Country"].replace({"PortugaL": "Portugal"})

assert len(df) == 1358
assert ((df["Gross Sales"] - df["Units Sold"] * df["Sale Price"]).abs() < 0.01).all()
assert ((df["Sales"] - (df["Gross Sales"] - df["Discounts"])).abs() < 0.01).all()
assert ((df["Profit"] - (df["Sales"] - df["COGS"])).abs() < 0.01).all()

segment = pd.DataFrame({"segment_name": sorted(df["Segment"].unique())})
segment["segment_id"] = segment.index + 1

country = pd.DataFrame({"country_name": sorted(df["Country"].unique())})
country["country_id"] = country.index + 1

product = df[["Product", "Manufacturing Price"]].drop_duplicates().sort_values("Product")
product = product.rename(columns={"Product": "product_name",
                                  "Manufacturing Price": "manufacturing_price"})
product = product.reset_index(drop=True)
product["product_id"] = product.index + 1

discount_band = pd.DataFrame({
    "discount_band_id": [1, 2, 3, 4],
    "band_name": ["None", "Low", "Medium", "High"],
    "sort_order": [0, 1, 2, 3],
    "min_rate": [0.00, 0.01, 0.05, 0.10],
    "max_rate": [0.00, 0.04, 0.09, 0.15],
})

df["unit_cost"] = df["COGS"] / df["Units Sold"]
price_tier = df[["Segment", "Sale Price", "unit_cost"]].drop_duplicates()
price_tier = price_tier.sort_values(["Segment", "Sale Price"]).reset_index(drop=True)
price_tier["price_tier_id"] = price_tier.index + 1
price_tier = price_tier.merge(segment, left_on="Segment", right_on="segment_name")
price_tier = price_tier.rename(columns={"Sale Price": "sale_price"})
price_tier = price_tier[["price_tier_id", "segment_id", "sale_price", "unit_cost"]]

sale = df.merge(country, left_on="Country", right_on="country_name")
sale = sale.merge(product, left_on="Product", right_on="product_name")
sale = sale.merge(price_tier, left_on="Sale Price", right_on="sale_price")
sale = sale.merge(discount_band, left_on="Discount Band", right_on="band_name")
assert len(sale) == 1358

sale = sale.sort_values(["source_period", "source_row"])
sale["sale_date"] = sale["Date"].dt.strftime("%Y-%m-%d")
sale = sale.rename(columns={"Units Sold": "units_sold", "Discounts": "discounts"})
sale = sale[["source_period", "source_row", "sale_date", "country_id", "product_id",
             "price_tier_id", "discount_band_id", "units_sold", "discounts"]]

OLTP_DB.unlink(missing_ok=True)
conn = sqlite3.connect(OLTP_DB)
conn.execute("PRAGMA foreign_keys = ON")
conn.executescript((ROOT / "sql" / "oltp_schema.sql").read_text(encoding="utf-8"))

segment.to_sql("segment", conn, if_exists="append", index=False)
country.to_sql("country", conn, if_exists="append", index=False)
product.to_sql("product", conn, if_exists="append", index=False)
discount_band.to_sql("discount_band", conn, if_exists="append", index=False)
price_tier.to_sql("price_tier", conn, if_exists="append", index=False)
sale.to_sql("sale", conn, if_exists="append", index=False)
conn.commit()
conn.close()

print(f"oltp.db: sale = {len(sale)} rows")
