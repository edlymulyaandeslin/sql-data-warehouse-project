/*
===============================================================================
Gold Layer - Data Quality Checks
===============================================================================

Purpose:
    Validate the quality, uniqueness, completeness, and relationships of
    the Gold layer dimensions and fact table.

===============================================================================
*/


-- ============================================================================
-- 1. CUSTOMER DIMENSION
-- ============================================================================

-- Check for duplicate customer keys
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;


-- Check for duplicate customer IDs
SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- Check for NULL customer keys or IDs
SELECT *
FROM gold.dim_customers
WHERE customer_key IS NULL
   OR customer_id IS NULL;


-- Check for NULL customer number
SELECT *
FROM gold.dim_customers
WHERE customer_number IS NULL
   OR TRIM(customer_number) = '';


-- Check for invalid gender values
SELECT *
FROM gold.dim_customers
WHERE gender NOT IN ('Male', 'Female', 'n/a');


-- Check for future birth dates
SELECT *
FROM gold.dim_customers
WHERE birthdate > CAST(GETDATE() AS DATE);


-- Check for future customer creation dates
SELECT *
FROM gold.dim_customers
WHERE create_date > CAST(GETDATE() AS DATE);



-- ============================================================================
-- 2. PRODUCT DIMENSION
-- ============================================================================

-- Check for duplicate product keys
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


-- Check for duplicate product IDs
SELECT
    product_id,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- Check for duplicate product numbers
SELECT
    product_number,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;


-- Check for NULL product keys or IDs
SELECT *
FROM gold.dim_products
WHERE product_key IS NULL
   OR product_id IS NULL;


-- Check for NULL product numbers
SELECT *
FROM gold.dim_products
WHERE product_number IS NULL
   OR TRIM(product_number) = '';


-- Check for NULL product names
SELECT *
FROM gold.dim_products
WHERE product_name IS NULL
   OR TRIM(product_name) = '';


-- Check for invalid product cost
SELECT *
FROM gold.dim_products
WHERE cost IS NULL
   OR cost < 0;


-- Check for NULL category information
SELECT *
FROM gold.dim_products
WHERE category_id IS NULL
   OR category IS NULL
   OR subcategory IS NULL;


-- Check for invalid product line
SELECT *
FROM gold.dim_products
WHERE product_line NOT IN (
    'Mountain',
    'Road',
    'Other Sales',
    'Touring',
    'n/a'
);


-- Check for future product start dates
SELECT *
FROM gold.dim_products
WHERE start_date > CAST(GETDATE() AS DATE);



-- ============================================================================
-- 3. SALES FACT
-- ============================================================================

-- Check for NULL order numbers
SELECT *
FROM gold.fact_sales
WHERE order_number IS NULL
   OR TRIM(order_number) = '';


-- Check for NULL dimension keys
SELECT *
FROM gold.fact_sales
WHERE product_key IS NULL
   OR customer_key IS NULL;


-- Check for invalid sales dates
SELECT *
FROM gold.fact_sales
WHERE order_date IS NULL
   OR ship_date IS NULL
   OR due_date IS NULL;


-- Check date sequence
SELECT *
FROM gold.fact_sales
WHERE order_date > ship_date
   OR ship_date > due_date;


-- Check for invalid sales amount
SELECT *
FROM gold.fact_sales
WHERE sales_amount IS NULL
   OR sales_amount < 0;


-- Check for invalid quantity
SELECT *
FROM gold.fact_sales
WHERE quantity IS NULL
   OR quantity <= 0;


-- Check for invalid price
SELECT *
FROM gold.fact_sales
WHERE price IS NULL
   OR price <= 0;


-- Check sales calculation
SELECT *
FROM gold.fact_sales
WHERE sales_amount <> quantity * price;



-- ============================================================================
-- 4. REFERENTIAL INTEGRITY
-- ============================================================================

-- Check fact records without a matching product
SELECT
    fs.product_key
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
    ON fs.product_key = dp.product_key
WHERE dp.product_key IS NULL
GROUP BY fs.product_key;


-- Check fact records without a matching customer
SELECT
    fs.customer_key
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
    ON fs.customer_key = dc.customer_key
WHERE dc.customer_key IS NULL
GROUP BY fs.customer_key;



-- ============================================================================
-- 5. GOLD LAYER SUMMARY
-- ============================================================================

-- Row count for each Gold layer object
SELECT 'dim_customers' AS table_name, COUNT(*) AS row_count
FROM gold.dim_customers

UNION ALL

SELECT 'dim_products', COUNT(*)
FROM gold.dim_products

UNION ALL

SELECT 'fact_sales', COUNT(*)
FROM gold.fact_sales;
