-- =============================================
-- Reconciliation Model: Invoices to Ledger
-- =============================================
-- Purpose: Match invoices to ledger entries and identify posting issues
-- Business Rules:
--   - Match on invoice_id
--   - Multiple ledger entries may sum to invoice amount
--   - Posted amount must equal invoice amount
--   - Flag missing or duplicate postings
-- =============================================

WITH ledger_aggregates AS (
    SELECT
        invoice_id,
        
        -- Count of entries
        COUNT(*) AS ledger_entry_count,
        COUNT(DISTINCT ledger_entry_id) AS distinct_entry_count,
        
        -- Sum of amounts
        SUM(net_amount) AS total_ledger_amount,
        SUM(CASE WHEN posting_status = 'POSTED' THEN net_amount ELSE 0 END) AS posted_amount,
        SUM(CASE WHEN posting_status = 'PENDING' THEN net_amount ELSE 0 END) AS pending_amount,
        
        -- Posting dates
        MIN(posting_date) AS first_posting_date,
        MAX(posting_date) AS last_posting_date,
        
        -- Account information (for reference)
        STRING_AGG(DISTINCT account_number, ', ') AS account_numbers,
        STRING_AGG(DISTINCT account_type, ', ') AS account_types,
        
        -- Entry IDs for audit trail
        STRING_AGG(CAST(ledger_entry_id AS VARCHAR), ', ') AS entry_ids
        
    FROM stg_ledger
    WHERE invoice_id IS NOT NULL
    GROUP BY invoice_id
),

invoice_ledger_matches AS (
    SELECT
        -- Invoice information
        i.invoice_id,
        i.order_id,
        i.customer_id,
        i.customer_name,
        i.invoice_date,
        i.total_amount AS invoice_amount,
        i.invoice_status,
        i.due_date,
        i.paid_date,
        
        -- Ledger aggregates
        COALESCE(l.ledger_entry_count, 0) AS ledger_entry_count,
        COALESCE(l.distinct_entry_count, 0) AS distinct_entry_count,
        COALESCE(l.total_ledger_amount, 0) AS total_ledger_amount,
        COALESCE(l.posted_amount, 0) AS posted_amount,
        COALESCE(l.pending_amount, 0) AS pending_amount,
        l.first_posting_date,
        l.last_posting_date,
        l.account_numbers,
        l.account_types,
        l.entry_ids,
        
        -- Calculate differences
        i.total_amount - COALESCE(l.posted_amount, 0) AS amount_diff,
        ABS(i.total_amount - COALESCE(l.posted_amount, 0)) AS abs_amount_diff,
        
        -- Percentage difference
        CASE 
            WHEN i.total_amount > 0 THEN 
                (ABS(i.total_amount - COALESCE(l.posted_amount, 0)) / i.total_amount) * 100
            ELSE 0
        END AS amount_diff_pct,
        
        -- Days to post
        CASE 
            WHEN l.first_posting_date IS NOT NULL 
            THEN DATEDIFF(day, i.invoice_date, l.first_posting_date)
            ELSE NULL
        END AS days_to_post,
        
        -- Audit timestamps
        i.created_at AS invoice_created_at
        
    FROM stg_invoices i
    LEFT JOIN ledger_aggregates l 
        ON i.invoice_id = l.invoice_id
),

