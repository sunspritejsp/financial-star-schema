SELECT
    s.segment_name,
    round(sum(f.sales), 2)                        AS sales,
    round(sum(f.profit), 2)                       AS profit,
    round(100.0 * sum(f.profit) / sum(f.sales), 1) AS margin_pct
FROM fact_sales f
JOIN dim_segment s ON s.segment_key = f.segment_key
GROUP BY s.segment_name
ORDER BY profit DESC;
