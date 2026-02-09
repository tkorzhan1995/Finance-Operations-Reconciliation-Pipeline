-- =============================================
-- Staging View: Orders
-- =============================================
-- Purpose: Clean and standardize raw orders data
-- Transformations:
--   - Normalize date formats
--   - Cast amounts to numeric
--   - Remove duplicate records
--   - Standardize text fields
-- =============================================

WITH cleaned_orders AS (
    SELECT
        -- Primary identifiers
        order_id,
        customer_id,
        
        -- Date standardization
        -- Convert all date formats to standard YYYY-MM-DD
        CAST(order_date AS DATE) AS order_date,
        CAST(COALESCE(ship_date, order_date) AS DATE) AS ship_date,
        
        -- Amount cleaning
        -- Remove currency symbols, cast to numeric with 2 decimal places
        CAST(REPLACE(REPLACE(order_amount, '$', ''), ',', '') AS DECIMAL(18,2)) AS order_amount,
        CAST(REPLACE(REPLACE(COALESCE(tax_amount, '0'), '$', ''), ',', '') AS DECIMAL(18,2)) AS tax_amount,
        CAST(REPLACE(REPLACE(COALESCE(shipping_amount, '0'), '$', ''), ',', '') AS DECIMAL(18,2)) AS shipping_amount,
        
        -- Calculated total
        CAST(REPLACE(REPLACE(order_amount, '$', ''), ',', '') AS DECIMAL(18,2)) +
        CAST(REPLACE(REPLACE(COALESCE(tax_amount, '0'), '$', ''), ',', '') AS DECIMAL(18,2)) +
        CAST(REPLACE(REPLACE(COALESCE(shipping_amount, '0'), '$', ''), ',', '') AS DECIMAL(18,2)) AS total_amount,
        
        -- Text standardization
        UPPER(TRIM(order_status)) AS order_status,
        UPPER(TRIM(customer_name)) AS customer_name,
        TRIM(product_sku) AS product_sku,
        CAST(quantity AS INTEGER) AS quantity,
        
        -- Additional fields
        UPPER(TRIM(COALESCE(payment_method, 'UNKNOWN'))) AS payment_method,
        TRIM(order_notes) AS order_notes,
        
        -- Audit columns
        created_at,
        updated_at,
        
        -- Row number for deduplication
        ROW_NUMBER() OVER (
            PARTITION BY order_id 
            ORDER BY updated_at DESC, created_at DESC
        ) AS row_num
        
    FROM raw_orders
    WHERE order_id IS NOT NULL  -- Remove records without order_id
      AND order_amount IS NOT NULL  -- Remove records without amount
)

-- Select only the most recent version of each order (deduplication)
SELECT
    order_id,
    customer_id,
    order_date,
    ship_date,
    order_amount,
    tax_amount,
    shipping_amount,
    total_amount,
    order_status,
    customer_name,
    product_sku,
    quantity,
    payment_method,
    order_notes,
    created_at,
    updated_at
FROM cleaned_orders
WHERE row_num = 1  -- Keep only the most recent record for each order_id
  AND order_amount >= 0  -- Remove negative amounts (likely errors)
  AND quantity > 0;  -- Remove zero or negative quantities