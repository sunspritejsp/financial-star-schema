# Financial Star Schema

Course project for a databases class, also intended for the owner's GitHub portfolio. It builds a relational database from spreadsheets, models it as a star or snowflake schema, loads it through ETL, and runs analytical queries.

**Deadline: 2026-11-12.**

## How to work with the owner

Act as a Senior Data Architect with ten years of experience, mentoring the owner through each step.

- Let the owner do the work. Don't give answers straight away.
- When they're stuck, start with a hint. Show code only if they ask.
- Review their work at each checkpoint, and push back where needed.
- Don't write project deliverables unless they ask you to.
- Don't reveal answers to the open Step 1 questions. Check their conclusions against the data instead.

## Assignment

Use a relational database and build its equivalent star or snowflake model. Load the data from the relational database into the data warehouse, then run analytical queries on it.

The presentation must describe:
1. The relational database, its context and its model
2. The proposed data warehouse model
3. The loading process from OLTP to OLAP (ETL scripts)
4. The analytical queries run on the warehouse

## Set up on a new machine

```bash
git clone git@github.com:sunspritejsp/financial-star-schema.git
cd financial-star-schema
conda create -n star-schema python=3.13 -y
conda activate star-schema
python -m pip install -r requirements.txt
git config user.name "sunspritejsp"
git config user.email "166426856+sunspritejsp@users.noreply.github.com"
```

Then:
1. Open this folder in VS Code.
2. Run **Python: Select Interpreter** and choose `star-schema`.
3. Open a new terminal and run `which python` to confirm it points to that environment.

Always commit with the noreply address above. Run `git log -1 --format='%ae'` to check it.

## Stack and layout

- Python and Pandas for the migration from spreadsheets to the OLTP database
- SQLite for both databases: `oltp.db` and `dw.db`, connected with `ATTACH DATABASE`
- `.db` files are generated and are not committed

| Path | Contents |
|---|---|
| `data/raw/` | The four source spreadsheets |
| `src/` | Python code |
| `sql/` | Schemas and analytical queries |
| `docs/` | Data-quality notes and diagrams |

SQLite notes:
- There is no `ROLLUP` or `CUBE`, so build subtotals with `UNION ALL`.
- Run `PRAGMA foreign_keys = ON` on every connection.
- Use `STRICT` tables.
- Store dates as ISO `TEXT` and money as `REAL`, and allow a small tolerance when comparing totals.

## Data

The files are anonymized and altered, so results don't reflect a real business. Say so in the README and the presentation. Don't describe the data's origin in this repo.

Sales and Manufacturing files exist for two periods, 2020-2021 and 2022-2023, covering Sep 2020 to Dec 2023.

Known traps:
- Sales and Manufacturing rows pair up 1:1 by position, and there is no business key.
- The 2020-2021 files merge `Country,Product` into one column. The 2022-2023 files split it.
- `Segment` has typos, and `Country` has a case error.
- The 2020-2021 files have 15 exact duplicate rows, at data positions 700-714 (zero-based).
- `Discount Band` has the literal value `"None"`. Read it with `keep_default_na=False`.
- `Product_Name` is completely empty, and the `' Sales'` header has a leading space.
- `Units Sold` can have decimals.
- Three of the four files have blank rows up to row 1000, which pandas skips.

Established facts:
- After removing the duplicates, the target is exactly **1,358 sales** (700 + 658).
- These hold on every row: `Gross Sales = Units Sold × Sale Price`, `Sales = Gross Sales − Discounts`, `Profit = Sales − COGS`.
- `COGS` is not `Units Sold × Manufacturing Price` (about 23% of rows match), so it can't be dropped as derived.
- Segment × Country × Product × Month is not a unique grain, even with Discount Band and Sale Price added.
- 2020 starts in September, so don't compare it directly with all of 2021.

## Work plan

**Status: Step 0 is done. Next is Step 1, which hasn't started.** Update this line as steps finish.

Suggested pacing: Nov 5 Steps 0-1, Nov 6 Steps 2-3, Nov 7 Step 4, Nov 8 Steps 5-6, Nov 9 Step 7, Nov 10 Step 8, Nov 11 Steps 9-10 and rehearsal.

If time runs short, cut in this order: README polish, then `run_all.py`, then the number of queries (keep at least `LAG`, `RANK`, a rollup and a pivot). Don't cut the reconciliation check in Step 7.

0. **Repo setup.** Done.
1. **Explore the data.** Write findings to `docs/data_quality.md`, with what was found, how many rows it affects and how to handle it. Questions:
   - How do the two periods' columns differ, and which column breaks 1NF?
   - Which text values are typos?
   - What changes in `Discount Band` with default pandas settings versus `keep_default_na=False`?
   - How many exact duplicates are there, where are they, and are both files affected in the same rows?
   - What determines `Sale Price` and COGS per unit?
   - Is 2022-2023 really new data, or 2020-2021 with different dates? What does that mean for year-over-year analysis?
2. **Design the OLTP model.** ER diagram in 3NF, justifying each table. Done when reviewed.
3. **Write `sql/oltp_schema.sql`** with primary keys, foreign keys, `CHECK` constraints and `STRICT`. Done when it runs twice without errors and a bad insert is rejected.
4. **Write the Pandas migration** to `oltp.db`. Done when there are exactly 1,358 sales and the three formulas hold on every row.
5. **Design the star schema.** Declare the grain, dimensions and measures, and decide between line level and aggregating. Done when the owner can defend the grain and each measure's additivity.
6. **Write `sql/dw_schema.sql` and generate `dim_date`.** Done when it builds from scratch.
7. **Write the ETL from OLTP to DW.** Load dimensions first, then the fact table, using SQL over `ATTACH` called from Python. Consider what happens on a re-run. Done when an automated script confirms that row counts and totals match.
8. **Write 5-6 analytical queries**, starting from business questions, with a line interpreting each result. Include a `UNION ALL` rollup, `LAG`, `RANK` and a `CASE` pivot.
9. **Make it one command** with `run_all.py` or a Makefile. Done when it rebuilds from a fresh clone.
10. **Write the README and slides** around the four presentation topics. Done when a stranger can understand and run the project from the README.
