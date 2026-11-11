-- Question: which products bring the most profit in each country?
-- Technique: RANK window function, partitioned by country.
WITH product_profit AS (
    SELECT c.country_name, p.product_name, sum(f.profit) AS profit
    FROM fact_sales f
    JOIN dim_country c USING (country_key)
    JOIN dim_product p USING (product_key)
    GROUP BY c.country_name, p.product_name
),
ranked AS (
    SELECT country_name, product_name, profit,
           RANK() OVER (PARTITION BY country_name ORDER BY profit DESC) AS profit_rank
    FROM product_profit
)
SELECT country_name, profit_rank, product_name, round(profit, 2) AS profit
FROM ranked
WHERE profit_rank <= 2
ORDER BY country_name, profit_rank;
