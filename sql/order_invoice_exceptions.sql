CREATE OR REPLACE VIEW order_invoice_exceptions AS
SELECT
    'ORDER_INVOICE' AS reconciliation_type,
    order_id,
    invoice_id,
    recon_status AS exception_reason,
    order_amount AS expected_amount,
    invoice_amount AS actual_amount,
    order_date,
    invoice_date,
    CURRENT_DATE AS detected_date
FROM recon_orders_to_invoices
WHERE recon_status <> 'MATCHED';