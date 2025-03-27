/* 
   For each customer, calculate the first and second purchase dates 
   from the ecom_orders table. 
   Then group customers into monthly cohorts based on the first purchase date,
   and calculate retention rates within 1, 2, and 3 months after their first order.
*/

-- Step 1: Get each customer's first order date
WITH first_order_date AS (
  SELECT 
    customer_id,
    MIN(order_date) AS first_order_date
  FROM bigquery_db_databricks.ecom_orders
  GROUP BY customer_id
  ORDER BY first_order_date
),

-- Step 2: Get each customer's second order date using row_number()
second_order_date AS (
  SELECT 
    customer_id,
    order_date AS second_order_date
  FROM (
    SELECT 
      customer_id,
      order_date,
      ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS row_number
    FROM bigquery_db_databricks.ecom_orders
  )
  WHERE row_number = 2
),

-- Step 3: Combine first and second order info, compute cohort month and time between orders
monthly_cohorts AS (
  SELECT
    f.customer_id AS customer_id,
    DATE_TRUNC('MONTH', f.first_order_date)::DATE AS cohort_month,
    DATE_TRUNC('MONTH', s.second_order_date)::DATE AS second_order_month,
    DATE_DIFF(MONTH, f.first_order_date, s.second_order_date) AS months_between_first_and_seconde_order
  FROM first_order_date AS f 
  LEFT JOIN second_order_date AS s
    ON f.customer_id = s.customer_id
)

-- Step 4: Calculate retention rates for customers who placed a second order within 1, 2, or 3 months
SELECT 
  cohort_month,
  COUNT(*) AS total_customers,
  ROUND(COUNT(customer_id) FILTER (
    WHERE months_between_first_and_seconde_order <= 1
  ) / COUNT(DISTINCT customer_id), 2) AS retention_rate_1m,
  ROUND(COUNT(customer_id) FILTER (
    WHERE months_between_first_and_seconde_order <= 2
  ) / COUNT(DISTINCT customer_id), 2) AS retention_rate_2m,
  ROUND(COUNT(customer_id) FILTER (
    WHERE months_between_first_and_seconde_order <= 3
  ) / COUNT(DISTINCT customer_id), 2) AS retention_rate_3m
FROM monthly_cohorts
GROUP BY cohort_month
ORDER BY cohort_month;
