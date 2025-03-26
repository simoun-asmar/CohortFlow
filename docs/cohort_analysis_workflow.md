# Cohort Analysis Workflow

This file documents all the SQL queries used in this project, alongside the visualizations that help interpret the results.

---

## 📌 1. First Order per Customer

This query calculates, for each customer, the minimum (first) order date.

```sql
/* 
  Calculate the first order date for each customer.
  This is done by grouping by customer_id and selecting the earliest order_date (MIN).
*/

SELECT customer_id,
       MIN(order_date) as first_order_date  -- earliest purchase date for the customer
FROM bigquery_db_databricks.ecom_orders
GROUP BY customer_id
ORDER BY first_order_date;
```

## 📌 2. Second Order per Customer

This query calculates the second purchase date for each customer by identifying the earliest order date that comes after their first order.

```sql
/* 
   Compute, for each customer, the earliest order date 
   that is later than their first purchase date.
*/

SELECT 
      customer_id,
      order_date AS second_order_date

FROM (
    /* Assign a row number to each order per customer, ordered by date */
    SELECT customer_id,
           order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS row_number
    FROM bigquery_db_databricks.ecom_orders
)

/* Filter to get only the second order per customer */
WHERE row_number = 2;
```
## 📌 3. First vs Second Order Gap

This query shows the first purchase date, the second purchase date (if available), and calculates the number of days between both for each customer.

```sql
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
```
## 📌 4. Create cohort_analysis Table

This query creates a new table called cohort_analysis in the Databricks database.
It contains the first and second purchase dates per customer and the number of days between both.

```sql
/* 
   Create a new table `cohort_analysis` in the Databricks database 
   using the result of the previous query that includes:
   - first purchase date
   - second purchase date
   - days between the two
*/

-- Create a new table from the query result
CREATE TABLE cohort_analysis AS  

-- Step 1: Get the first order date per customer
WITH first_order_date AS (
  SELECT 
    customer_id,
    MIN(order_date) AS first_order_date
  FROM bigquery_db_databricks.ecom_orders
  GROUP BY customer_id
  ORDER BY first_order_date
),

-- Step 2: Get the second order date using row_number
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

-- Step 3: Join both sets and calculate the number of days between the first and second order
SELECT
  f.customer_id,
  f.first_order_date,
  s.second_order_date,
  DATE_DIFF(s.second_order_date, f.first_order_date) AS days_between_first_and_seconde_order
FROM first_order_date AS f 
LEFT JOIN second_order_date AS s
  ON f.customer_id = s.customer_id;
```
## 📌 5. Retention Rate by Cohort

This query calculates monthly customer retention rates by identifying users who placed a second order within 1, 2, and 3 months after their first purchase.
Customers are grouped into monthly cohorts based on their first order date.

```sql
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
    WHERE months_between_first_and_seconde_order = 0 
       OR months_between_first_and_seconde_order = 1
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
```

📊 Underneath, you can see the visualization created directly in Databricks, showing retention rates across customer cohorts over time.

![Retention Rate by Cohort](./dashboard/Retention_rate_by_cohort.png)

## 📌 6. Repeat Purchase Rate by Cohort

This query calculates, for each monthly cohort, the percentage of customers who made at least a 2nd, 3rd, or 4th purchase.
It helps assess long-term customer engagement and purchase behavior over time.

```sql
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
```

📊 Underneath, you can see the visualization created directly in Databricks, showing repeat purchase behavior across cohorts.

![Repeat Purchase Rates by Cohort](./dashboard/Repeat_purchase_rates_by_cohort.png)

## 📌 7. Cohort Size by Month

This query calculates the number of new customers acquired each month, based on the date of their first purchase.
It gives insight into customer acquisition trends over time.

```sql
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
```
📊 Underneath, you can see the visualization created directly in Databricks, showing the number of new customers acquired each month.

![Cohort Size by Month](./dashboard/Cohort_size_by_month.png)
