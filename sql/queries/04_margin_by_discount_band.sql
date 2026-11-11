SELECT
    b.band_name,
    count(*)                                                AS sales_lines,
    round(100.0 * sum(f.discounts) / sum(f.gross_sales), 1) AS discount_pct,
    round(100.0 * sum(f.profit) / sum(f.sales), 1)          AS margin_pct
FROM fact_sales f
JOIN dim_discount_band b ON b.discount_band_key = f.discount_band_key
GROUP BY b.band_name, b.sort_order
ORDER BY b.sort_order;
