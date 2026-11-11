BEGIN;

DELETE FROM fact_sales;
DELETE FROM dim_date;
DELETE FROM dim_segment;
DELETE FROM dim_country;
DELETE FROM dim_product;
DELETE FROM dim_discount_band;

WITH RECURSIVE months (d) AS (
    SELECT min(sale_date) FROM oltp.sale
    UNION ALL
    SELECT date(d, '+1 month') FROM months
    WHERE d < (SELECT max(sale_date) FROM oltp.sale)
)
INSERT INTO dim_date (date_key, full_date, year, quarter, month_number,
                      month_name, year_month, data_period)
SELECT
    CAST(strftime('%Y%m%d', d) AS INTEGER),
    d,
    CAST(strftime('%Y', d) AS INTEGER),
    (CAST(strftime('%m', d) AS INTEGER) + 2) / 3,
    CAST(strftime('%m', d) AS INTEGER),
    CASE CAST(strftime('%m', d) AS INTEGER)
        WHEN 1 THEN 'January'   WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April'     WHEN 5 THEN 'May'      WHEN 6 THEN 'June'
        WHEN 7 THEN 'July'      WHEN 8 THEN 'August'   WHEN 9 THEN 'September'
        WHEN 10 THEN 'October'  WHEN 11 THEN 'November' ELSE 'December'
    END,
    strftime('%Y-%m', d),
    CASE WHEN d < '2022-01-01' THEN '2020-2021' ELSE '2022-2023' END
FROM months;

INSERT INTO dim_segment (segment_name)
SELECT segment_name FROM oltp.segment ORDER BY segment_name;

INSERT INTO dim_country (country_name)
SELECT country_name FROM oltp.country ORDER BY country_name;

INSERT INTO dim_product (product_name, manufacturing_price)
SELECT product_name, manufacturing_price FROM oltp.product ORDER BY product_name;

INSERT INTO dim_discount_band (band_name, sort_order, min_rate, max_rate)
SELECT band_name, sort_order, min_rate, max_rate
FROM oltp.discount_band ORDER BY sort_order;

INSERT INTO fact_sales (oltp_sale_id, date_key, segment_key, country_key, product_key,
                        discount_band_key, units_sold, sale_price, unit_cost,
                        gross_sales, discounts, sales, cogs, profit)
SELECT
    s.sale_id,
    dd.date_key,
    ds.segment_key,
    dc.country_key,
    dp.product_key,
    db.discount_band_key,
    s.units_sold,
    pt.sale_price,
    pt.unit_cost,
    s.units_sold * pt.sale_price,
    s.discounts,
    s.units_sold * pt.sale_price - s.discounts,
    s.units_sold * pt.unit_cost,
    s.units_sold * (pt.sale_price - pt.unit_cost) - s.discounts
FROM oltp.sale s
JOIN oltp.price_tier    pt  ON pt.price_tier_id     = s.price_tier_id
JOIN oltp.segment       sg  ON sg.segment_id        = pt.segment_id
JOIN oltp.country       c   ON c.country_id         = s.country_id
JOIN oltp.product       p   ON p.product_id         = s.product_id
JOIN oltp.discount_band b   ON b.discount_band_id   = s.discount_band_id
JOIN dim_date           dd  ON dd.full_date         = s.sale_date
JOIN dim_segment        ds  ON ds.segment_name      = sg.segment_name
JOIN dim_country        dc  ON dc.country_name      = c.country_name
JOIN dim_product        dp  ON dp.product_name      = p.product_name
JOIN dim_discount_band  db  ON db.band_name         = b.band_name
ORDER BY s.sale_id;

COMMIT;
