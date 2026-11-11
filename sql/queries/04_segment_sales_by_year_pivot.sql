SELECT
    s.segment_name,
    round(sum(CASE WHEN d.year = 2020 THEN f.sales ELSE 0 END), 2) AS sales_2020,
    round(sum(CASE WHEN d.year = 2021 THEN f.sales ELSE 0 END), 2) AS sales_2021,
    round(sum(CASE WHEN d.year = 2022 THEN f.sales ELSE 0 END), 2) AS sales_2022,
    round(sum(CASE WHEN d.year = 2023 THEN f.sales ELSE 0 END), 2) AS sales_2023,
    round(sum(f.sales), 2)                                          AS total_sales
FROM fact_sales f
JOIN dim_segment s USING (segment_key)
JOIN dim_date d USING (date_key)
GROUP BY s.segment_name
ORDER BY total_sales DESC;
