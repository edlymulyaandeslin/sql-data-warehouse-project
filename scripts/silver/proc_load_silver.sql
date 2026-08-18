/*
===============================================================================
Stored Procedure: silver.load_silver
===============================================================================

Script Purpose:
    This stored procedure transforms and loads data from the Bronze layer
    into the Silver layer.

    It cleans and standardizes CRM and ERP data, handles duplicates and
    invalid values, applies necessary transformations, and loads the
    processed data into the Silver layer tables.

How to Execute:
    EXEC silver.load_silver;

===============================================================================
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===============================================';
		PRINT 'Loading Silver Layer';
		PRINT '===============================================';

		PRINT '-----------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '-----------------------------------------------';


		-- Transformation bronze.crm_cust_info to silver.crm_cust_info
		SET @start_time = GETDATE();
		PRINT '>> TRUNCATING Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> INSERTING Data Into: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info (
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date
		)
			(SELECT
				cst_id,
				cst_key,
				TRIM(cst_firstname) cst_firstname,
				TRIM(cst_lastname) cst_lastname,
				CASE
					WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
					WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
					ELSE 'n/a'
				END cst_marital_status,
				CASE
					WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
					WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
					ELSE 'n/a'
				END cst_gndr,
				cst_create_date
			FROM(
				SELECT
					*,
					ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) flag_last
				FROM bronze.crm_cust_info
				WHERE cst_id IS NOT NULL
			)t WHERE flag_last = 1
			);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds.';
		PRINT '----------------';


		-- Transformation bronze.crm_prd_info to silver.crm_prd_info
		SET @start_time = GETDATE();
		PRINT '>> TRUNCATING Table: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> INSERTING Data Into: silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info (
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
			(SELECT
				prd_id,
				REPLACE(SUBSTRING(TRIM(prd_key), 1, 5), '-', '_') cat_id,
				SUBSTRING(TRIM(prd_key), 7, LEN(prd_key)) prd_key,
				prd_nm,
				COALESCE(prd_cost, 0) prd_cost,
				CASE UPPER(TRIM(prd_line))
					WHEN 'M' THEN 'Mountain'
					WHEN 'R' THEN 'Road'
					WHEN 'S' THEN 'Other Sales'
					WHEN 'T' THEN 'Touring'
					ELSE 'n/a'
				END prd_line,
				CAST(prd_start_dt AS DATE) prd_start_dt,
				CAST(LEAD(DATEADD(DAY, -1, prd_start_dt)) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) AS DATE) prd_end_dt
			FROM bronze.crm_prd_info
			);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds.';
		PRINT '----------------';

	
		-- Transformation bronze.crm_sales_details to silver.crm_sales_details
		SET @start_time = GETDATE();
		PRINT '>> TRUNCATING Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> INSERTING Data Into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details (
			   sls_ord_num
			  ,sls_prd_key
			  ,sls_cust_id
			  ,sls_order_dt
			  ,sls_ship_dt
			  ,sls_due_dt
			  ,sls_sales
			  ,sls_quantity
			  ,sls_price
		)
			(SELECT
				sls_ord_num,
				sls_prd_key,
				sls_cust_id,
				CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
					 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
				END sls_order_dt,
				CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
					 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
				END sls_ship_dt,
				CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
					 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
				END sls_due_dt,
				CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
						THEN sls_quantity * ABS(sls_price)
					ELSE sls_sales
				END sls_sales,
				sls_quantity,
				CASE WHEN sls_price IS NULL OR sls_price <= 0
					THEN sls_sales / NULLIF(sls_quantity, 0)
					ELSE sls_price
				END sls_price
			FROM bronze.crm_sales_details
			);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds.';
		PRINT '----------------';


		PRINT '-----------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '-----------------------------------------------';

		-- Transformation bronze.erp_cust_az12 to silver.erp_cust_az12
		SET @start_time = GETDATE();
		PRINT '>> TRUNCATING Table: silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> INSERTING Data Into: silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
			(SELECT
				 CASE 
					WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
					ELSE cid
				 END cid,
				 CASE
					WHEN bdate > GETDATE() THEN NULL
					ELSE CAST(bdate AS DATE)
				 END bdate,
				 CASE
					WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
					WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
					ELSE 'n/a'
				 END gen
			FROM bronze.erp_cust_az12
			);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds.';
		PRINT '----------------';


		-- Transformation bronze.erp_loc_a101 to silver.erp_loc_a101
		SET @start_time = GETDATE();
		PRINT '>> TRUNCATING Table: silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> INSERTING Data Into: silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101 (cid, cntry)
		(SELECT
			REPLACE(cid, '-', '') cid,
			CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
				 WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
				 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
				 ELSE TRIM(cntry)
			END cntry
		FROM bronze.erp_loc_a101
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds.';
		PRINT '----------------';


		-- Transformation bronze.erp_px_cat_g1v2 to silver.erp_px_cat_g1v2
		SET @start_time = GETDATE();
		PRINT '>> TRUNCATING Table: silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> INSERTING Data Into: silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2 (
			id, cat, subcat, maintenance
		)
		(SELECT
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds.';
		PRINT '----------------';


		SET @batch_end_time = GETDATE();
		PRINT '=============================================';
		PRINT 'Loading Silver Layer is Competed'
		PRINT '	- Total Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds.';
		PRINT '=============================================';
	END TRY

	BEGIN CATCH
		PRINT '=============================================';
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		PRINT 'Error Message ' + ERROR_MESSAGE();
		PRINT 'Error Number ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '=============================================';
	END CATCH
END
