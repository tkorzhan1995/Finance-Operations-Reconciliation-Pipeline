# Finance Operations Reconciliation Pipeline

**End-to-end reconciliation pipeline aligning operational and financial data, with automated matching, exception handling, and comprehensive reporting.**

## Overview

This project simulates a company where operational activity (orders and shipments) must reconcile to financial records (invoices and ledger postings). Differences can arise due to timing, partial fulfillment, refunds, or data issues. The pipeline automatically matches records, identifies true exceptions, and provides clear outputs for finance and operations teams.

## Features

- **Automated Record Matching**: Intelligently matches operational records (orders, shipments) with financial records (invoices, ledger postings)
- **Exception Detection**: Identifies and categorizes various types of exceptions:
  - Timing differences (orders vs invoices created on different dates)
  - Amount mismatches (operational vs financial amounts differ)
  - Missing invoices (orders without corresponding invoices)
  - Missing orders (invoices without corresponding orders)
  - Partial fulfillments (only part of order was shipped/invoiced)
  - Refunds (detected from ledger postings)
- **Comprehensive Reporting**: Generates multiple report formats:
  - Summary report with key statistics (text format)
  - Matched records report (CSV)
  - Exceptions report with details (CSV)
  - Detailed JSON report for programmatic access
- **Configurable Tolerances**: Adjust amount and timing tolerances for matching
- **Data Validation**: Validates input data for common issues

## Project Structure

```
Finance-Operations-Reconciliation-Pipeline/
├── reconcile.py              # Main pipeline script
├── requirements.txt          # Python dependencies
├── README.md                 # This file
├── src/
│   ├── models/              # Data models (Order, Invoice, etc.)
│   ├── loaders/             # Data loading utilities
│   ├── reconciliation/      # Core reconciliation engine
│   └── reporting/           # Report generation
├── sample_data/             # Sample CSV files
│   ├── orders.csv
│   ├── shipments.csv
│   ├── invoices.csv
│   └── ledger_postings.csv
└── outputs/                 # Generated reports (created on first run)
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/tkorzhan1995/Finance-Operations-Reconciliation-Pipeline.git
cd Finance-Operations-Reconciliation-Pipeline
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Basic Usage

Run the pipeline with sample data:
```bash
python reconcile.py
```

### Custom Data Files

Use your own data files:
```bash
python reconcile.py \
  --orders path/to/orders.csv \
  --invoices path/to/invoices.csv \
  --shipments path/to/shipments.csv \
  --ledger path/to/ledger_postings.csv
```

### Adjust Tolerance Settings

```bash
python reconcile.py \
  --amount-tolerance 1.00 \
  --timing-tolerance 10
```

### Help

```bash
python reconcile.py --help
```

## Data Format

### Orders (orders.csv)
```csv
order_id,customer_id,order_date,amount,status
ORD-001,CUST-101,2024-01-15,1500.00,completed
```

### Shipments (shipments.csv)
```csv
shipment_id,order_id,shipment_date,shipped_amount,status
SHIP-001,ORD-001,2024-01-16,1500.00,delivered
```

### Invoices (invoices.csv)
```csv
invoice_id,order_id,customer_id,invoice_date,amount,status
INV-001,ORD-001,CUST-101,2024-01-15,1500.00,paid
```

### Ledger Postings (ledger_postings.csv)
```csv
posting_id,invoice_id,posting_date,amount,account,transaction_type
POST-001,INV-001,2024-01-15,1500.00,AR-101,debit
```

## Output Reports

The pipeline generates four types of reports in the `outputs/` directory:

1. **Summary Report** (`reconciliation_summary_*.txt`): High-level statistics and exception breakdown
2. **Matched Records** (`matched_records_*.csv`): Successfully matched records
3. **Exceptions Report** (`exceptions_*.csv`): All exception records with categories
4. **Detailed Report** (`detailed_report_*.json`): Complete data in JSON format

## Example Output

```
======================================================================
RECONCILIATION SUMMARY
======================================================================

Total Orders:           10
Total Invoices:         9
Matched Records:        6
Exception Records:      5

Exception Breakdown:
  - Timing Issues:      1
  - Amount Mismatches:  1
  - Missing Invoices:   1
  - Missing Orders:     1
  - Partial Fulfillment:0
  - Refunds:            1

Total Operational:      $18,230.50
Total Financial:        $18,240.50
Total Difference:       $-10.00
======================================================================
```

## Reconciliation Logic

The reconciliation engine:

1. **Matches by Order ID**: Primary matching key between orders and invoices
2. **Amount Comparison**: Checks if amounts match within tolerance (default: $0.01)
3. **Timing Analysis**: Flags records with date differences > threshold (default: 5 days)
4. **Partial Fulfillment Detection**: Compares shipped amounts to invoiced amounts
5. **Refund Detection**: Identifies refund transactions in ledger postings
6. **Exception Categorization**: Classifies unmatched or problematic records

## Use Cases

- **Finance Teams**: Identify invoicing gaps and reconciliation issues
- **Operations Teams**: Track fulfillment and shipping discrepancies
- **Auditing**: Generate comprehensive audit trails
- **Process Improvement**: Identify patterns in exceptions to improve processes
- **Daily Reconciliation**: Automate daily reconciliation workflows

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the MIT License.
