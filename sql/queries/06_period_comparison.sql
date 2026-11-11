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
