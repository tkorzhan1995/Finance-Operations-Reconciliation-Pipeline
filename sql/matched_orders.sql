CREATE OR REPLACE VIEW matched_orders AS
SELECT *
FROM recon_orders_to_invoices
WHERE recon_status = 'MATCHED';