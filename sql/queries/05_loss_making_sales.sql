SELECT
    s.segment_name,
    b.band_name,
    count(*)                AS sales_lines,
    round(sum(f.profit), 2) AS loss
FROM fact_sales f
JOIN dim_segment s       ON s.segment_key       = f.segment_key
JOIN dim_discount_band b ON b.discount_band_key = f.discount_band_key
WHERE f.profit < 0
GROUP BY s.segment_name, b.band_name, b.sort_order
ORDER BY b.sort_order;
