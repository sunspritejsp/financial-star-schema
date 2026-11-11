SELECT
    c.country_name,
    p.product_name,
    round(sum(f.profit), 2) AS profit,
    RANK() OVER (PARTITION BY c.country_name ORDER BY sum(f.profit) DESC) AS profit_rank
FROM fact_sales f
JOIN dim_country c ON c.country_key = f.country_key
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY c.country_name, p.product_name
ORDER BY c.country_name, profit_rank;
