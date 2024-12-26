-- Check the data
SELECT * FROM test.sales;

-- Number of missing ratings
SELECT 
    COUNT(review_rating) AS number_of_nulls
FROM test.sales
WHERE review_rating = '';

-- Total number of rows in the sales table
SELECT COUNT(customer_id) AS total_rows
FROM test.sales;

-- Number of unique customers
SELECT COUNT(DISTINCT customer_id) AS unique_customers
FROM test.sales;

-- Average rating, purchase amount, and total spending per year
SELECT 
    ROUND(AVG(review_rating), 2) AS avg_rating,
    ROUND(AVG(purchase_amount), 2) AS avg_purchase_amount,
    SUM(purchase_amount) AS total_spending,
    YEAR(date_purchase) AS year
FROM test.sales
GROUP BY year;

-- Total spending per year and rank customers by spending
WITH yearly_customer_spending AS (
    SELECT 
        customer_id, 
        SUM(purchase_amount) AS total_spending,
        YEAR(date_purchase) AS year
    FROM test.sales
    GROUP BY customer_id, YEAR(date_purchase)
),
ranked_customer_spending AS (
    SELECT 
        *,
        DENSE_RANK() OVER (PARTITION BY year ORDER BY total_spending DESC) AS dense_rank,
        RANK() OVER (PARTITION BY year ORDER BY total_spending DESC) AS rank
    FROM yearly_customer_spending
)
SELECT * 
FROM ranked_customer_spending;

-- Number of purchases per year
SELECT 
    YEAR(date_purchase) AS year, 
    COUNT(*) AS number_of_purchases
FROM test.sales
GROUP BY year;

-- Year-over-Year (YoY) change in total spending
SELECT 
    CONCAT(
        ROUND(
            SUM(CASE WHEN YEAR(date_purchase) = 2023 THEN purchase_amount ELSE 0 END) / 
            SUM(CASE WHEN YEAR(date_purchase) = 2022 THEN purchase_amount ELSE 0 END), 2
        ) * 100, '%'
    ) AS YoY_change
FROM test.sales;

-- Largest monthly purchase and Month-over-Month (MoM) change
WITH monthly_totals AS (
    SELECT 
        MONTH(date_purchase) AS month, 
        YEAR(date_purchase) AS year, 
        SUM(purchase_amount) AS total_spending
    FROM test.sales
    GROUP BY MONTH(date_purchase), YEAR(date_purchase)
),
monthly_changes AS (
    SELECT 
        *,
        ROUND(
            (total_spending - LAG(total_spending) OVER (ORDER BY year, month)) / 
            LAG(total_spending) OVER (ORDER BY year, month) * 100, 2
        ) AS percent_change
    FROM monthly_totals
)
SELECT * 
FROM monthly_changes;

-- Last year comparison by month
WITH monthly_spending AS (
    SELECT 
        YEAR(date_purchase) AS year,
        MONTH(date_purchase) AS month,
        SUM(purchase_amount) AS total_spending
    FROM test.sales
    GROUP BY YEAR(date_purchase), MONTH(date_purchase)
),
year_over_year_comparison AS (
    SELECT 
        previous.year AS last_year,
        current.year AS this_year,
        current.month,
        previous.total_spending AS last_year_spending,
        current.total_spending AS this_year_spending,
        CONCAT(
            ROUND(
                (current.total_spending - previous.total_spending) / previous.total_spending, 2
            ) * 100, '%'
        ) AS percent_change
    FROM monthly_spending AS previous
    JOIN monthly_spending AS current
    ON previous.year = current.year - 1 AND previous.month = current.month
)
SELECT * 
FROM year_over_year_comparison;

-- Most popular products
SELECT 
    item_purchased, 
    COUNT(*) AS number_of_items_sold
FROM test.sales
GROUP BY item_purchased
ORDER BY number_of_items_sold DESC;

-- Most and least frequently purchased items
WITH item_sales_counts AS (
    SELECT 
        item_purchased, 
        COUNT(*) AS number_of_items_sold
    FROM test.sales
    GROUP BY item_purchased
),
ranked_items AS (
    SELECT 
        item_purchased, 
        DENSE_RANK() OVER (ORDER BY number_of_items_sold DESC) AS rank
    FROM item_sales_counts
),
extreme_ranks AS (
    SELECT 
        MIN(rank) AS min_rank, 
        MAX(rank) AS max_rank
    FROM ranked_items
)
SELECT 
    ranked_items.item_purchased, 
    ranked_items.rank
FROM ranked_items
JOIN extreme_ranks
ON ranked_items.rank = extreme_ranks.min_rank OR ranked_items.rank = extreme_ranks.max_rank;

-- Average purchase amount for each type of item
WITH average_item_spending AS (
    SELECT 
        item_purchased, 
        ROUND(AVG(purchase_amount), 2) AS avg_purchase_amount
    FROM test.sales
    GROUP BY item_purchased
)
SELECT 
    *, 
    DENSE_RANK() OVER (ORDER BY avg_purchase_amount DESC) AS rank
FROM average_item_spending;

-- Items generating the highest total revenue
WITH sales_price_combination AS (
    SELECT * 
    FROM test.sales AS sales
    JOIN test.price_data AS prices
    ON sales.item_purchased = prices.Item
)
SELECT 
    Item, 
    SUM(purchase_amount * Price) AS total_revenue
FROM sales_price_combination
GROUP BY Item
ORDER BY total_revenue DESC;

-- Month-over-Month (MoM) revenue change
WITH monthly_sales_revenue AS (
    SELECT 
        DATE_FORMAT(date_purchase, '%Y-%m') AS month_year,
        SUM(Price * purchase_amount) AS total_revenue
    FROM test.sales AS sales
    JOIN test.price_data AS prices
    ON sales.item_purchased = prices.Item
    GROUP BY DATE_FORMAT(date_purchase, '%Y-%m')
),
monthly_revenue_changes AS (
    SELECT 
        *,
        CONCAT(
            ROUND(
                (total_revenue - LAG(total_revenue) OVER (ORDER BY month_year)) / 
                LAG(total_revenue) OVER (ORDER BY month_year) * 100, 2
            ), '%'
        ) AS percent_change
    FROM monthly_sales_revenue
)
SELECT * 
FROM monthly_revenue_changes;
