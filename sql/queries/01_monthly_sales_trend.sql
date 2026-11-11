WITH monthly AS (
    SELECT d.year_month, sum(f.sales) AS sales
    FROM fact_sales f
    JOIN dim_date d USING (date_key)
    GROUP BY d.year_month
),
with_previous AS (
    SELECT year_month, sales,
           LAG(sales) OVER (ORDER BY year_month) AS previous_sales
    FROM monthly
)
SELECT
    year_month,
    round(sales, 2)                                          AS sales,
    round(sales - previous_sales, 2)                         AS change,
    round(100.0 * (sales - previous_sales) / previous_sales, 1) AS pct_change
FROM with_previous
ORDER BY year_month;
