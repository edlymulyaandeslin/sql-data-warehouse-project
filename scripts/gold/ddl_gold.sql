/*
===============================================================================
Create Gold Layer Views
===============================================================================

Script Purpose:
    This script creates the Gold layer views used for reporting and analytics.

    The views combine and transform data from the Silver layer into:
        - gold.dim_customers : Customer dimension with customer details.
        - gold.dim_products  : Product dimension with current product details.
        - gold.fact_sales    : Sales fact table linked to customers and products.

===============================================================================
*/

/*	Create View Gold Layer: JOIN silver.crm_cust_info, 
						silver.erp_cust_az12, 
						silver.erp_loc_a101
	Result: gold.dim_customers
*/
CREATE OR ALTER VIEW gold.dim_customers AS (
	SELECT 
		ROW_NUMBER() OVER(ORDER BY ci.cst_id) customer_key,
		ci.cst_id customer_id,
		ci.cst_key customer_number,
		ci.cst_firstname first_name,
		ci.cst_lastname last_name,
		la.cntry country,
		ci.cst_marital_status marital_status,
		CASE
			WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM is the master for gender info
			ELSE COALESCE(ca.gen, 'n/a')
		END gender,
		ca.bdate birthdate,
		ci.cst_create_date create_date
	FROM silver.crm_cust_info ci
	LEFT JOIN silver.erp_cust_az12 ca
	ON ci.cst_key = ca.cid
	LEFT JOIN silver.erp_loc_a101 la
	ON ci.cst_key = la.cid
);

GO

/*	Create View Gold Layer: JOIN silver.crm_prd_info pin,
								silver.erp_px_cat_g1v2
	Result: gold.dim_products
*/
CREATE OR ALTER VIEW gold.dim_products AS (
	SELECT
		ROW_NUMBER() OVER(ORDER BY pin.prd_start_dt, pin.prd_key) product_key,
		pin.prd_id product_id,
		pin.prd_key product_number,
		pin.prd_nm product_name,
		pin.cat_id category_id,
		pc.cat category,
		pc.subcat subcategory,
		pc.maintenance,
		pin.prd_cost cost,
		pin.prd_line product_line,
		pin.prd_start_dt start_date
	FROM silver.crm_prd_info pin
	LEFT JOIN silver.erp_px_cat_g1v2 pc
	ON pin.cat_id = pc.id
	WHERE pin.prd_end_dt IS NULL -- Filter out all historical data
);

GO

/*	Create View Gold Layer: JOIN silver.crm_sales_details,
								gold.dim_products, 
								gold.dim_customers
	Result: gold.fact_sales
*/
CREATE OR ALTER VIEW gold.fact_sales AS (
SELECT 
	sd.sls_ord_num order_number,
	pr.product_key,
	cu.customer_key,
	sd.sls_order_dt order_date,
	sd.sls_ship_dt ship_date,
	sd.sls_due_dt due_date,
	sd.sls_sales sales_amount,
	sd.sls_quantity quantity,
	sd.sls_price price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.customer_id
);
