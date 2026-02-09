-- =============================================
-- Reconciliation Summary Dashboard
-- =============================================
-- Purpose: Executive-level KPIs and metrics for reconciliation health
-- Provides:
--   - Total transaction volumes
--   - Auto-match rates
--   - Exception counts and categories
--   - Financial exposure calculations
--   - Trend indicators
-- =============================================

WITH orders_to_invoices_summary AS (
    SELECT
        COUNT(*) AS total_orders,
        COUNT(CASE WHEN recon_status = 'MATCHED' THEN 1 END) AS matched_orders,
        COUNT(CASE WHEN recon_status != 'MATCHED' THEN 1 END) AS exception_orders,
        
        -- Exception breakdown
        COUNT(CASE WHEN recon_status = 'NO_INVOICE' THEN 1 END) AS no_invoice_count,
        COUNT(CASE WHEN recon_status = 'AMOUNT_DIFF' THEN 1 END) AS amount_diff_count,
        COUNT(CASE WHEN recon_status = 'TIMING_DIFF' THEN 1 END) AS timing_diff_count,
        COUNT(CASE WHEN recon_status = 'AMOUNT_AND_TIMING_DIFF' THEN 1 END) AS amount_timing_diff_count,
        
        -- Financial metrics
        SUM(order_amount) AS total_order_value,
        SUM(CASE WHEN recon_status = 'MATCHED' THEN order_amount ELSE 0 END) AS matched_order_value,
        SUM(CASE WHEN recon_status != 'MATCHED' THEN order_amount ELSE 0 END) AS exception_order_value,
        
        -- Match rate
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(CASE WHEN recon_status = 'MATCHED' THEN 1 END) * 100.0) / COUNT(*), 2)
            ELSE 0
        END AS order_match_rate_pct,
        
        -- Average metrics
        AVG(CASE WHEN recon_status = 'MATCHED' THEN ABS(date_diff_days) END) AS avg_days_to_invoice,
        AVG(CASE WHEN recon_status != 'MATCHED' THEN ABS(amount_diff) END) AS avg_exception_amount,
        
        -- Priority breakdown
        COUNT(CASE WHEN priority = 1 THEN 1 END) AS priority_1_count,
        COUNT(CASE WHEN priority = 2 THEN 1 END) AS priority_2_count,
        COUNT(CASE WHEN priority = 3 THEN 1 END) AS priority_3_count
        
    FROM recon_orders_to_invoices
),

invoices_to_ledger_summary AS (
    SELECT
        COUNT(*) AS total_invoices,
        COUNT(CASE WHEN recon_status = 'MATCHED' THEN 1 END) AS matched_invoices,
        COUNT(CASE WHEN recon_status != 'MATCHED' THEN 1 END) AS exception_invoices,
        
        -- Exception breakdown
        COUNT(CASE WHEN recon_status = 'UNPOSTED_INVOICE' THEN 1 END) AS unposted_count,
        COUNT(CASE WHEN recon_status = 'DUPLICATE_POSTING' THEN 1 END) AS duplicate_count,
        COUNT(CASE WHEN recon_status = 'UNDER_POSTED' THEN 1 END) AS under_posted_count,
        COUNT(CASE WHEN recon_status = 'PARTIAL_POSTING' THEN 1 END) AS partial_posting_count,
        COUNT(CASE WHEN recon_status = 'AMOUNT_MISMATCH' THEN 1 END) AS ledger_amount_mismatch_count,
        
        -- Financial metrics
        SUM(invoice_amount) AS total_invoice_value,
        SUM(CASE WHEN recon_status = 'MATCHED' THEN invoice_amount ELSE 0 END) AS matched_invoice_value,
        SUM(CASE WHEN recon_status != 'MATCHED' THEN invoice_amount ELSE 0 END) AS exception_invoice_value,
        
        -- Match rate
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(CASE WHEN recon_status = 'MATCHED' THEN 1 END) * 100.0) / COUNT(*), 2)
            ELSE 0
        END AS invoice_match_rate_pct,
        
        -- Average metrics
        AVG(CASE WHEN recon_status = 'MATCHED' THEN days_to_post END) AS avg_days_to_post,
        AVG(ledger_entry_count) AS avg_ledger_entries_per_invoice,
        
        -- Priority breakdown
        COUNT(CASE WHEN priority = 1 THEN 1 END) AS priority_1_count,
        COUNT(CASE WHEN priority = 2 THEN 1 END) AS priority_2_count,
        COUNT(CASE WHEN priority = 3 THEN 1 END) AS priority_3_count
        
    FROM recon_invoices_to_ledger
),

