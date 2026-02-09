-- =============================================
-- Staging View: Shipments
-- =============================================
-- Purpose: Clean and standardize raw shipments data
-- Transformations:
--   - Normalize date formats
--   - Standardize tracking information
--   - Remove duplicate records
--   - Calculate shipping metrics
-- =============================================

WITH cleaned_shipments AS (
    SELECT
        -- Primary identifiers
        shipment_id,
        order_id,
        
        -- Date standardization
        CAST(ship_date AS DATE) AS ship_date,
        CAST(estimated_delivery_date AS DATE) AS estimated_delivery_date,
        CAST(actual_delivery_date AS DATE) AS actual_delivery_date,
        
        -- Shipping details
        UPPER(TRIM(carrier)) AS carrier,
        TRIM(tracking_number) AS tracking_number,
        UPPER(TRIM(shipment_status)) AS shipment_status,
        
        -- Weight and dimensions (standardize to numeric)
        CAST(COALESCE(weight_lbs, 0) AS DECIMAL(10,2)) AS weight_lbs,
        CAST(COALESCE(length_inches, 0) AS DECIMAL(10,2)) AS length_inches,
        CAST(COALESCE(width_inches, 0) AS DECIMAL(10,2)) AS width_inches,
        CAST(COALESCE(height_inches, 0) AS DECIMAL(10,2)) AS height_inches,
        
        -- Cost information
        CAST(REPLACE(REPLACE(COALESCE(shipping_cost, '0'), '$', ''), ',', '') AS DECIMAL(18,2)) AS shipping_cost,
        
        -- Address standardization
        UPPER(TRIM(destination_city)) AS destination_city,
        UPPER(TRIM(destination_state)) AS destination_state,
        TRIM(destination_zip) AS destination_zip,
        UPPER(TRIM(destination_country)) AS destination_country,
        
        -- Additional fields
        CAST(COALESCE(number_of_packages, 1) AS INTEGER) AS number_of_packages,
        TRIM(shipping_notes) AS shipping_notes,
        
        -- Service level standardization
        CASE 
            WHEN UPPER(TRIM(service_level)) IN ('OVERNIGHT', '1-DAY', 'NEXT DAY') THEN 'OVERNIGHT'
            WHEN UPPER(TRIM(service_level)) IN ('2-DAY', 'TWO DAY') THEN '2-DAY'
            WHEN UPPER(TRIM(service_level)) IN ('3-DAY', 'THREE DAY') THEN '3-DAY'
            WHEN UPPER(TRIM(service_level)) IN ('GROUND', 'STANDARD', '5-7 DAY') THEN 'GROUND'
            ELSE 'STANDARD'
        END AS service_level,
        
        -- Audit columns
        created_at,
        updated_at,
        
        -- Row number for deduplication
        ROW_NUMBER() OVER (
            PARTITION BY shipment_id 
            ORDER BY updated_at DESC, created_at DESC
        ) AS row_num
        
    FROM raw_shipments
    WHERE shipment_id IS NOT NULL  -- Remove records without shipment_id
      AND order_id IS NOT NULL  -- Remove records without order_id
),

enriched_shipments AS (
    SELECT
        shipment_id,
        order_id,
        ship_date,
        estimated_delivery_date,
        actual_delivery_date,
        carrier,
        tracking_number,
        shipment_status,
        weight_lbs,
        length_inches,
        width_inches,
        height_inches,
        shipping_cost,
        destination_city,
        destination_state,
        destination_zip,
        destination_country,
        number_of_packages,
        shipping_notes,
        service_level,
        created_at,
        updated_at,
        
        -- Calculated metrics
        CASE 
            WHEN actual_delivery_date IS NOT NULL AND estimated_delivery_date IS NOT NULL
            THEN DATEDIFF(day, estimated_delivery_date, actual_delivery_date)
            ELSE NULL
        END AS delivery_variance_days,
        
        -- Delivery status flag
        CASE 
            WHEN actual_delivery_date IS NOT NULL THEN TRUE
            ELSE FALSE
        END AS is_delivered,
        
        -- On-time delivery flag
        CASE 
            WHEN actual_delivery_date IS NOT NULL AND estimated_delivery_date IS NOT NULL
            THEN CASE WHEN actual_delivery_date <= estimated_delivery_date THEN TRUE ELSE FALSE END
            ELSE NULL
        END AS is_on_time
        
    FROM cleaned_shipments
    WHERE row_num = 1  -- Keep only the most recent record for each shipment_id
)

-- Final output
SELECT
    shipment_id,
    order_id,
    ship_date,
    estimated_delivery_date,
    actual_delivery_date,
    carrier,
    tracking_number,
    shipment_status,
    weight_lbs,
    length_inches,
    width_inches,
    height_inches,
    shipping_cost,
    destination_city,
    destination_state,
    destination_zip,
    destination_country,
    number_of_packages,
    shipping_notes,
    service_level,
    delivery_variance_days,
    is_delivered,
    is_on_time,
    created_at,
    updated_at
FROM enriched_shipments
WHERE ship_date IS NOT NULL;  -- Remove records without ship date