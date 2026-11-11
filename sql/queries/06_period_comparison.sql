-- Question: is 2022-2023 new business, or a copy of 2020-2021?
-- Technique: compare the two periods with GROUP BY, and recompute the
-- average price from sums, because a price is non-additive.
SELECT
    d.data_period,
    count(*)                                    AS sales_lines,
    round(sum(f.sales), 2)                      AS sales,
    round(sum(f.profit), 2)                     AS profit,
    round(sum(f.gross_sales) / sum(f.units_sold), 2) AS avg_sale_price
FROM fact_sales f
JOIN dim_date d USING (date_key)
GROUP BY d.data_period
ORDER BY d.data_period;
