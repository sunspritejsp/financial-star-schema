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

INSERT INTO dim_segment (segment_key, segment_name)
SELECT segment_id, segment_name FROM oltp.segment;

INSERT INTO dim_country (country_key, country_name)
SELECT country_id, country_name FROM oltp.country;

INSERT INTO dim_product (product_key, product_name, manufacturing_price)
SELECT product_id, product_name, manufacturing_price FROM oltp.product;

INSERT INTO dim_discount_band (discount_band_key, band_name, sort_order, min_rate, max_rate)
SELECT discount_band_id, band_name, sort_order, min_rate, max_rate FROM oltp.discount_band;

INSERT INTO fact_sales (oltp_sale_id, date_key, segment_key, country_key, product_key,
                        discount_band_key, units_sold, sale_price, unit_cost,
                        gross_sales, discounts, sales, cogs, profit)
SELECT
    s.sale_id,
    CAST(strftime('%Y%m%d', s.sale_date) AS INTEGER),
    pt.segment_id,
    s.country_id,
    s.product_id,
    s.discount_band_id,
    s.units_sold,
    pt.sale_price,
    pt.unit_cost,
    s.units_sold * pt.sale_price,
    s.discounts,
    s.units_sold * pt.sale_price - s.discounts,
    s.units_sold * pt.unit_cost,
    s.units_sold * pt.sale_price - s.discounts - s.units_sold * pt.unit_cost
FROM oltp.sale s
JOIN oltp.price_tier pt ON pt.price_tier_id = s.price_tier_id
ORDER BY s.sale_id;

COMMIT;
