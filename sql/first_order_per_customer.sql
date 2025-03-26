/* 
  Calculate the first order date for each customer.
  This is done by grouping by customer_id and selecting the earliest order_date (MIN).
*/

SELECT customer_id,
       MIN(order_date) as first_order_date  -- earliest purchase date for the customer
FROM bigquery_db_databricks.ecom_orders
GROUP BY customer_id
ORDER BY first_order_date;
