CREATE OR REPLACE VIEW stg_invoices AS
SELECT
    invoice_id,
    order_id,
    CAST(invoice_date AS DATE) AS invoice_date,
    CAST(invoice_amount AS DECIMAL(12,2)) AS invoice_amount
FROM raw_invoices
WHERE order_id IS NOT NULL;