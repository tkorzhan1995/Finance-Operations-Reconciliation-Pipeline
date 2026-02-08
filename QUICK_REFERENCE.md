# Quick Reference Guide

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Run with sample data
python reconcile.py

# View results
cat outputs/reconciliation_summary_*.txt
```

## Common Commands

```bash
# Basic run
python reconcile.py

# With custom data
python reconcile.py --orders data/orders.csv --invoices data/invoices.csv

# Adjust tolerances
python reconcile.py --amount-tolerance 1.00 --timing-tolerance 10

# Custom output directory
python reconcile.py --output-dir reports/2024-01/

# Help
python reconcile.py --help
```

## File Formats

### Input CSV Structure

**Orders**: `order_id, customer_id, order_date, amount, status`
**Shipments**: `shipment_id, order_id, shipment_date, shipped_amount, status`
**Invoices**: `invoice_id, order_id, customer_id, invoice_date, amount, status`
**Ledger**: `posting_id, invoice_id, posting_date, amount, account, transaction_type`

### Output Files

- `reconciliation_summary_*.txt` - Executive summary
- `matched_records_*.csv` - Successful matches
- `exceptions_*.csv` - Issues requiring attention
- `detailed_report_*.json` - Complete data

## Exception Types

| Type | Description | Action Required |
|------|-------------|-----------------|
| `matched` | Perfect match | None - OK ✓ |
| `timing` | Date difference > tolerance | Review timing |
| `amount_mismatch` | Amount difference > tolerance | Investigate amounts |
| `missing_invoice` | Order without invoice | Create invoice |
| `missing_order` | Invoice without order | Find order or void invoice |
| `partial_fulfillment` | Partial shipment | Verify fulfillment |
| `refund` | Refund detected | Review refund reason |
| `cancelled` | Cancelled transaction | Verify cancellation |

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `--amount-tolerance` | 0.01 | Max amount difference ($) |
| `--timing-tolerance` | 5 | Max date difference (days) |
| `--output-dir` | outputs | Report directory |

## Tolerance Guidelines

### Strict (Audit Mode)
```bash
--amount-tolerance 0.01 --timing-tolerance 3
```
Use for: Month-end close, audits, high-value transactions

### Normal (Daily Operations)
```bash
--amount-tolerance 0.10 --timing-tolerance 5
```
Use for: Daily reconciliation, normal operations

### Relaxed (High Volume)
```bash
--amount-tolerance 1.00 --timing-tolerance 10
```
Use for: High-volume operations, bulk processing

## Workflow

1. **Prepare Data**: Export data to CSV files
2. **Run Pipeline**: Execute reconcile.py with appropriate settings
3. **Review Summary**: Check overall statistics
4. **Investigate Exceptions**: Review exceptions report
5. **Take Action**: Resolve issues based on exception type
6. **Document**: Archive reports for audit trail

## Interpreting Results

### High Match Rate (>95%)
✓ Good - Operations and finance are aligned

### Moderate Match Rate (80-95%)
⚠ Needs attention - Review exception types

### Low Match Rate (<80%)
✗ Critical - Systematic issues need resolution

## Integration Examples

### Python Script
```python
from src.loaders import DataLoader
from src.reconciliation import ReconciliationEngine

orders = DataLoader.load_orders('data/orders.csv')
invoices = DataLoader.load_invoices('data/invoices.csv')
engine = ReconciliationEngine()
matches, summary = engine.reconcile(orders, [], invoices, [])
```

### Bash Automation
```bash
#!/bin/bash
TODAY=$(date +%Y%m%d)
python reconcile.py \
  --orders /data/${TODAY}_orders.csv \
  --invoices /data/${TODAY}_invoices.csv \
  --output-dir /reports/${TODAY}/
```

## Troubleshooting

### Issue: FileNotFoundError
**Solution**: Check file paths, ensure files exist

### Issue: Date parsing errors
**Solution**: Use ISO format: YYYY-MM-DD

### Issue: Amount calculation errors
**Solution**: Ensure numeric values, no currency symbols

### Issue: High exception count
**Solution**: Review tolerance settings, check data quality

## Performance Tips

- Process large files in batches by date range
- Use appropriate tolerances to reduce false positives
- Archive old reports regularly
- Monitor trends over time

## Best Practices

1. **Run daily** - Catch issues early
2. **Review trends** - Monitor exception patterns
3. **Document resolutions** - Maintain audit trail
4. **Adjust tolerances** - Based on business needs
5. **Automate** - Use scheduled jobs
6. **Validate data** - Check input data quality

## Testing

```bash
# Run test suite
python test_reconciliation.py

# Test with sample data
python reconcile.py

# Test custom tolerances
python reconcile.py --amount-tolerance 100 --timing-tolerance 30
```

## Support

For issues or questions:
1. Check this guide and EXAMPLES.md
2. Review ARCHITECTURE.md for technical details
3. Check sample data in sample_data/ directory
4. Open an issue on GitHub

## Version Info

- Python: 3.7+
- Key Dependencies: pandas, numpy, python-dateutil
- License: MIT