reconciliation_status AS (
    SELECT
        invoice_id,
        order_id,
        customer_id,
        customer_name,
        invoice_date,
        invoice_amount,
        invoice_status,
        due_date,
        paid_date,
        ledger_entry_count,
        distinct_entry_count,
        total_ledger_amount,
        posted_amount,
        pending_amount,
        first_posting_date,
        last_posting_date,
        account_numbers,
        account_types,
        entry_ids,
        amount_diff,
        abs_amount_diff,
        amount_diff_pct,
        days_to_post,
        
        -- Reconciliation Status Logic
        CASE
            -- Perfect match: posted amount equals invoice amount
            WHEN ledger_entry_count > 0 
                AND abs_amount_diff <= 0.01  -- Tolerance for rounding
                AND pending_amount = 0  -- No pending entries
            THEN 'MATCHED'
            
            -- No ledger entries found
            WHEN ledger_entry_count = 0
            THEN 'UNPOSTED_INVOICE'
            
            -- Posted amount exceeds invoice amount (potential duplicate)
            WHEN posted_amount > invoice_amount + 0.01
            THEN 'DUPLICATE_POSTING'
            
            -- Posted amount less than invoice amount
            WHEN posted_amount < invoice_amount - 0.01 AND pending_amount = 0
            THEN 'UNDER_POSTED'
            
            -- Some entries are still pending
            WHEN pending_amount > 0
            THEN 'PARTIAL_POSTING'
            
            -- Amount doesn't match but entries exist
            WHEN abs_amount_diff > 0.01
            THEN 'AMOUNT_MISMATCH'
            
            -- Catch-all
            ELSE 'UNKNOWN'
        END AS recon_status,
        
        -- Additional flag for potential duplicate entries
        CASE
            WHEN ledger_entry_count > 3 THEN 'POTENTIAL_DUPLICATE'
            WHEN distinct_entry_count < ledger_entry_count THEN 'DUPLICATE_ENTRY_IDS'
            ELSE NULL
        END AS duplicate_flag,
        
        -- Priority flag for follow-up
        CASE
            WHEN ledger_entry_count = 0 THEN 1  -- Highest priority
            WHEN posted_amount > invoice_amount + 100 THEN 1  -- Large overpayment
            WHEN abs_amount_diff > 1000 THEN 1  -- Large amount difference
            WHEN amount_diff_pct > 10 THEN 1  -- >10% difference
            WHEN pending_amount > 0 THEN 2  -- Partial posting
            WHEN abs_amount_diff > 0.01 THEN 2  -- Any amount difference
            WHEN ledger_entry_count > 5 THEN 3  -- Many entries (review for duplicates)
            ELSE 4  -- Matched, low priority
        END AS priority,
        
        -- Exception notes
        CASE
            WHEN ledger_entry_count = 0 THEN 'Invoice not posted to ledger'
            WHEN posted_amount > invoice_amount + 0.01 
                THEN 'Duplicate posting detected: ledger amount $' || CAST(posted_amount AS VARCHAR) || ' exceeds invoice $' || CAST(invoice_amount AS VARCHAR)
            WHEN posted_amount < invoice_amount - 0.01 AND pending_amount = 0
                THEN 'Under-posted: ledger amount $' || CAST(posted_amount AS VARCHAR) || ' is less than invoice $' || CAST(invoice_amount AS VARCHAR)
            WHEN pending_amount > 0 
                THEN 'Partial posting: $' || CAST(pending_amount AS VARCHAR) || ' still pending'
            WHEN abs_amount_diff > 0.01 
                THEN 'Amount mismatch: $' || CAST(amount_diff AS VARCHAR) || ' difference'
            WHEN ledger_entry_count > 5 
                THEN 'Review: ' || CAST(ledger_entry_count AS VARCHAR) || ' ledger entries found'
            ELSE 'Reconciled successfully'
        END AS exception_notes,
        
        invoice_created_at
        
    FROM invoice_ledger_matches
)

-- Final output with all reconciliation details
SELECT
    invoice_id,
    order_id,
    customer_id,
    customer_name,
    invoice_date,
    invoice_amount,
    invoice_status,
    ledger_entry_count,
    distinct_entry_count,
    posted_amount,
    pending_amount,
    total_ledger_amount,
    amount_diff,
    amount_diff_pct,
    first_posting_date,
    last_posting_date,
    days_to_post,
    account_numbers,
    account_types,
    entry_ids,
    recon_status,
    duplicate_flag,
    priority,
    exception_notes,
    invoice_created_at,
    CURRENT_TIMESTAMP AS reconciliation_run_date
FROM reconciliation_status
ORDER BY 
    priority ASC,
    abs_amount_diff DESC,
    invoice_date DESC;