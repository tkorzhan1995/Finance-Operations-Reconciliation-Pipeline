-- =============================================
-- Staging View: Ledger
-- =============================================
-- Purpose: Clean and standardize raw ledger data
-- Transformations:
--   - Normalize date formats
--   - Cast amounts to numeric with proper debit/credit handling
--   - Remove duplicate postings
--   - Standardize account codes and transaction types
-- =============================================

WITH cleaned_ledger AS (
    SELECT
        -- Primary identifiers
        entry_id,
        transaction_id,
        invoice_id,
        
        -- General ledger reference
        UPPER(TRIM(account_code)) AS account_code,
        TRIM(account_name) AS account_name,
        UPPER(TRIM(account_type)) AS account_type,  -- ASSET, LIABILITY, REVENUE, EXPENSE, EQUITY
        
        -- Date standardization
        CAST(posting_date AS DATE) AS posting_date,
        CAST(transaction_date AS DATE) AS transaction_date,
        CAST(COALESCE(effective_date, transaction_date) AS DATE) AS effective_date,
        
        -- Period information
        CAST(fiscal_year AS INTEGER) AS fiscal_year,
        CAST(fiscal_period AS INTEGER) AS fiscal_period,
        TRIM(period_name) AS period_name,  -- e.g., "2024-01", "JAN-2024"
        
        -- Amount handling with debit/credit logic
        CAST(REPLACE(REPLACE(COALESCE(debit_amount, '0'), '$', ''), ',', '') AS DECIMAL(18,2)) AS debit_amount,
        CAST(REPLACE(REPLACE(COALESCE(credit_amount, '0'), '$', ''), ',', '') AS DECIMAL(18,2)) AS credit_amount,
        
        -- Net amount (positive for debits, negative for credits)
        CAST(REPLACE(REPLACE(COALESCE(debit_amount, '0'), '$', ''), ',', '') AS DECIMAL(18,2)) -
        CAST(REPLACE(REPLACE(COALESCE(credit_amount, '0'), '$', ''), ',', '') AS DECIMAL(18,2)) AS net_amount,
        
        -- Absolute amount for matching purposes
        CASE 
            WHEN COALESCE(debit_amount, 0) > 0 THEN CAST(REPLACE(REPLACE(debit_amount, '$', ''), ',', '') AS DECIMAL(18,2))
            WHEN COALESCE(credit_amount, 0) > 0 THEN CAST(REPLACE(REPLACE(credit_amount, '$', ''), ',', '') AS DECIMAL(18,2))
            ELSE 0
        END AS absolute_amount,
        
        -- Transaction classification
        UPPER(TRIM(transaction_type)) AS transaction_type,  -- INVOICE, PAYMENT, ADJUSTMENT, REFUND
        UPPER(TRIM(entry_type)) AS entry_type,  -- DEBIT, CREDIT
        UPPER(TRIM(posting_status)) AS posting_status,  -- POSTED, PENDING, REVERSED
        
        -- Business details
        UPPER(TRIM(business_unit)) AS business_unit,
        UPPER(TRIM(cost_center)) AS cost_center,
        UPPER(TRIM(department)) AS department,
        
        -- Reference information
        TRIM(reference_number) AS reference_number,
        TRIM(description) AS description,
        TRIM(posted_by) AS posted_by,
        
        -- Currency handling
        UPPER(TRIM(COALESCE(currency_code, 'USD'))) AS currency_code,
        CAST(COALESCE(exchange_rate, 1.0) AS DECIMAL(18,6)) AS exchange_rate,
        
        -- Reversal tracking
        CASE WHEN reversal_flag = 'Y' OR UPPER(posting_status) = 'REVERSED' THEN TRUE ELSE FALSE END AS is_reversed,
        reversal_entry_id,
        
        -- Audit columns
        created_at,
        updated_at,
        
        -- Row number for deduplication
        ROW_NUMBER() OVER (
            PARTITION BY entry_id 
            ORDER BY updated_at DESC, created_at DESC
        ) AS row_num
        
    FROM raw_ledger
    WHERE entry_id IS NOT NULL
      AND account_code IS NOT NULL
),

-- Identify and flag duplicate postings
 deduplicated_ledger AS (
    SELECT
        *,
        -- Check for duplicate postings (same invoice, amount, date, account)
        COUNT(*) OVER (
            PARTITION BY invoice_id, account_code, posting_date, absolute_amount
            ORDER BY entry_id
        ) AS duplicate_count,
        
        ROW_NUMBER() OVER (
            PARTITION BY invoice_id, account_code, posting_date, absolute_amount
            ORDER BY entry_id
        ) AS duplicate_row_num
        
    FROM cleaned_ledger
    WHERE row_num = 1
      AND posting_status != 'CANCELLED'
)

-- Final selection
SELECT
    entry_id,
    transaction_id,
    invoice_id,
    account_code,
    account_name,
    account_type,
    posting_date,
    transaction_date,
    effective_date,
    fiscal_year,
    fiscal_period,
    period_name,
    debit_amount,
    credit_amount,
    net_amount,
    absolute_amount,
    transaction_type,
    entry_type,
    posting_status,
    business_unit,
    cost_center,
    department,
    reference_number,
    description,
    posted_by,
    currency_code,
    exchange_rate,
    is_reversed,
    reversal_entry_id,
    created_at,
    updated_at,
    
    -- Duplicate flag for exception reporting
    CASE 
        WHEN duplicate_count > 1 AND duplicate_row_num > 1 THEN TRUE 
        ELSE FALSE 
    END AS is_duplicate
    
FROM deduplicated_ledger
WHERE posting_date IS NOT NULL  -- Must have a posting date
  AND NOT is_reversed  -- Exclude reversed entries
  AND (debit_amount > 0 OR credit_amount > 0);  -- Must have an amount