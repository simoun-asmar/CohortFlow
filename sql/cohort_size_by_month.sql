/* 
   Count the number of new customers acquired in each month.
   A new customer is identified by their first order date.
*/

-- Step 1: Identify the cohort month for each customer (month of their first order)
WITH first_order_date AS (
  SELECT 
    customer_id,
    DATE_TRUNC('MONTH', MIN(order_date))::DATE AS cohort_month
  FROM bigquery_db_databricks.ecom_orders
  GROUP BY customer_id
)

-- Step 2: Count how many customers had their first order in each cohort month
SELECT 
  cohort_month,
  COUNT(DISTINCT customer_id) AS total_customers
FROM first_order_date
GROUP BY cohort_month
ORDER BY cohort_month;
