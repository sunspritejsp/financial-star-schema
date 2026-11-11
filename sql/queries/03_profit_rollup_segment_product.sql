WITH rollup AS (
    SELECT segment_name, product_name, sum(sales) AS sales, sum(profit) AS profit
    FROM fact_sales
    JOIN dim_segment USING (segment_key)
    JOIN dim_product USING (product_key)
    GROUP BY segment_name, product_name

    UNION ALL

    SELECT segment_name, NULL, sum(sales), sum(profit)
    FROM fact_sales
    JOIN dim_segment USING (segment_key)
    GROUP BY segment_name

    UNION ALL

    SELECT NULL, NULL, sum(sales), sum(profit)
    FROM fact_sales
)
SELECT
    coalesce(segment_name, 'All segments') AS segment,
    coalesce(product_name, 'All products') AS product,
    round(profit, 2)                       AS profit,
    round(100.0 * profit / sales, 1)       AS margin_pct
FROM rollup
ORDER BY segment_name NULLS LAST, product_name NULLS LAST;
