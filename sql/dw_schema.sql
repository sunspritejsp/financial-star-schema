CREATE TABLE IF NOT EXISTS dim_date (
    date_key     INTEGER PRIMARY KEY,
    full_date    TEXT    NOT NULL UNIQUE CHECK (date(full_date) = full_date),
    year         INTEGER NOT NULL,
    quarter      INTEGER NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month_number INTEGER NOT NULL CHECK (month_number BETWEEN 1 AND 12),
    month_name   TEXT    NOT NULL,
    year_month   TEXT    NOT NULL UNIQUE,
    data_period  TEXT    NOT NULL CHECK (data_period IN ('2020-2021', '2022-2023'))
) STRICT;

CREATE TABLE IF NOT EXISTS dim_segment (
    segment_key  INTEGER PRIMARY KEY,
    segment_name TEXT    NOT NULL UNIQUE
) STRICT;

CREATE TABLE IF NOT EXISTS dim_country (
    country_key  INTEGER PRIMARY KEY,
    country_name TEXT    NOT NULL UNIQUE
) STRICT;

CREATE TABLE IF NOT EXISTS dim_product (
    product_key         INTEGER PRIMARY KEY,
    product_name        TEXT    NOT NULL UNIQUE,
    manufacturing_price REAL    NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS dim_discount_band (
    discount_band_key INTEGER PRIMARY KEY,
    band_name         TEXT    NOT NULL UNIQUE,
    sort_order        INTEGER NOT NULL UNIQUE,
    min_rate          REAL    NOT NULL,
    max_rate          REAL    NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS fact_sales (
    sale_key          INTEGER PRIMARY KEY,
    oltp_sale_id      INTEGER NOT NULL UNIQUE,
    date_key          INTEGER NOT NULL REFERENCES dim_date (date_key),
    segment_key       INTEGER NOT NULL REFERENCES dim_segment (segment_key),
    country_key       INTEGER NOT NULL REFERENCES dim_country (country_key),
    product_key       INTEGER NOT NULL REFERENCES dim_product (product_key),
    discount_band_key INTEGER NOT NULL REFERENCES dim_discount_band (discount_band_key),
    units_sold        REAL    NOT NULL CHECK (units_sold > 0),
    sale_price        REAL    NOT NULL CHECK (sale_price > 0),
    unit_cost         REAL    NOT NULL CHECK (unit_cost > 0),
    gross_sales       REAL    NOT NULL,
    discounts         REAL    NOT NULL CHECK (discounts >= 0),
    sales             REAL    NOT NULL,
    cogs              REAL    NOT NULL,
    profit            REAL    NOT NULL
) STRICT;

CREATE INDEX IF NOT EXISTS ix_fact_date    ON fact_sales (date_key);
CREATE INDEX IF NOT EXISTS ix_fact_segment ON fact_sales (segment_key);
CREATE INDEX IF NOT EXISTS ix_fact_country ON fact_sales (country_key);
CREATE INDEX IF NOT EXISTS ix_fact_product ON fact_sales (product_key);
CREATE INDEX IF NOT EXISTS ix_fact_band    ON fact_sales (discount_band_key);
