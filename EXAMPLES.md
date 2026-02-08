# Usage Examples

This document provides detailed examples of using the Finance Operations Reconciliation Pipeline.

## Example 1: Basic Usage with Sample Data

```bash
python reconcile.py
```

**Output:**
```
======================================================================
Finance Operations Reconciliation Pipeline
======================================================================

Loading operational data...
  ✓ Loaded 10 orders from sample_data/orders.csv
  ✓ Loaded 9 shipments from sample_data/shipments.csv

Loading financial data...
  ✓ Loaded 9 invoices from sample_data/invoices.csv
  ✓ Loaded 10 ledger postings from sample_data/ledger_postings.csv

Running reconciliation...
  ✓ Reconciliation complete: 11 records processed

============================================================
RECONCILIATION SUMMARY
============================================================

Total Orders:           10
Total Invoices:         9
Matched Records:        5
Exception Records:      6

Exception Breakdown:
  - Timing Issues:      1
  - Amount Mismatches:  1
  - Missing Invoices:   2
  - Missing Orders:     1
  - Partial Fulfillment:0
  - Refunds:            0
============================================================
```

## Example 2: Custom Tolerance Settings

### Strict Tolerances (Default)
```bash
python reconcile.py --amount-tolerance 0.01 --timing-tolerance 5
```

Flags exceptions for amounts differing by more than $0.01 and dates differing by more than 5 days.

### Relaxed Tolerances
```bash
python reconcile.py --amount-tolerance 100.00 --timing-tolerance 30
```

More forgiving matching - useful for high-volume operations with natural variations.

## Example 3: Custom Data Files

```bash
python reconcile.py \
  --orders monthly_data/january_orders.csv \
  --invoices monthly_data/january_invoices.csv \
  --shipments monthly_data/january_shipments.csv \
  --ledger monthly_data/january_ledger.csv \
  --output-dir reports/january/
```

## Example 4: Understanding the Sample Data

### Scenario 1: Perfect Match
- **Order**: ORD-001, $1,500.00, 2024-01-15
- **Invoice**: INV-001, $1,500.00, 2024-01-15
- **Result**: ✓ Matched

### Scenario 2: Timing Exception
- **Order**: ORD-003, $890.00, 2024-01-17
- **Invoice**: INV-003, $890.00, 2024-01-25
- **Result**: ⚠ Exception (8 days difference)

### Scenario 3: Amount Mismatch
- **Order**: ORD-006, $3,200.00, 2024-01-20
- **Invoice**: INV-006, $3,500.00, 2024-01-20
- **Result**: ⚠ Exception ($300 difference)

### Scenario 4: Missing Invoice
- **Order**: ORD-010, $990.00, 2024-01-24
- **Invoice**: None
- **Result**: ⚠ Exception (No invoice found)

### Scenario 5: Missing Order
- **Order**: None
- **Invoice**: INV-009, $5,000.00, 2024-01-23
- **Result**: ⚠ Exception (No order found)

### Scenario 6: Cancelled Transaction
- **Order**: ORD-007, $750.00, cancelled
- **Invoice**: INV-007, $750.00, cancelled
- **Result**: ⚠ Exception (Both cancelled)

## Example 5: Interpreting Reports

### Summary Report (`reconciliation_summary_*.txt`)
High-level statistics showing:
- Overall match rate
- Total counts by exception type
- Financial totals and differences

**Use for:** Executive reporting, daily dashboards

### Matched Records (`matched_records_*.csv`)
All successfully matched records.

**Use for:** Confirmation that most records are processing correctly

### Exceptions Report (`exceptions_*.csv`)
Detailed list of all exceptions with:
- Exception type
- Amounts
- Differences
- Explanatory notes

**Use for:** Investigation and resolution by finance/operations teams

### Detailed Report (`detailed_report_*.json`)
Complete data in JSON format.

**Use for:** Programmatic analysis, integration with other systems

## Example 6: Automated Daily Reconciliation

Create a shell script for daily automation:

```bash
#!/bin/bash
# daily_reconciliation.sh

DATE=$(date +%Y%m%d)
DATA_DIR="/data/exports/${DATE}"
REPORT_DIR="/reports/${DATE}"

python reconcile.py \
  --orders "${DATA_DIR}/orders.csv" \
  --invoices "${DATA_DIR}/invoices.csv" \
  --shipments "${DATA_DIR}/shipments.csv" \
  --ledger "${DATA_DIR}/ledger.csv" \
  --output-dir "${REPORT_DIR}" \
  --amount-tolerance 0.10 \
  --timing-tolerance 7

# Email summary to finance team
mail -s "Daily Reconciliation Report ${DATE}" \
  finance@company.com < "${REPORT_DIR}/reconciliation_summary_*.txt"
```

## Example 7: Integration Patterns

### Python Integration
```python
from src.loaders import DataLoader
from src.reconciliation import ReconciliationEngine
from src.reporting import ReportGenerator
from decimal import Decimal

# Load data
orders = DataLoader.load_orders('data/orders.csv')
invoices = DataLoader.load_invoices('data/invoices.csv')
shipments = DataLoader.load_shipments('data/shipments.csv')
ledger = DataLoader.load_ledger_postings('data/ledger.csv')

# Run reconciliation
engine = ReconciliationEngine(
    tolerance_amount=Decimal('0.01'),
    timing_tolerance_days=5
)
matches, summary = engine.reconcile(orders, shipments, invoices, ledger)

# Generate reports
report_gen = ReportGenerator(output_dir='outputs')
reports = report_gen.generate_all_reports(matches, summary)

# Custom analysis
exceptions = [m for m in matches if m.match_status == 'exception']
critical_exceptions = [e for e in exceptions if abs(e.difference) > 1000]

print(f"Found {len(critical_exceptions)} critical exceptions > $1000")
```

## Example 8: Common Workflows

### Daily Finance Reconciliation
1. Export daily transaction data
2. Run pipeline with standard tolerances
3. Review exception report
4. Investigate high-value exceptions first
5. Document resolution actions

### Month-End Close
1. Run pipeline with strict tolerances (0.01, 3 days)
2. Ensure all exceptions are documented
3. Generate summary for management
4. Archive reports for audit trail

### Audit Preparation
1. Run pipeline on historical data
2. Compare multiple periods
3. Generate detailed JSON reports
4. Provide exception breakdown by category

## Tips and Best Practices

1. **Start with relaxed tolerances** when first implementing, then tighten as processes improve
2. **Review exceptions regularly** to identify process improvement opportunities
3. **Document resolutions** for audit trails
4. **Automate daily runs** but review manually weekly
5. **Monitor trends** in exception types over time
6. **Use different tolerances** for different business units or transaction types