executive_summary AS (
    SELECT
        -- Overall volumes
        o.total_orders,
        i.total_invoices,
        o.matched_orders + i.matched_invoices AS total_matched_records,
        o.exception_orders + i.exception_invoices AS total_exceptions,
        
        -- Match rates
        o.order_match_rate_pct,
        i.invoice_match_rate_pct,
        ROUND(((o.matched_orders + i.matched_invoices) * 100.0) / (o.total_orders + i.total_invoices), 2) AS overall_match_rate_pct,
        
        -- Financial exposure
        o.exception_order_value AS orders_financial_exposure,
        i.exception_invoice_value AS invoices_financial_exposure,
        o.exception_order_value + i.exception_invoice_value AS total_financial_exposure,
        
        -- Priority items
        o.priority_1_count + i.priority_1_count AS total_priority_1_items,
        o.priority_2_count + i.priority_2_count AS total_priority_2_items,
        o.priority_3_count + i.priority_3_count AS total_priority_3_items,
        
        -- Timing metrics
        o.avg_days_to_invoice,
        i.avg_days_to_post,
        
        -- Additional context
        o.total_order_value,
        i.total_invoice_value,
        o.matched_order_value,
        i.matched_invoice_value
        
    FROM orders_to_invoices_summary o
    CROSS JOIN invoices_to_ledger_summary i
)

-- =============================================
-- FINAL OUTPUT: Executive Dashboard Metrics
-- =============================================

SELECT
    '=== EXECUTIVE SUMMARY ===' AS section,
    NULL AS metric,
    NULL AS value,
    NULL AS percentage
    
UNION ALL

SELECT
    'Transaction Volumes' AS section,
    'Total Orders' AS metric,
    CAST(total_orders AS VARCHAR) AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Transaction Volumes' AS section,
    'Total Invoices' AS metric,
    CAST(total_invoices AS VARCHAR) AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Transaction Volumes' AS section,
    'Total Matched Records' AS metric,
    CAST(total_matched_records AS VARCHAR) AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Transaction Volumes' AS section,
    'Total Exceptions' AS metric,
    CAST(total_exceptions AS VARCHAR) AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    '' AS section,
    '' AS metric,
    '' AS value,
    '' AS percentage

UNION ALL

SELECT
    '=== MATCH RATES ===' AS section,
    NULL AS metric,
    NULL AS value,
    NULL AS percentage

UNION ALL

SELECT
    'Match Rates' AS section,
    'Orders → Invoices Match Rate' AS metric,
    CAST(order_match_rate_pct AS VARCHAR) AS value,
    CAST(order_match_rate_pct AS VARCHAR) || '%' AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Match Rates' AS section,
    'Invoices → Ledger Match Rate' AS metric,
    CAST(invoice_match_rate_pct AS VARCHAR) AS value,
    CAST(invoice_match_rate_pct AS VARCHAR) || '%' AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Match Rates' AS section,
    'Overall Pipeline Match Rate' AS metric,
    CAST(overall_match_rate_pct AS VARCHAR) AS value,
    CAST(overall_match_rate_pct AS VARCHAR) || '%' AS percentage
FROM executive_summary

UNION ALL

SELECT
    '' AS section,
    '' AS metric,
    '' AS value,
    '' AS percentage

UNION ALL

SELECT
    '=== FINANCIAL EXPOSURE ===' AS section,
    NULL AS metric,
    NULL AS value,
    NULL AS percentage

UNION ALL

SELECT
    'Financial Exposure' AS section,
    'Orders Layer Exposure' AS metric,
    '$' || CAST(ROUND(orders_financial_exposure, 2) AS VARCHAR) AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Financial Exposure' AS section,
    'Invoices Layer Exposure' AS metric,
    '$' || CAST(ROUND(invoices_financial_exposure, 2) AS VARCHAR) AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Financial Exposure' AS section,
    'TOTAL FINANCIAL EXPOSURE' AS metric,
    '$' || CAST(ROUND(total_financial_exposure, 2) AS VARCHAR) AS value,
    CAST(ROUND((total_financial_exposure * 100.0) / (total_order_value + total_invoice_value), 2) AS VARCHAR) || '%' AS percentage
