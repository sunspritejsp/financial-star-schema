SELECT
    b.band_name,
    count(*)                                                AS sales_lines,
    round(100.0 * sum(f.discounts) / sum(f.gross_sales), 2) AS discount_rate_pct,
    round(100.0 * sum(f.profit) / sum(f.sales), 2)          AS margin_pct,
    sum(CASE WHEN f.profit < 0 THEN 1 ELSE 0 END)           AS loss_lines,
    round(sum(CASE WHEN f.profit < 0 THEN f.profit ELSE 0 END), 2) AS loss_amount
FROM fact_sales f
JOIN dim_discount_band b USING (discount_band_key)
GROUP BY b.band_name, b.sort_order
ORDER BY b.sort_order;
