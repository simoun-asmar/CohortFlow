/* 
   Include the customer’s first purchase date, second purchase date, 
   and the number of days between these dates.
*/

-- Step 1: Get the first order date per customer
WITH first_order_date AS (
  SELECT 
    customer_id,
    MIN(order_date) AS first_order_date
  FROM bigquery_db_databricks.ecom_orders
  GROUP BY customer_id
  ORDER BY first_order_date
),

-- Step 2: Get the second order date per customer using row_number
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
)

-- Step 3: Join both datasets and calculate days between first and second order
SELECT
  f.customer_id,
  f.first_order_date,
  s.second_order_date,
  DATE_DIFF(s.second_order_date, f.first_order_date) AS days_between_first_and_seconde_order
FROM first_order_date AS f 
LEFT JOIN second_order_date AS s
  ON f.customer_id = s.customer_id;