FROM executive_summary

UNION ALL

SELECT
    '' AS section,
    '' AS metric,
    '' AS value,
    '' AS percentage

UNION ALL

SELECT
    '=== PRIORITY BREAKDOWN ===' AS section,
    NULL AS metric,
    NULL AS value,
    NULL AS percentage

UNION ALL

SELECT
    'Priority Items' AS section,
    'Priority 1 (Critical)' AS metric,
    CAST(total_priority_1_items AS VARCHAR) AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Priority Items' AS section,
    'Priority 2 (High)' AS metric,
    CAST(total_priority_2_items AS VARCHAR) AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Priority Items' AS section,
    'Priority 3 (Medium)' AS metric,
    CAST(total_priority_3_items AS VARCHAR) AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    '' AS section,
    '' AS metric,
    '' AS value,
    '' AS percentage

UNION ALL

SELECT
    '=== TIMING METRICS ===' AS section,
    NULL AS metric,
    NULL AS value,
    NULL AS percentage

UNION ALL

SELECT
    'Timing Metrics' AS section,
    'Avg Days Order → Invoice' AS metric,
    CAST(ROUND(avg_days_to_invoice, 1) AS VARCHAR) || ' days' AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    'Timing Metrics' AS section,
    'Avg Days Invoice → Ledger Post' AS metric,
    CAST(ROUND(avg_days_to_post, 1) AS VARCHAR) || ' days' AS value,
    NULL AS percentage
FROM executive_summary

UNION ALL

SELECT
    '' AS section,
    '' AS metric,
    '' AS value,
    '' AS percentage

UNION ALL

SELECT
    '=== ORDERS → INVOICES EXCEPTIONS ===' AS section,
    NULL AS metric,
    NULL AS value,
    NULL AS percentage

UNION ALL

SELECT
    'Order Exceptions' AS section,
    'Missing Invoices' AS metric,
    CAST(no_invoice_count AS VARCHAR) AS value,
    NULL AS percentage
FROM orders_to_invoices_summary

UNION ALL

SELECT
    'Order Exceptions' AS section,
    'Amount Mismatches' AS metric,
    CAST(amount_diff_count AS VARCHAR) AS value,
    NULL AS percentage
FROM orders_to_invoices_summary

UNION ALL

SELECT
    'Order Exceptions' AS section,
    'Timing Differences' AS metric,
    CAST(timing_diff_count AS VARCHAR) AS value,
    NULL AS percentage
FROM orders_to_invoices_summary

UNION ALL

SELECT
    'Order Exceptions' AS section,
    'Amount & Timing Issues' AS metric,
    CAST(amount_timing_diff_count AS VARCHAR) AS value,
    NULL AS percentage
FROM orders_to_invoices_summary

UNION ALL

SELECT
    '' AS section,
    '' AS metric,
    '' AS value,
    '' AS percentage

UNION ALL

SELECT
    '=== INVOICES → LEDGER EXCEPTIONS ===' AS section,
    NULL AS metric,
    NULL AS value,
    NULL AS percentage

UNION ALL

SELECT
    'Invoice Exceptions' AS section,
    'Unposted Invoices' AS metric,
    CAST(unposted_count AS VARCHAR) AS value,
    NULL AS percentage
FROM invoices_to_ledger_summary

UNION ALL

SELECT
    'Invoice Exceptions' AS section,
    'Duplicate Postings' AS metric,
    CAST(duplicate_count AS VARCHAR) AS value,
    NULL AS percentage
FROM invoices_to_ledger_summary

UNION ALL

SELECT
    'Invoice Exceptions' AS section,
    'Under Posted' AS metric,
    CAST(under_posted_count AS VARCHAR) AS value,
    NULL AS percentage
FROM invoices_to_ledger_summary

UNION ALL

SELECT
    'Invoice Exceptions' AS section,
    'Partial Postings' AS metric,
    CAST(partial_posting_count AS VARCHAR) AS value,
    NULL AS percentage
FROM invoices_to_ledger_summary

UNION ALL

SELECT
    'Invoice Exceptions' AS section,
    'Amount Mismatches' AS metric,
    CAST(ledger_amount_mismatch_count AS VARCHAR) AS value,
    NULL AS percentage
FROM invoices_to_ledger_summary;