/*
===============================================================================
Data Quality Checks - Silver Layer
===============================================================================

Purpose:
    Validate the quality, consistency, and integrity of data loaded into
    the Silver layer.

===============================================================================
*/


-- ============================================================================
-- 1. CRM CUSTOMER
-- ============================================================================

-- Check for NULL or invalid Customer IDs
SELECT *
FROM silver.crm_cust_info
WHERE cst_id IS NULL;


-- Check for duplicate Customer IDs
SELECT
    cst_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1;


-- Check for NULL Customer Keys
SELECT *
FROM silver.crm_cust_info
WHERE cst_key IS NULL
   OR TRIM(cst_key) = '';


-- Check for NULL or invalid Customer Names
SELECT *
FROM silver.crm_cust_info
WHERE cst_firstname IS NULL
   OR TRIM(cst_firstname) = ''
   OR cst_lastname IS NULL
   OR TRIM(cst_lastname) = '';


-- Check standardized Marital Status
SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info;


-- Check standardized Gender
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;


-- Check for invalid Marital Status or Gender
SELECT *
FROM silver.crm_cust_info
WHERE cst_marital_status NOT IN ('Single', 'Married', 'n/a')
   OR cst_gndr NOT IN ('Male', 'Female', 'n/a');


-- ============================================================================
-- 2. CRM PRODUCT
-- ============================================================================

-- Check for NULL Product IDs
SELECT *
FROM silver.crm_prd_info
WHERE prd_id IS NULL;


-- Check for duplicate Product IDs
SELECT
    prd_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1;


-- Check for NULL Product Keys
SELECT *
FROM silver.crm_prd_info
WHERE prd_key IS NULL
   OR TRIM(prd_key) = '';


-- Check for invalid Product Cost
SELECT *
FROM silver.crm_prd_info
WHERE prd_cost < 0
   OR prd_cost IS NULL;


-- Check standardized Product Line
SELECT DISTINCT prd_line
FROM silver.crm_prd_info;


-- Check for invalid Product Line
SELECT *
FROM silver.crm_prd_info
WHERE prd_line NOT IN (
    'Mountain',
    'Road',
    'Other Sales',
    'Touring',
    'n/a'
);


-- Check Product Date Range
SELECT *
FROM silver.crm_prd_info
WHERE prd_start_dt > prd_end_dt;


-- Check overlapping Product Date Ranges
SELECT *
FROM (
    SELECT
        prd_key,
        prd_start_dt,
        prd_end_dt,
        LEAD(prd_start_dt) OVER (
            PARTITION BY prd_key
            ORDER BY prd_start_dt
        ) AS next_start_dt
    FROM silver.crm_prd_info
) t
WHERE prd_end_dt >= next_start_dt;


-- ============================================================================
-- 3. CRM SALES
-- ============================================================================

-- Check for NULL Order Number
SELECT *
FROM silver.crm_sales_details
WHERE sls_ord_num IS NULL
   OR TRIM(sls_ord_num) = '';


-- Check for NULL Product Key
SELECT *
FROM silver.crm_sales_details
WHERE sls_prd_key IS NULL
   OR TRIM(sls_prd_key) = '';


-- Check for NULL Customer ID
SELECT *
FROM silver.crm_sales_details
WHERE sls_cust_id IS NULL;


-- Check invalid Sales Dates
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt IS NULL
   OR sls_ship_dt IS NULL
   OR sls_due_dt IS NULL;


-- Check date sequence
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_ship_dt > sls_due_dt;


-- Check invalid Sales Amount
SELECT *
FROM silver.crm_sales_details
WHERE sls_sales IS NULL
   OR sls_sales < 0;


-- Check invalid Quantity
SELECT *
FROM silver.crm_sales_details
WHERE sls_quantity IS NULL
   OR sls_quantity <= 0;


-- Check invalid Price
SELECT *
FROM silver.crm_sales_details
WHERE sls_price IS NULL
   OR sls_price <= 0;


-- Check Sales Calculation
SELECT *
FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price;


-- ============================================================================
-- 4. ERP CUSTOMER
-- ============================================================================

-- Check for NULL Customer ID
SELECT *
FROM silver.erp_cust_az12
WHERE cid IS NULL
   OR TRIM(cid) = '';


-- Check for duplicate Customer IDs
SELECT
    cid,
    COUNT(*) AS duplicate_count
FROM silver.erp_cust_az12
GROUP BY cid
HAVING COUNT(*) > 1;


-- Check for future Birth Dates
SELECT *
FROM silver.erp_cust_az12
WHERE bdate > CAST(GETDATE() AS DATE);


-- Check standardized Gender
SELECT DISTINCT gen
FROM silver.erp_cust_az12;


-- Check for invalid Gender
SELECT *
FROM silver.erp_cust_az12
WHERE gen NOT IN ('Male', 'Female', 'n/a');


-- ============================================================================
-- 5. ERP LOCATION
-- ============================================================================

-- Check for NULL Customer ID
SELECT *
FROM silver.erp_loc_a101
WHERE cid IS NULL
   OR TRIM(cid) = '';


-- Check for duplicate Customer IDs
SELECT
    cid,
    COUNT(*) AS duplicate_count
FROM silver.erp_loc_a101
GROUP BY cid
HAVING COUNT(*) > 1;


-- Check for NULL or invalid Country
SELECT *
FROM silver.erp_loc_a101
WHERE cntry IS NULL
   OR TRIM(cntry) = '';


-- ============================================================================
-- 6. ERP PRODUCT CATEGORY
-- ============================================================================

-- Check for NULL IDs
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE id IS NULL
   OR TRIM(id) = '';


-- Check for NULL Category
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE cat IS NULL
   OR TRIM(cat) = '';


-- Check for NULL Subcategory
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE subcat IS NULL
   OR TRIM(subcat) = '';


-- Check for NULL Maintenance
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE maintenance IS NULL
   OR TRIM(maintenance) = '';


-- Check for duplicate Product Category IDs
SELECT
    id,
    COUNT(*) AS duplicate_count
FROM silver.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1;


-- ============================================================================
-- 7. CROSS-TABLE / REFERENTIAL INTEGRITY
-- ============================================================================

-- Check Sales Customer IDs that do not exist in Customer table
SELECT DISTINCT
    s.sls_cust_id
FROM silver.crm_sales_details s
LEFT JOIN silver.crm_cust_info c
    ON s.sls_cust_id = c.cst_id
WHERE c.cst_id IS NULL;


-- Check Sales Product Keys that do not exist in Product table
SELECT DISTINCT
    s.sls_prd_key
FROM silver.crm_sales_details s
LEFT JOIN silver.crm_prd_info p
    ON s.sls_prd_key = p.prd_key
WHERE p.prd_key IS NULL;


-- Check ERP Customer IDs that do not exist in ERP Location
SELECT DISTINCT
    c.cid
FROM silver.erp_cust_az12 c
LEFT JOIN silver.erp_loc_a101 l
    ON c.cid = l.cid
WHERE l.cid IS NULL;
