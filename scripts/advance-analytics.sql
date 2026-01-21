--7. Change Over Time Analysis

--analyze sales performance over time
SELECT 
DATETRUNC(month, order_date) as order_date,
SUM(sales_amount) as total_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quanity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date)

-- HOW many new customer were added each year
SELECT
DATETRUNC(year, create_date) as create_year,
COUNT(customer_key) as total_customer
FROM gold.dim_customer
GROUP BY DATETRUNC(year, create_date) 
ORDER BY DATETRUNC(year, create_date)
---------------------------------------------
--8. Cumulative Analysis

--CALCULATE THE TOTAL SALES PER MONTH AND RUNNING TOTAL OF SALES OVER TIME
SELECT
order_date,
total_sales,
SUM(total_sales) OVER (ORDER BY order_date) as running_total_sales,
AVG(avg_price) OVER (ORDER BY order_date) as moving_avg_price
FROM(
SELECT
DATETRUNC(month, order_date) as order_date,
SUM(sales_amount) as total_sales,
AVG(price) as avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
)t
-------------------------------------------
--9. Performance Analysis (Year-over-Year, Month-over-Month)

 /*analyze the yearly performance of product by comparing their sales
 to both the avg sales performance ot the product and the previous years sales*/
WITH yearly_product_sales AS(
 SELECT 
 YEAR(f.order_date) AS order_year,
 p.product_name,
 SUM(f.sales_amount) as current_sales
 FROM gold.fact_sales f
 LEFT JOIN gold.dim_products p
 ON f.product_key = p.product_key
 WHERE f.order_date IS NOT NULL
 GROUP BY YEAR(f.order_date),
 p.product_name
 )

 SELECT
 order_year,
 product_name,
 current_sales,
 AVG(current_sales) OVER (PARTITION BY product_name) avg_sales,
 current_sales - AVG(current_sales) OVER (PARTITION BY product_name) as diff_avg,
 CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above AVG' 
      WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below AVG' 
      ELSE 'AVG'
END avg_change,
-- year over year analysis
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year)py_sales,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) as diff_py,
CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'increase' 
      WHEN current_sales -LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'decrease' 
      ELSE 'no change'
END py_change
 FROM yearly_product_sales
 ORDER BY product_name , order_year
 ------------------------------------------------
 --10. Part-to-Whole Analysis
 
 --which categories contribute the most to overall sales
 WITH category_sales AS (
 SELECT
 category,
 SUM(sales_amount) total_sales
 FROM gold.fact_sales f
 LEFT JOIN gold.dim_products p
 ON p.product_key = f.product_key
 GROUP BY category )

 SELECT
 category,
 total_sales,
 SUM(total_sales) OVER () overall_sales,
 CONCAT(ROUND((CAST(total_sales AS FLOAT)/ SUM(total_sales)OVER())*100, 2),'%') AS per_of_total
 FROM category_sales
 ORDER BY total_sales DESC
 ----------------------------------------
--11. Data Segmentation Analysis

/*segment product into cost range 
and count how many product fall into each segmant*/
WITH product_segments as(
SELECT 
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'below 100'
     WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	 ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)

SELECT
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC


/*group customers into 3 segments based on their spending behavior:
-vip:cust with at least 12 month of history and spending more than 5,000.
-regular:cust with at least 12 month of history but spending 5,000 or less.
-new:cust with a lifespan less than 12 month.
and find the total number of customer by each group */
WITH customer_spending AS (
    SELECT
        c.customer_key,
        SUM(f.sales_amount) AS total_spending,
        MIN(order_date) AS first_order,
        MAX(order_date) AS last_order,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customer c
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT 
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT 
        customer_key,
        CASE 
            WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_spending
) AS segmented_customers
GROUP BY customer_segment
ORDER BY total_customers DESC;
