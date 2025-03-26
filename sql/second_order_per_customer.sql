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
