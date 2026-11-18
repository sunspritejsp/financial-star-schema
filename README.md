# Financial Star Schema

Loads sales spreadsheets into a relational database, then into a star schema, and answers business questions with SQL. Built with Python, Pandas and SQLite.

> The data is anonymized and altered sample data, so the results don't reflect a real business.

## Run it

```bash
conda create -n star-schema python=3.13 -y
conda activate star-schema
python -m pip install -r requirements.txt
python run_all.py
```

run_all.py rebuilds both databases from the spreadsheets and prints the result of every query.

## How it works

1. **Clean:** Pandas cleans the four spreadsheets (typos, duplicates, a merged column) and loads them into `oltp.db`, a normalized database in 3NF.
2. **ETL:** sql/etl.sql loads the star schema in dw.db: one fact table (`fact_sales`, 1,358 rows) and five dimensions.
3. **Query:** six analytical queries in sql/queries/ answer business questions.

## Main results

- **Public Sector** brings in 67% of total profit.
- **Corporate** loses money on every product.
- **Discounts** cut the margin from 19.9% to 7.1%.
- **2022-2023** repeats the 2020-2021 data, so the two periods can't be compared as growth.
