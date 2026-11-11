SELECT
    d.data_period,
    count(*)                AS sales_lines,
    round(sum(f.sales), 2)  AS sales,
    round(sum(f.profit), 2) AS profit
FROM fact_sales f
JOIN dim_date d ON d.date_key = f.date_key
GROUP BY d.data_period
ORDER BY d.data_period;
