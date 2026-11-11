-- OLTP schema in 3NF for the sales and manufacturing spreadsheets.
-- Safe to run more than once: every object uses IF NOT EXISTS.
-- Run PRAGMA foreign_keys = ON on the connection before inserting.

CREATE TABLE IF NOT EXISTS segment (
    segment_id   INTEGER PRIMARY KEY,
    segment_name TEXT    NOT NULL UNIQUE CHECK (length(trim(segment_name)) > 0)
) STRICT;

CREATE TABLE IF NOT EXISTS country (
    country_id   INTEGER PRIMARY KEY,
    country_name TEXT    NOT NULL UNIQUE CHECK (length(trim(country_name)) > 0)
) STRICT;

-- Manufacturing Price depends only on the product, so it is stored here.
CREATE TABLE IF NOT EXISTS product (
    product_id          INTEGER PRIMARY KEY,
    product_name        TEXT    NOT NULL UNIQUE CHECK (length(trim(product_name)) > 0),
    manufacturing_price REAL    NOT NULL CHECK (manufacturing_price > 0)
) STRICT;

-- A discount band is a range of discount rates (Discounts / Gross Sales).
CREATE TABLE IF NOT EXISTS discount_band (
    discount_band_id INTEGER PRIMARY KEY,
    band_name        TEXT    NOT NULL UNIQUE,
    sort_order       INTEGER NOT NULL UNIQUE,
    min_rate         REAL    NOT NULL CHECK (min_rate >= 0),
    max_rate         REAL    NOT NULL CHECK (max_rate <= 1),
    CHECK (min_rate <= max_rate)
) STRICT;

-- Each sale price belongs to exactly one tier, which fixes the segment
-- and the cost per unit. Keeping them here removes the transitive
-- dependency sale -> sale_price -> (segment, unit_cost).
CREATE TABLE IF NOT EXISTS price_tier (
    price_tier_id INTEGER PRIMARY KEY,
    segment_id    INTEGER NOT NULL REFERENCES segment (segment_id),
    sale_price    REAL    NOT NULL UNIQUE CHECK (sale_price > 0),
    unit_cost     REAL    NOT NULL CHECK (unit_cost > 0)
) STRICT;

-- One row per sale line. A sales row and its manufacturing row describe
-- the same sale (they pair 1:1 by position), so they form one entity.
-- Gross Sales, Sales, COGS and Profit are derived, so they live in the
-- v_sale view below instead of being stored.
CREATE TABLE IF NOT EXISTS sale (
    sale_id          INTEGER PRIMARY KEY,
    source_period    TEXT    NOT NULL CHECK (source_period IN ('2020-2021', '2022-2023')),
    source_row       INTEGER NOT NULL CHECK (source_row >= 0),
    sale_date        TEXT    NOT NULL CHECK (
                         sale_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-01'
                         AND date(sale_date) = sale_date
                     ),
    country_id       INTEGER NOT NULL REFERENCES country (country_id),
    product_id       INTEGER NOT NULL REFERENCES product (product_id),
    price_tier_id    INTEGER NOT NULL REFERENCES price_tier (price_tier_id),
    discount_band_id INTEGER NOT NULL REFERENCES discount_band (discount_band_id),
    units_sold       REAL    NOT NULL CHECK (units_sold > 0),
    discounts        REAL    NOT NULL CHECK (discounts >= 0),
    UNIQUE (source_period, source_row)
) STRICT;

CREATE INDEX IF NOT EXISTS ix_sale_date    ON sale (sale_date);
CREATE INDEX IF NOT EXISTS ix_sale_country ON sale (country_id);
CREATE INDEX IF NOT EXISTS ix_sale_product ON sale (product_id);
CREATE INDEX IF NOT EXISTS ix_sale_tier    ON sale (price_tier_id);
CREATE INDEX IF NOT EXISTS ix_sale_band    ON sale (discount_band_id);

-- The sale with its descriptions and every derived amount, as in the
-- original spreadsheets.
CREATE VIEW IF NOT EXISTS v_sale AS
SELECT
    s.sale_id,
    s.source_period,
    s.source_row,
    s.sale_date,
    sg.segment_name,
    c.country_name,
    p.product_name,
    db.band_name                                       AS discount_band,
    s.units_sold,
    pt.sale_price,
    p.manufacturing_price,
    pt.unit_cost,
    s.units_sold * pt.sale_price                       AS gross_sales,
    s.discounts,
    s.units_sold * pt.sale_price - s.discounts         AS sales,
    s.units_sold * pt.unit_cost                        AS cogs,
    s.units_sold * (pt.sale_price - pt.unit_cost) - s.discounts AS profit
FROM sale s
JOIN price_tier    pt ON pt.price_tier_id    = s.price_tier_id
JOIN segment       sg ON sg.segment_id       = pt.segment_id
JOIN country       c  ON c.country_id        = s.country_id
JOIN product       p  ON p.product_id        = s.product_id
JOIN discount_band db ON db.discount_band_id = s.discount_band_id;
