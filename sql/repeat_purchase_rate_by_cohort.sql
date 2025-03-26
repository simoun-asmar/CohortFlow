/* 
   For each customer, calculate the cohort month (based on first purchase) 
   and total number of orders.
   Then group customers into monthly cohorts and compute repeat purchase rates
   — the percentage of customers who placed at least a 2nd, 3rd, and 4th order.
*/

-- Step 1: Compute each customer's cohort month and their total number of orders
WITH first_order_date AS (
  SELECT 
    customer_id,
    DATE_TRUNC('MONTH', MIN(order_date))::DATE AS cohort_month,
    COUNT(order_id) AS total_orders
  FROM bigquery_db_databricks.ecom_orders
  GROUP BY customer_id
)

-- Step 2: For each cohort, calculate the percentage of customers with at least:
-- a 2nd, 3rd, and 4th order (repeat purchase behavior)
SELECT 
  cohort_month,
  ROUND(COUNT(customer_id) FILTER (
    WHERE total_orders >= 2
  ) / COUNT(DISTINCT customer_id), 2) AS repeat_rate_2nd_order,

  ROUND(COUNT(customer_id) FILTER (
    WHERE total_orders >= 3
  ) / COUNT(DISTINCT customer_id), 2) AS repeat_rate_3nd_order,

  ROUND(COUNT(customer_id) FILTER (
    WHERE total_orders >= 4
  ) / COUNT(DISTINCT customer_id), 2) AS repeat_rate_4th_order

FROM first_order_date
GROUP BY cohort_month
ORDER BY cohort_month;
